"""Audit original CIP-04 ROMs and exercise generated host controls; no full-machine claim."""
from pathlib import Path
import hashlib,json,re,subprocess
from prepare_cip04 import ROOT,OUT,hashes
def main():
    source=(OUT/'CIP04.sv').read_text()
    rom=(ROOT/'assets/roms/cip04.rom').read_bytes()
    if len(rom)!=65536:raise ValueError('Wrong CIP-04 ROM length')
    dos=rom[32768:49152]
    ports={hex(p):dos.count(bytes([1,p&255,p>>8])) for p in [0x1ffd,0x2ffd,0x3ffd,0x7ffd]}
    if any(ports[hex(p)]==0 for p in [0x2ffd,0x3ffd]):raise ValueError('Missing expected FDC port accesses in original DOS ROM')
    # Exercise the exact ROM-upload controller extracted from the generated wrapper.
    start=source.index('reg init_reset = 1;');end=source.index('\nreg NMI;',start)
    control=source[start:end]
    start=source.index('reg [7:0] host_reset_count');end=source.index('wire        reset_core',start)
    host=source[start:end]
    tb='''module cip04_controls_tb;
reg clk_sys=0,RESET=1,ioctl_download=0,ioctl_wr=0;
reg [7:0] ioctl_index=0;reg [24:0] ioctl_addr=0;
reg [10:0] ps2_key=0;wire [11:1] Fn;wire [2:0] modifiers;wire [4:0] keys;
always #5 clk_sys=~clk_sys;
'''+control+host+'''
keyboard keyboard(.reset(RESET || host_reset_count!=0),.clk_sys(clk_sys),.ps2_key(ps2_key),
 .recreated_zx(1'b0),.ghosting(1'b0),.addr(16'hbffe),.key_data(keys),.Fn(Fn),.mod(modifiers));
task upload(input integer count);
 integer i;
 begin
  ioctl_download=1;repeat(3)@(negedge clk_sys);
  for(i=0;i<count;i=i+1)begin ioctl_wr=1;ioctl_addr=i;@(negedge clk_sys);end
  ioctl_wr=0;ioctl_download=0;repeat(3)@(negedge clk_sys);
 end
endtask
initial begin
 repeat(8)@(negedge clk_sys);RESET=0;
 upload(2048);if(!init_reset)$fatal(1,"Short ROM released CPU");
 upload(65536);if(init_reset)$fatal(1,"Complete ROM did not release CPU");
 upload(65537);if(!init_reset)$fatal(1,"Oversized ROM released CPU");
 upload(65536);if(init_reset)$fatal(1,"ROM reload failed");
 ps2_key=11'h678;repeat(8)@(negedge clk_sys);
 if(host_reset_count<240)$fatal(1,"F11 did not hold CPU reset");
 repeat(270)@(negedge clk_sys);if(host_reset_count!=0)$fatal(1,"F11 reset stuck");
 ps2_key=11'h078;repeat(5)@(negedge clk_sys);
 ps2_key=11'h63b;repeat(5)@(negedge clk_sys);if(keys!==5'b10111)$fatal(1,"CIP matrix J key failed: %b",keys);
 $display("PASS: CIP04 ROM upload/reload rejection, automatic start, F11 pulse and matrix adapter");$finish;
end
endmodule
'''
    (ROOT/'build/cip04_controls_tb.sv').write_text(tb)
    command=['iverilog','-g2012','-s','cip04_controls_tb','-o','build/cip04-controls.vvp',
             'build/cip04_controls_tb.sv','mister/cip04_keyboard.sv','rtl/cip01_keyboard.sv']
    subprocess.run(command,cwd=ROOT,check=True);subprocess.run(['vvp','build/cip04-controls.vvp'],cwd=ROOT,check=True)
    report={'status':'passed','project_sources':hashes(),'rom_sha256':hashlib.sha256(rom).hexdigest(),
        'rom_bank_sha256':[hashlib.sha256(rom[i:i+16384]).hexdigest() for i in range(0,65536,16384)],
        'dos_port_reference_counts':ports,'checks':['ROM size and bank hashes','original DOS FDC port references','short/oversized ROM rejection','automatic start after full ROM upload','F11 reset hold/release','PS2 matrix adapter'],
        'qualification':'ROM and host-control checks only. Complete CPU boot, AY, tape, disk and physical 256K mapper remain unverified.'}
    (ROOT/'build/cip04-profile-validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS: profile controls and ROM audit; full-machine CIP-04 testing remains pending')
if __name__=='__main__':main()
