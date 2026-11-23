"""Prepare an explicitly experimental CIP-04 +3 compatibility build from pinned RTL."""
from project_paths import DOCS,README,PLAN,source_path,export_readme
from pathlib import Path
import hashlib,json,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1];UP=ROOT/'vendor/spectrum';OUT=ROOT/'build/quartus-CIP04'
def hashes():
    names=['tools/prepare_cip04.py','mister/cip04_keyboard.sv','rtl/cip01_keyboard.sv']
    return {n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in names}
def main():
    lock=json.loads((DOCS/'dependencies.lock.json').read_text())
    if (UP/'.git').exists() and subprocess.check_output(['git','rev-parse','HEAD'],cwd=UP,text=True).strip()!=lock['spectrum']['commit']:raise ValueError('Wrong platform revision')
    OUT.mkdir(parents=True,exist_ok=True)
    for folder in ['rtl','sys']:shutil.copytree(UP/folder,OUT/folder,dirs_exist_ok=True)
    for name in ['ZX-Spectrum.sdc','files.qip']:
        shutil.copyfile(UP/name,OUT/name)
    text=(UP/'ZX-Spectrum.sv').read_text()
    start=text.index('localparam CONF_STR = {');end=text.index('\n};',start)+3
    text=text[:start]+'''localparam CONF_STR = {
    "CIP04;;",
    "S0,DSK,Mount Disk A;",
    "F2,TAPCSWTZXPZX,Load Tape;",
    "-;",
    "O[5:4],Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
    "O[1],Tape Sound,On,Off;",
    "O[19:17],Joystick,Kempston,Sinclair I,Sinclair II,Sinclair I+II,Cursor;",
    "O[3:2],Stereo Mix,None,25%,50%,100%;",
    "-;",
    "R[0],Reset;",
    "J,Fire 1,Fire 2;",
    "V,Experimental +3 profile"
};'''+text[end:]
    # Force the documented +3 firmware interface; the additional 128K mapper is
    # deliberately not guessed. This is not certified as full 256K CIP-04 support.
    text=text.replace('wire [63:0] status;', '''wire [63:0] status_hps;
wire [63:0] status;
localparam [63:0] USER_MASK=(64'hf<<1)|(64'h7<<17)|64'h1;
assign status=(status_hps & USER_MASK)|(64'd4<<10)|(64'd1<<8)|(64'd3<<20)|(64'd1<<41)|(64'd1<<6);''')
    text=re.sub(r'\.status\(status\)', '.status(status_hps)',text,count=1)
    text=text.replace("25'h150000","25'h160000")
    text=text.replace('(plus3 & (ioctl_index[7:6] == 2)) && (img_size != 0)','plus3 && (img_size != 0)')
    text=text.replace('`include "build_id.v"','// Build identity is included in the profile menu below.')
    start=text.index('reg init_reset = 1;');end=text.index('\nreg NMI;',start)
    text=text[:start]+'''reg init_reset = 1;
reg rom_downloading = 0;
reg [25:0] rom_length = 0;
always @(posedge clk_sys) begin
    rom_downloading <= ioctl_download && ioctl_index[4:0] == 0;
    if (RESET) begin init_reset <= 1; rom_length <= 0; end
    else begin
        if (ioctl_download && ioctl_index[4:0] == 0 && !rom_downloading) begin
            init_reset <= 1; rom_length <= 0;
        end
        if (ioctl_download && ioctl_index[4:0] == 0 && ioctl_wr) rom_length <= {1'b0,ioctl_addr}+1'b1;
        if (rom_downloading && !ioctl_download) init_reset <= rom_length != 65536;
    end
end
''' + text[end:]
    text=text.replace('wire        reset_core = buttons[1]', '''reg [7:0] host_reset_count = 0;
always @(posedge clk_sys) begin
    if (Fn[11]) host_reset_count <= 8'hff;
    else if (host_reset_count != 0) host_reset_count <= host_reset_count - 1'b1;
end
wire        reset_core = (host_reset_count != 0) | buttons[1]''')
    text=re.sub(r'wire mni_pulse = [^;]+;',"wire mni_pulse = 1'b0;",text,count=1)
    (OUT/'CIP04.sv').write_text(text)
    shutil.copyfile(ROOT/'mister/cip04_keyboard.sv',OUT/'rtl/keyboard.sv')
    shutil.copyfile(ROOT/'rtl/cip01_keyboard.sv',OUT/'rtl/cip01_keyboard.sv')
    qip=(UP/'files.qip').read_text().replace('"ZX-Spectrum.sv"','"CIP04.sv"')
    qip+='\nset_global_assignment -name SYSTEMVERILOG_FILE rtl/cip01_keyboard.sv\n'
    (OUT/'files.qip').write_text(qip)
    qsf=(UP/'ZX-Spectrum.qsf').read_text().replace('17.0.2 Standard Edition','17.0.2 Lite Edition')
    qsf=qsf.replace('set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL\n','')+'\nset_global_assignment -name NUM_PARALLEL_PROCESSORS 4\n'
    (OUT/'CIP04.qsf').write_text(qsf);(OUT/'CIP04.qpf').write_text('QUARTUS_VERSION = "17.0"\nPROJECT_REVISION = "CIP04"\n')
    (OUT/'inputs.json').write_text(json.dumps({'project_sources':hashes(),'upstream_commit':lock['spectrum']['commit'],
        'quartus_image':lock['quartus_image'],'qualification':'Experimental +3-compatible 128K address map; CIP-04 extra RAM paging unverified'},indent=2)+'\n')
    print(OUT/'CIP04.qpf')
if __name__=='__main__':main()
