"""Exercise disk commands against real DSK images with a byte-accurate host."""
from build import *
from validate_quartus import source_hashes
def main():
 original=source_hashes()
 run(['verilator','--cc','--exe','--build','-j','4','--top-module','hc_fdc_sim','-Wno-fatal','-Wno-WIDTH','-Wno-CASEINCOMPLETE','--Mdir',BUILD/'fdc-obj','-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',ROOT/'rtl/hc88_u765.sv',ROOT/'sim/hc_fdc_sim.sv',ROOT/'sim/hc_fdc_main.cpp'],log='fdc-build.log')
 run([BUILD/'fdc-obj/Vhc_fdc_sim'])
 if source_hashes()!=original:raise ValueError('Sources changed during FDC tests')
 p=BUILD/'fdc-validation.json';proof=json.loads(p.read_text());proof['project_sources']=original;p.write_text(json.dumps(proof,indent=2)+'\n')
if __name__=='__main__':main()
