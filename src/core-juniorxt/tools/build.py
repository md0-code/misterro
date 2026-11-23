from project_paths import ROOT
from common import run
import sys
act=sys.argv[1] if len(sys.argv)>1 else 'test'
steps={'fetch':['fetch_sources'],'assets':['build_hdrom','prepare_assets','build_software'],'sim':['prepare_quartus','sim'],'test':['prepare_quartus','test_serial','test_memory','test_runtime','test_winchester'],'quartus':['compile'],'package':['package','check_package']}
if act not in steps:raise SystemExit('Choose fetch, assets, sim, test, quartus or package')
for step in steps[act]:run([sys.executable,'-B',ROOT/'tools'/(step+'.py'),*sys.argv[2:]])
