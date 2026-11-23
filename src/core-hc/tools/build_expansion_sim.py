"""Build the native six-model, dual-drive HC expansion simulator."""
from build import *
from validate_quartus import source_hashes
def main():
 original=source_hashes()
 cpu()
 run(['verilator','--cc','--exe','--build','-j','4','--top-module','hc_expansion_sim','-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-WIDTH','-Wno-CASEINCOMPLETE','-Wno-COMBDLY','--Mdir',BUILD/'expansion-obj','-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',*sources(),ROOT/'rtl/hc_family_host.sv',ROOT/'sim/hc_expansion_sim.sv',ROOT/'sim/hc_expansion_main.cpp'],log='expansion-verilator-build.log')
 if source_hashes()!=original:raise ValueError('Sources changed while building simulator')
 (BUILD/'expansion-sim-inputs.json').write_text(json.dumps({'project_sources':original,'binary_sha256':hashlib.sha256((BUILD/'expansion-obj/Vhc_expansion_sim').read_bytes()).hexdigest(),'simulation_sources':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'sim/hc_expansion_sim.sv',ROOT/'sim/hc_expansion_main.cpp']}},indent=2)+'\n')
if __name__=='__main__':main()
