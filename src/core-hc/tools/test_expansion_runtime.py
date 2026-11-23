"""Run original HC BASIC/CPM ROMs against their disk media without CPU traps."""
from build import *
from validate_quartus import source_hashes
import concurrent.futures

def main():
 original=source_hashes()
 run([sys.executable,ROOT/'tools/build_expansion_sim.py'])
 executable=BUILD/'expansion-obj/Vhc_expansion_sim'
 tests={
 'hc85-dos':['--model','0','--if1','--seconds','3','--disk','assets/disks/hc85/blank.dsk','--script','sim/scripts/hc85-dos.txt'],
 'hc90-cpm':['--model','1','--if1','--boot-cpm','--seconds','.01','--disk','assets/disks/hc91/system.dsk','--script','sim/scripts/cpm-dir.txt'],
 'hc91-cpm':['--model','2','--if1','--seconds','3','--cpm','--disk','assets/disks/hc91/system.dsk','--script','sim/scripts/cpm-dir.txt'],
 'hc128-basic':['--model','4','--if1','--seconds','3','--script','sim/scripts/hc128-basic.txt'],
 'hc128-cpm':['--model','4','--if1','--break','--seconds','.01','--disk','assets/disks/hc91/system.dsk','--script','sim/scripts/cpm-dir.txt'],
 'hc2000-basic':['--model','5','--seconds','3','--script','sim/scripts/hc2000-basic.txt'],
 'hc2000-files':['--model','5','--boot-cpm','--seconds','.01','--disk','assets/disks/hc2000/system.dsk','--disk-b','assets/disks/hc91/system.dsk','--script','sim/scripts/hc2000-files.txt']}
 def test(item):
  name,args=item
  with (BUILD/(name+'.log')).open('w') as log:subprocess.run([executable,*args,'--output','build/'+name],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
  print('Finished native',name,flush=True)
 with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(test,tests.items()))
 if source_hashes()!=original:raise ValueError('Sources changed during native runtime tests')
 finalize(original,list(tests))

def finalize(original,names=None):
 if names is None:names=['hc85-dos','hc90-cpm','hc91-cpm','hc128-basic','hc128-cpm','hc2000-basic','hc2000-files']
 if source_hashes()!=original:raise ValueError('Sources changed during native runtime tests')
 run([sys.executable,ROOT/'tools/check_expansion_captures.py'])
 proof={'status':'passed','project_sources':original,'models':['HC85','HC90','HC91','HC128','HC2000'],'runs':{name:json.loads((BUILD/(name+'.json')).read_text()) for name in names},'firmware_sha256':hashlib.sha256((ROOT/'assets/roms/family.rom').read_bytes()).hexdigest(),'simulator':json.loads((BUILD/'expansion-sim-inputs.json').read_text())}
 (BUILD/'expansion-validation.json').write_text(json.dumps(proof,indent=2)+'\n')
if __name__=='__main__':main()
