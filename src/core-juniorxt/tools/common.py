from project_paths import ROOT,DOCS
import subprocess,json,hashlib
BUILD=ROOT/'build'
def run(args,log=None,**kwargs):
 print('+ '+str(args[0])+' ('+str(len(args)-1)+' arguments)',flush=True)
 if log:
  with (BUILD/log).open('w') as f:r=subprocess.run(list(map(str,args)),cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,**kwargs)
  if r.returncode:
   print('\n'.join(line[:250] for line in (BUILD/log).read_text(errors='replace').splitlines()[-35:]),flush=True)
   raise RuntimeError(str(args[0])+' failed; see '+str(BUILD/log))
 else:subprocess.run(list(map(str,args)),cwd=ROOT,check=True,**kwargs)
