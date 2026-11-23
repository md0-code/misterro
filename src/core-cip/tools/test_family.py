"""Exercise the single CIP selector, original ROMs, runtime BASIC and +3 firmware banks."""
from pathlib import Path
import concurrent.futures,hashlib,json,re,subprocess,sys
from build import ROOT,BUILD,cpu,run,sources
from prepare_family import hashes
from check_capture import text
from project_paths import DOCS

def run_case(case,args):
    prefix='family-'+case+'-'
    with (BUILD/(prefix+'runtime.log')).open('w') as log:
        subprocess.run([BUILD/'family-obj/Vcip01_sim','--prefix',prefix,*args],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    if case=='cip01':
        expected=(ROOT/'build/expected-basic.bin').read_bytes()
        if (BUILD/(prefix+'loaded.bin')).read_bytes()[:len(expected)]!=expected:raise ValueError('Runtime BASIC bytes differ')
        if '4' not in [r.strip() for r in text((BUILD/(prefix+'basic.bin')).read_bytes())]:raise ValueError('Tape BASIC arithmetic failed')
    else:
        name='switch-basic' if case=='copier' else 'reset-basic'
        expected='4' if case=='copier' else '6'
        if expected not in [r.strip() for r in text((BUILD/(prefix+name+'.bin')).read_bytes())]:raise ValueError('Resident arithmetic failed: '+case)
    print('PASS: CIP family',case,flush=True)
    return case

def controller_test():
    (BUILD/'family.hex').write_text(''.join(f'{byte:02x}\n' for byte in (ROOT/'assets/roms/family.rom').read_bytes()))
    extension=(ROOT/'mister/cip_family_extension.svh').read_text()
    a=extension.index('reg [7:0] family_rom4');b=extension.index('wire [39:0]',a)
    bank=extension[a:b]
    tb='''module cip_family_host_tb;
reg clk_sys=0,reset=1,download=0,wr=0,copier_request=0;
reg[1:0]request=0;reg[26:0]address=0;reg[7:0]ioctl_dout=0;
wire[1:0]model;wire copier,hold_reset,native_wr,family_plus3_wr,loaded,overflow;
wire[14:0]native_address;wire[15:0]family_plus3_address;
reg[3:0]page_rom=8;reg[15:0]addr=0;
reg[7:0]image[0:83967];
always #5 clk_sys=~clk_sys;
cip_family_host dut(.clk(clk_sys),.reset(reset),.requested_model(request),.requested_copier(copier_request),
.download(download),.wr(wr),.address(address),.model(model),.copier(copier),.hold_reset(hold_reset),
.native_wr(native_wr),.plus3_wr(family_plus3_wr),.native_address(native_address),.plus3_address(family_plus3_address),.loaded(loaded),.overflow(overflow));
'''+bank+'''
task upload(input integer bytes);integer i;begin
 download=1;repeat(3)@(negedge clk_sys);
 for(i=0;i<bytes;i=i+1)begin wr=1;address=i;ioctl_dout=i<83968?image[i]:8'ha5;@(negedge clk_sys);end
 wr=0;download=0;repeat(4)@(negedge clk_sys);
end endtask
integer i,k,m;
initial begin
 $readmemh("build/family.hex",image);
 repeat(3)@(negedge clk_sys);reset=0;
 upload(18432);if(loaded||!hold_reset)$fatal(1,"Incomplete family ROM accepted");
 upload(83969);if(loaded||!overflow)$fatal(1,"Oversized family ROM accepted");
 upload(83968);if(!loaded||hold_reset)$fatal(1,"Valid family bundle rejected");
 for(k=0;k<4;k=k+1)begin
  page_rom=8+k;
  for(i=0;i<16384;i=i+137)begin
   addr=i;repeat(2)@(negedge clk_sys);
   if(family_rom4_q!==image[18432+k*16384+i])$fatal(1,"CIP04 bank mismatch %d %h",k,addr);
  end
 end
 for(m=0;m<4;m=m+1)begin
  request=m;repeat(2)@(negedge clk_sys);
  if(m!=0&&!hold_reset)$fatal(1,"Model change did not reset CPU");
  repeat(260)@(negedge clk_sys);if(hold_reset||!loaded||model!=m)$fatal(1,"Switch lost firmware");
 end
 request=1;repeat(260)@(negedge clk_sys);
 copier_request=1;repeat(2)@(negedge clk_sys);if(!hold_reset||!copier)$fatal(1,"Copier selection did not reset");
 repeat(260)@(negedge clk_sys);copier_request=0;repeat(260)@(negedge clk_sys);if(copier||hold_reset)$fatal(1,"Resident selection failed");
 $display("PASS: CIP combined ROM bounds, every +3 ROM bank, model changes and copier selection");$finish;
end
endmodule
'''
    (BUILD/'cip_family_host_tb.sv').write_text(tb)
    run(['verilator','--binary','--timing','-j','4','-Wno-fatal','-Wno-WIDTH','--top-module','cip_family_host_tb',
         '--Mdir',BUILD/'family-host-obj',ROOT/'rtl/cip_family_host.sv',BUILD/'cip_family_host_tb.sv'],log='family-host-build.log')
    run([BUILD/'family-host-obj/Vcip_family_host_tb'])

def video_bridge_test():
    extension=(ROOT/'mister/cip_family_extension.svh').read_text()
    a=extension.index('reg [7:0] family_video_hold');b=extension.index('wire [15:0] family_native_audio',a)
    bridge=extension[a:b]
    tb="""module cip_family_video_tb;
reg clk_sys=0,clk_56=0,reset=1;reg[3:0]phase=0;
always #5 clk_sys=~clk_sys;
integer offset;
initial begin if(!$value$plusargs("phase=%d",offset))offset=0;#(offset);forever #10 clk_56=~clk_56;end
always @(posedge clk_sys)if(reset)phase<=0;else phase<=phase+1'b1;
wire family_pixel=phase==15;
wire family_hs,family_vs,family_hb,family_vb;wire[3:0]family_rgb;
wire[13:0]address;wire[8:0]x,y;
cip01_video video(.clk(clk_sys),.reset(reset),.ce_pixel(family_pixel),.border(3'd3),.ram_addr(address),
.ram_data(address[7:0]),.rgb(family_rgb),.hs(family_hs),.vs(family_vs),.hblank(family_hb),.vblank(family_vb),.x(x),.y(y),.flash_count());
"""+bridge+"""
reg[7:0]expected[0:280000];integer sent=0,received=0,last_event=0,cycles=0;
always @(posedge clk_sys)if(family_pixel)begin
 expected[sent]={x>=320 && x<352,y>=248 && y<252,family_hb,family_vb,family_rgb};sent=sent+1;
end
always @(posedge clk_56)begin
 cycles=cycles+1;
 if(family_pixel_56)begin
  if(received>=sent)$fatal(1,"Duplicate or unsolicited pixel");
  if(family_video_hold!==expected[received])$fatal(1,"Pixel/sync mismatch at %d",received);
  if(received>0 && cycles-last_event!=8)$fatal(1,"Lost or duplicated pixel event");
  last_event=cycles;received=received+1;
 end
end
initial begin
 repeat(5)@(negedge clk_sys);reset=0;
 wait(received==279552);
 $display("PASS: two full native rasters, positive mixer sync, blanking/RGB and 112-to-56 MHz pixel cadence (phase %d)",offset);$finish;
end
initial begin #50000000;$fatal(1,"Video bridge timeout");end
endmodule
"""
    (BUILD/'cip_family_video_tb.sv').write_text(tb)
    run(['iverilog','-g2012','-s','cip_family_video_tb','-o',BUILD/'family-video.vvp',ROOT/'rtl/cip01_video.sv',BUILD/'cip_family_video_tb.sv'],log='family-video-build.log')
    for phase in [0,5,9]:run(['vvp',BUILD/'family-video.vvp','+phase='+str(phase)])


def expected_basic():
    data=(ROOT/'assets/tapes/basic.tzx').read_bytes();pos=10;blocks=[]
    while pos<len(data):
        if data[pos]!=0x10:raise ValueError('Unexpected runtime BASIC tape block')
        length=int.from_bytes(data[pos+3:pos+5],'little');block=data[pos+5:pos+5+length]
        checksum=0
        for byte in block:checksum^=byte
        if len(block)!=length or checksum:raise ValueError('Runtime BASIC checksum failed')
        blocks.append(block);pos+=5+length
    if len(blocks)!=2 or blocks[1][0]!=255:raise ValueError('Expected original BASIC CODE payload')
    payload=blocks[1][1:-1];evidence=json.loads((DOCS/'audio-conversion.json').read_text())
    if len(payload)!=evidence['payload_bytes'] or hashlib.sha256(payload).hexdigest()!=evidence['payload_sha256']:raise ValueError('BASIC audio provenance mismatch')
    (BUILD/'expected-basic.bin').write_bytes(payload)


def main():
    cpu();expected_basic();run([sys.executable,ROOT/'tools/test_units.py']);controller_test();video_bridge_test()
    # The real 112 MHz divider is compressed by 16 for this event-equivalent
    # simulation, keeping the original 3.5 MHz CPU and cassette pulse ratio.
    run(['verilator','--cc','--exe','--build','-j','4','--top-module','cip_family_sim','--prefix','Vcip01_sim',
         '-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-CASEINCOMPLETE','-Wno-WIDTH','-Wno-COMBDLY',
         '--Mdir',BUILD/'family-obj','-CFLAGS','-DCIP_FAMILY','-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',
         *sources(),ROOT/'rtl/cip_family_host.sv',ROOT/'sim/cip_family_sim.sv',ROOT/'sim/cip01_main.cpp'],log='family-verilator-build.log')
    cases=[('cip01',['--family-model','0','--seconds','.6','--tape',str(ROOT/'assets/tapes/basic.tzx'),'--test']),
           ('cip02',['--family-model','1','--resident','--test','--seconds','1.5']),
           ('cip03',['--family-model','2','--resident','--test','--seconds','1.5']),
           ('copier',['--family-model','1','--resident','--monitor','--test','--seconds','.6'])]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        passed=list(pool.map(lambda item:run_case(*item),cases))
    original=(ROOT/'assets/roms/cip04.rom').read_bytes()
    result={'status':'passed','project_sources':hashes(),'runtime_cases':passed,
        'firmware_sha256':hashlib.sha256((ROOT/'assets/roms/family.rom').read_bytes()).hexdigest(),
        'cip04_bank_sha256':[hashlib.sha256(original[i:i+16384]).hexdigest() for i in range(0,65536,16384)],
        'checks':['Full MP3-derived BASIC received through EAR and byte-matched','BASIC arithmetic and F11 recovery','Resident model switching and arithmetic','CIP02 copier/resident switch','Combined firmware bounds','Native mixer sync and lossless 112-to-56 MHz video at three clock phases','Original CIP04 bank contents and hardware paging selection retained'],
        'qualification':'Native CIP01/02/03 RTL tested. CIP04 remains the experimental +3 profile; physical startup and extra 128K mapper unverified.'}
    (BUILD/'family-validation.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
