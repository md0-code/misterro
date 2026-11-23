from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
SHARED=ROOT/'shared/romanian'
if not SHARED.exists():SHARED=ROOT.parent/'shared/romanian'
sys.path.insert(0,str(SHARED/'tools'))
from toolchain import main
if __name__=='__main__':
 if len(sys.argv)>1 and sys.argv[1]=='test':
  import subprocess
  subprocess.run([sys.executable,str(ROOT/'tools/decoder_test.py')],check=True)
  subprocess.run([sys.executable,str(ROOT/'tools/hardware_test.py')],check=True)
 main(ROOT,SHARED)
