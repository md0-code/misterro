from project_paths import ROOT
from prepare_quartus import OUT
from validate_quartus import source_hashes
from common import run
from pathlib import Path
import json,subprocess,tempfile,shutil,os
run(['iverilog','-g2012','-s','map_tb','-o',ROOT/'build/map.vvp',OUT/'rtl/mem/sdram_pkg.sv',OUT/'rtl/mem/mem_map.sv',ROOT/'sim/map_tb.sv'],log='map-build.log')
run(['vvp',ROOT/'build/map.vvp'],log='map-test.log')
script=OUT/'rtl/mem/TESTBENCH/run_tests.sh'
with tempfile.TemporaryDirectory(prefix='juniorxt-memory-') as folder:
 for name in ['sdram_ctrl','e2e_optB_8086']:
  env=dict(os.environ,TB_BUILD=folder)
  run(['bash',script,name],env=env,log=name+'-test.log')
  for p in Path(folder).glob('*.log'):shutil.copyfile(p,ROOT/'build'/p.name)
result={'status':'passed','project_sources':source_hashes(),'checks':['Junior memory decode and ROM write protection','real SDRAM command/pin model','native 8086 bus and SDRAM end-to-end']}
(ROOT/'build/hardware-validation.json').write_text(json.dumps(result,indent=2)+'\n')
print('PASS: native memory decode, SDRAM pin model and 8086 memory integration')
