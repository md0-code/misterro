"""Build the original T80 and run the native CUB Z headless machine."""
from cpu import ROOT,BUILD,cpu,run
import sys
cpu()
run(['verilator','--cc','--exe','--build','-j','6','--top-module','cubz_core','-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-WIDTH','-Wno-CASEINCOMPLETE','--Mdir',BUILD/'obj','-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',*[str(p) for p in sorted((ROOT/'rtl').glob('*.sv'))],BUILD/'t80.v',ROOT/'sim/main.cpp'],log='verilator-build.log')
run([BUILD/'obj/Vcubz_core',*sys.argv[1:]])
