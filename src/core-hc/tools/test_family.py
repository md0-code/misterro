"""Verify HC firmware upload, every model bank, warm reset and runtime switching."""
from pathlib import Path
import concurrent.futures,json,subprocess,sys
from build import ROOT,BUILD,cpu,run,sources
from validate_quartus import source_hashes

def test_model(model):
    log=BUILD/(model.lower()+'-family-runtime.log')
    with log.open('w') as out:
        subprocess.run([BUILD/'family4-obj/Vhc85_sim','--model',model[2:],'--test'],cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,check=True)
    subprocess.run([sys.executable,ROOT/'tools/check_capture.py','--model',model,'--test','--family'],cwd=ROOT,check=True)
    return model

def main():
    original=source_hashes()
    cpu()
    run([sys.executable,ROOT/'tools/test_units.py'])
    tb='''module hc_family_host_tb;
reg clk=0,reset=1,download=0,wr=0;reg[2:0]request=0;reg[26:0]address=0;
wire[2:0]model;wire hold_reset,rom_wr,loaded,overflow;wire[15:0]rom_address;
always #5 clk=~clk;
hc_family_host dut(.clk(clk),.reset(reset),.requested_model(request),.download(download),.wr(wr),.address(address),
.model(model),.hold_reset(hold_reset),.rom_wr(rom_wr),.rom_address(rom_address),.loaded(loaded),.overflow(overflow));
task upload(input integer bytes);integer i;begin
 download=1;repeat(3)@(negedge clk);
 for(i=0;i<bytes;i=i+1)begin wr=1;address=i;@(negedge clk);end
 wr=0;download=0;repeat(4)@(negedge clk);
end endtask
integer m;
initial begin
 repeat(3)@(negedge clk);reset=0;
 upload(16384);if(loaded||!hold_reset)$fatal(1,"Individual ROM accepted as family bundle");
 upload(65537);if(loaded||!overflow)$fatal(1,"Oversized family ROM accepted");
 upload(65536);if(!loaded||hold_reset)$fatal(1,"Complete family ROM rejected");
 for(m=1;m<6;m=m+1)begin
  request=m;@(negedge clk);if(!hold_reset)$fatal(1,"Model change did not reset CPU");
  repeat(260)@(negedge clk);if(hold_reset||!loaded)$fatal(1,"Model change lost firmware");
 end
 if(model!=5)$fatal(1,"HC-2000 selection was lost");
 $display("PASS: HC family upload bounds, switching reset and retained firmware");$finish;
end
endmodule
'''
    (BUILD/'hc_family_host_tb.sv').write_text(tb)
    run(['verilator','--binary','--timing','-j','4','-Wno-fatal','--top-module','hc_family_host_tb','--Mdir',BUILD/'family-host-obj',ROOT/'rtl/hc_family_host.sv',BUILD/'hc_family_host_tb.sv'],log='family-host-build.log')
    run([BUILD/'family-host-obj/Vhc_family_host_tb'])
    run(['verilator','--cc','--exe','--build','-j','4','--top-module','hc_family_sim','--prefix','Vhc85_sim',
        '-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-CASEINCOMPLETE','-Wno-WIDTH','-Wno-COMBDLY',
        '--Mdir',BUILD/'family4-obj','-CFLAGS','-DHC_FAMILY','-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',
        *sources(),ROOT/'rtl/hc_family_host.sv',ROOT/'sim/hc_family_sim.sv',ROOT/'sim/main.cpp'],log='family-verilator-build.log')
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        models=list(pool.map(test_model,['HC85','HC90','HC91']))
    if source_hashes()!=original:raise ValueError('Sources changed during family tests')
    (BUILD/'family-validation.json').write_text(json.dumps({'status':'passed','project_sources':source_hashes(),'models':models,
        'checks':['Combined firmware upload bounds','Cold boot all original ROM banks','PRINT 2+2','F11 and PRINT 3+3','Live OSD transitions 85 to 90, 90 to 91, 91 to 85','BASIC arithmetic after switching','Model-specific bus, video and cassette-player regression']},indent=2)+'\n')
if __name__=='__main__':main()
