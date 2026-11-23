"""Prepare one CIP family core with native models and the experimental +3 path."""
from pathlib import Path
import hashlib,json,re,shutil
from project_paths import ROOT,DOCS
import prepare_cip04
OUT=ROOT/'build/quartus-CIP'
UP=ROOT/'vendor/spectrum'
def hashes():
    names=[p for d in ['rtl','mister'] for p in sorted((ROOT/d).iterdir()) if p.is_file()]
    names += [ROOT/'tools/prepare_family.py',ROOT/'tools/prepare_cip04.py']
    return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in names}
def disabled_instance(text,module,path,overrides=None):
    overrides=overrides or {}
    pattern=r'(?m)^'+re.escape(module)+r'\s+(?:#\([^\n]*\)\s*)?\w+\s*\n?\('
    match=re.search(pattern,text)
    if not match:raise ValueError('Missing optional instance: '+module)
    end=text.index('\n);',match.start())+3
    instance=text[match.start():end]
    decl=path.read_text();decl=decl[decl.index('module '+module):];decl=decl[:decl.index('\n);')]
    decl=re.sub(r'//[^\n]*','',decl)
    decl=re.sub(r'\b(output|reg|wire|signed)(?=\[)',r'\1 ',decl)
    outputs=re.findall(r'\boutput\s+(?:(?:reg|wire|signed)\s+)*(?:\[[^]]+\]\s*)?(\w+)',decl)
    assignments=[]
    for name in outputs:
        port=re.search(r'\.'+name+r'\s*\(([^()]*)\)',instance)
        if not port and '.*' not in instance:continue
        target=port.group(1).strip() if port else name
        if not target:continue
        if not re.fullmatch(r'\w+(?:\[[^]]+\])?',target):raise ValueError('Unsafe output tie: '+target)
        assignments.append('assign '+target+' = '+overrides.get(name,"'0")+';')
    return text[:match.start()]+'// Unexpanded family: optional '+module+' disabled.\n'+'\n'.join(assignments)+text[end:]
def main():
    prepare_cip04.main()
    OUT.mkdir(parents=True,exist_ok=True)
    for folder in ['rtl','sys']:shutil.copytree(prepare_cip04.OUT/folder,OUT/folder,dirs_exist_ok=True)
    (OUT/'ZX-Spectrum.sdc').write_text((prepare_cip04.OUT/'ZX-Spectrum.sdc').read_text()+'\n'+(ROOT/'mister/CIP.sdc').read_text())
    text=(prepare_cip04.OUT/'CIP04.sv').read_text()
    start=text.index('localparam CONF_STR = {');end=text.index('\n};',start)+3
    text=text[:start]+'''localparam CONF_STR = {
 "CIP;;",
 "S0,DSK,Floppy A:;",
 "F2,TAPCSWTZXPZX,Load tape;",
 "T[22],Tape play/pause;","T[23],Previous tape block;","T[24],Next tape block;",
 "-;",
 "P1,System;",
 "P1O[16:15],Model,CIP-01,CIP-02,CIP-03,CIP-04 experimental;",
 "P1O[7],CIP-02 startup,BASIC,Copier;",
 "P1F0,ROM,Load firmware;",
 "P2,Ports & Controllers;",
 "P2O[19:17],CIP-04 joystick,Kempston,Sinclair I,Sinclair II,Sinclair I+II,Cursor;",
 "P2O[56],CIP-04 UART,Serial port,Printer;",
 "P3,Audio & Video;",
 "P3O[1],Tape sound,On,Off;","P3O[3:2],Stereo mix,None,25%,50%,100%;",
 "P3O[61:60],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
 "P3O[58:57],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
 "-;",
 "R[0],Reset;","J,Fire;","V,v0.3"
};'''+text[end:]
    for module,file,overrides in [
        ('gs','rtl/gs.v',{}),('savestate_dev','rtl/savestate_dev.sv',{'ps2_key_kbd':'ps2_key','ula_q':'vram_dout','ula_border':'border_color'}),
        ('savestate_clock','rtl/savestate_clock.sv',{}),('snap_loader','rtl/snap_loader.sv',{}),
        ('wd1793','rtl/wd1793.sv',{}),('hq_mix','rtl/sound/hq_mix.sv',{}),
    ]:text=disabled_instance(text,module,UP/file,overrides)
    text=text.replace("(64'd1<<6);","(64'd1<<6)|(64'd1<<55);")
    a=text.index('\t.status_set(');b=text.index('\n\t.sd_lba',a)
    text=text[:a]+"\t.status_set(1'b0),\n\t.status_in(64'd0),\n"+text[b:]
    a=text.index('reg init_reset = 1;');b=text.index('\nreg NMI;',a)
    text=text[:a]+'wire init_reset=family_hold;\n'+text[b:]
    text=text.replace('wire        reset_core = (host_reset_count', 'wire        reset_core = family_hold | !family_plus3 | (host_reset_count')
    text=text.replace('~nMREQ   ? (tape_dout_en ? tape_dout : ram_dout)',"~nMREQ   ? ((!page_special && addr[15:14]==0) ? family_rom4_q : ram_dout)")
    text=text.replace('always @(posedge clk_sys) load <= (reset | ~nBUSACK) & ~nBUSRQ;',"always @(posedge clk_sys) load <= 1'b0;")
    a=text.index('smart_tape tape');b=text.index('\n);',a)+3
    text=text[:a]+'''assign tape_req=0;
assign tape_addr_raw=0;
assign tape_dout_en=0;
assign tape_turbo=0;
assign tape_dout=0;
assign tape_led=family_tape_active;
assign tape_active=family_tape_active;
assign tape_loaded=family_tape_available;
assign tape_vin=family_tape_audio;'''+text[b:]
    text=text.replace('ULA ULA(.*, .din(cpu_dout)', 'ULA ULA(.*, .reset(RESET || !locked), .din(cpu_dout)')
    text=text.replace('assign AUDIO_S   = 1;','assign AUDIO_S   = family_plus3;')
    text=text.replace('assign AUDIO_L = audio_l;','assign AUDIO_L = family_plus3 ? audio_l : family_native_audio;').replace('assign AUDIO_R = audio_r;','assign AUDIO_R = family_plus3 ? audio_r : family_native_audio;')
    text=text.replace('assign LED_POWER = 0;',"assign LED_POWER = family_overflow || family_tape_overflow ? 2'b11 : 2'b00;")
    text=re.sub(r'\bce_pix\b','plus3_ce_pix',text)
    text=text.replace('reg plus3_ce_pix;', 'wire ce_pix=family_plus3 ? plus3_ce_pix : family_pixel_56;\nreg plus3_ce_pix;')
    for port,up,native in [('HSync','hs','family_video_hold[7]'),('VSync','vs','family_video_hold[6]'),('HBlank','hbl','family_video_hold[5]'),('VBlank','vbl','family_video_hold[4]')]:
        text=text.replace(f'.{port}({up})',f'.{port}(family_plus3 ? {up} : {native})')
    for port,up,bit in [('R','Rx',1),('G','Gx',2),('B','Bx',0)]:
        text=text.replace(f'.{port}({up})',f".{port}(family_plus3 ? {up} : family_video_hold[{bit}] ? (family_video_hold[3] ? 8'hff : 8'hcd) : 8'h00)")
    text=text.replace('.ARX((!ar)',".ARX(!family_plus3 ? (!ar ? 12'd4 : (ar - 1'd1)) : (!ar)")
    text=text.replace('.ARY((!ar)',".ARY(!family_plus3 ? (!ar ? 12'd3 : 12'd0) : (!ar)")
    # The standard video options sit above the bits the +3 platform is forced to.
    for old,new in [('wire [1:0] scale = status[16:15];','wire [1:0] scale = status_hps[58:57];'),('wire [1:0] ar = status[5:4];','wire [1:0] ar = status_hps[61:60];'),
        # CIP-04 printer and serial ports (rtl/cip04_ports.sv).
        ('assign {UART_RTS, UART_TXD, UART_DTR} = 0;','assign UART_DTR = 0;'),
        ('\t\tfdc_sel  ? fdc_dout ',"\t\tfamily_printer_sel ? {7'h7f, family_printer_busy} :\n\t\tfdc_sel  ? fdc_dout "),
        ('\t\tpsg_rd   ? psg_dout ','\t\tpsg_rd   ? (family_ay14_sel ? family_ay14_in : psg_dout) ')]:
        if text.count(old)!=1:raise ValueError('Platform patch no longer matches: '+old)
        text=text.replace(old,new)
    text=text.replace('reg [1:0] vmode;','reg [1:0] vmode;\n reg [1:0] old_family_model;\n old_family_model<=family_model;')
    text=text.replace('if(vmode != status[9:8])','if(vmode != status[9:8] || old_family_model != family_model)')
    at=text.rindex('\nendmodule')
    text=text[:at]+'\n'+(ROOT/'mister/cip_family_extension.svh').read_text()+text[at:]
    (OUT/'CIP.sv').write_text(text)
    for file in (ROOT/'rtl').glob('*.sv'):shutil.copyfile(file,OUT/'rtl'/file.name)
    qip=(prepare_cip04.OUT/'files.qip').read_text().replace('"CIP04.sv"','"CIP.sv"')
    for name in ['cip01_core.sv','cip01_video.sv','cip01_tape.sv','cip_family_tape.sv','cip_family_host.sv','cip04_ports.sv']:
        qip+='\nset_global_assignment -name SYSTEMVERILOG_FILE rtl/'+name
    (OUT/'files.qip').write_text(qip+'\n')
    shutil.copyfile(prepare_cip04.OUT/'CIP04.qsf',OUT/'CIP.qsf')
    (OUT/'CIP.qpf').write_text('QUARTUS_VERSION = "17.0"\nPROJECT_REVISION = "CIP"\n')
    lock=json.loads((DOCS/'dependencies.lock.json').read_text())
    (OUT/'inputs.json').write_text(json.dumps({'project_sources':hashes(),'upstream_commit':lock['spectrum']['commit'],'quartus_image':lock['quartus_image'],'qualification':'CIP01/02/03 native machine plus experimental CIP04 +3 profile; extra 128K mapper unverified'},indent=2)+'\n')
    print(OUT/'CIP.qpf')
if __name__=='__main__':main()
