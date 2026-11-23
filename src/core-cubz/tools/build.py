"""CUB Z component build entry point (Linux/WSL)."""
from project_paths import ROOT
import argparse,subprocess,sys

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['sim','test','lint','quartus','package','assets','fetch']);a,extra=p.parse_known_args()
 targets={'sim':'sim.py','test':'test_runtime.py','quartus':'compile.py','package':'package.py','assets':'prepare_assets.py','fetch':'fetch_sources.py'}
 if a.action=='lint':
  from cpu import cpu,BUILD
  cpu();subprocess.run(['verilator','--lint-only','--top-module','cubz_core','-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-WIDTH','-Wno-CASEINCOMPLETE',*[str(p) for p in sorted((ROOT/'rtl').glob('*.sv'))],str(BUILD/'t80.v')],cwd=ROOT,check=True)
 else:
  subprocess.run([sys.executable,'-B',ROOT/'tools'/targets[a.action],*extra],cwd=ROOT,check=True)
  if a.action=='package':subprocess.run([sys.executable,'-B',ROOT/'tools/check_package.py'],cwd=ROOT,check=True)
if __name__=='__main__':main()
