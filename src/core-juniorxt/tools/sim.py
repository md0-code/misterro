from project_paths import ROOT
from prepare_quartus import main,OUT
from common import run
import shutil,json
from validation_inputs import harness_hashes
from validate_quartus import source_hashes

def build(speed=0,name=None):
 inputs={'project_sources':source_hashes(),'harness_sha256':harness_hashes(),'speed':speed}
 if json.loads((OUT/'inputs.json').read_text())['project_sources']!=inputs['project_sources']:raise ValueError('Prepare current hardware sources first')
 out=ROOT/('build/'+(name or 'sim'+str(speed)));out.mkdir(exist_ok=True)
 u=ROOT/'vendor/pcxt'
 lines=(u/'rtl/mem/TESTBENCH/sys_video_files.lst').read_text().splitlines()
 sources=[OUT/x for x in lines if x.strip()]
 # The package must precede all its users.
 pkg=OUT/'rtl/mem/sdram_pkg.sv';sources.remove(pkg);sources.insert(0,pkg)
 defs=['ENABLE_CGA=1','ENABLE_HGC=1','ENABLE_OPL2=0','ENABLE_CMS=0','ENABLE_MIDI=0','ENABLE_EMS=0']
 inc=[OUT/('rtl/KFPC-XT/HDL/'+x+'/HDL') for x in ['KF8237','KF8253','KF8255','KF8259']]
 run(['verilator','--cc','--exe','--build','-MAKEFLAGS','OPT_FAST=-O3','-j','8','-O3','-Wno-fatal','-Wno-lint','-Wno-style','-Wno-MULTIDRIVEN','-Wno-TIMESCALEMOD','-Wno-BLKANDNBLK','--top-module','junior_sim','-Mdir',out,'-o','sim','-GSPEED='+str(speed),*['-D'+s for s in defs],*['-I'+str(p) for p in inc],*sources,ROOT/'rtl/junior_serial.sv',ROOT/'sim/stubs.sv',ROOT/'sim/junior_sim.sv',ROOT/'sim/main.cpp'],log='sim-build.log')
 for src,name in [(u/'rtl/8088/mcl86_ucode.mem','mcl86_ucode.mem'),(ROOT/'assets/cga.hex','cga.hex'),(ROOT/'assets/hgc.hex','hgc.hex'),(u/'rtl/video/splash_320x200.hex','splash_320x200.hex')]:shutil.copyfile(src,out/name)
 if inputs['project_sources']!=source_hashes() or inputs['harness_sha256']!=harness_hashes():raise ValueError('Simulation inputs changed during build')
 (out/'build-inputs.json').write_text(json.dumps(inputs,indent=2)+'\n')
if __name__=='__main__':
 import sys
 build(int(sys.argv[1]) if len(sys.argv)>1 else 0)
