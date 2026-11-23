from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
SHARED=ROOT/'shared/romanian'
if not SHARED.exists():SHARED=ROOT.parent/'shared/romanian'
sys.path.insert(0,str(SHARED/'tools'))
from toolchain import main
if __name__=='__main__':main(ROOT,SHARED)
