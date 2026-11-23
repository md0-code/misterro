"""Exercise original firmware, CP/M boot, a real application and disk persistence."""
from project_paths import ROOT,DOCS
from validate_quartus import source_hashes
from cpu import run,BUILD
import subprocess,hashlib,json,sys

def launch(name,args,build=False):
 command=[sys.executable,ROOT/'tools/sim.py'] if build else [BUILD/'obj/Vcubz_core']
 with (BUILD/(name+'-run.log')).open('w') as out:
  subprocess.run([*map(str,command),*map(str,args),'--output','build/'+name],cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,check=True)
 text=(BUILD/(name+'-console-clean.txt')).read_text(errors='replace');status=json.loads((BUILD/(name+'-status.json')).read_text())
 if status['keyboard_overflow']:raise ValueError('Keyboard overflow: '+name)
 print('PASS:',name,status,flush=True);return text,status

def main():
 BUILD.mkdir(exist_ok=True);original=source_hashes();asset=ROOT/'assets/disks/cpm.dsk';disk_hash=hashlib.sha256(asset.read_bytes()).hexdigest()
 run([sys.executable,ROOT/'tools/prepare_assets.py']);run([sys.executable,ROOT/'tools/test_units.py'])
 results={}
 for rev in ['v13','v14']:
  name='test-monitor-'+rev
  text,status=launch(name,['--rom','assets/roms/cubz-'+rev+'.rom','--seconds','6','--until','\r\n.','--type','D 0000'],build=rev=='v13')
  if 'D 0000' not in text:raise ValueError('Original monitor keyboard echo failed: '+rev)
  results[name]=status
 commands=BUILD/'test-commands.txt';commands.write_bytes(b'DIR\rSAVE 1 CUBZTEST.COM\rDIR CUBZTEST.COM\r')
 name='test-cpm';text,status=launch(name,['--seconds','8','--until','A>','--disk',asset,'--exercise-turbo','--type-file',commands])
 if not all(t in text for t in ['57K CP/M','TURBO','Include error messages','Logged drive:','CUBZTEST COM']):raise ValueError('Native CP/M or application output missing')
 if status['sd_writes']<2 or status['dma_bytes']<32768:raise ValueError('Disk read/write paths not exercised')
 results[name]=status;modified=BUILD/(name+'-disk.dsk')
 if modified.stat().st_size!=asset.stat().st_size or hashlib.sha256(modified.read_bytes()).hexdigest()==disk_hash:raise ValueError('No persistent image changes')
 commands.write_bytes(b'DIR CUBZTEST.COM\rERA CUBZTEST.COM\rDIR CUBZTEST.COM\r')
 name='test-persist';text,status=launch(name,['--seconds','8','--until','A>','--disk',modified,'--type-file',commands])
 if 'CUBZTEST COM' not in text or 'NO FILE' not in text.upper():raise ValueError('Reopened disk file or deletion not verified')
 if not status['sd_writes']:raise ValueError('Deletion not flushed to image')
 results[name]=status
 if source_hashes()!=original or hashlib.sha256(asset.read_bytes()).hexdigest()!=disk_hash:raise ValueError('Sources or original demo disk changed during validation')
 proof={'status':'passed','project_sources':original,'original_disk_sha256':disk_hash,'checks':['original v1.3 and v1.4 monitor boot and keyboard echo','exact original boot-sector bytes copied through DMA','native 57K CP/M boot','TURBO.COM load, native menu, keyboard and exit','CP/M DIR and SAVE','saved file found after independent reboot','ERA persistence and missing-file result','keyboard serial/repeat, DMA ownership/count/TC, CTC IRQ/vector/priority/RETI, raster and scroll units'],'runs':results,'harness_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [*sorted((ROOT/'sim').iterdir()),ROOT/'tools/cpu.py',ROOT/'tools/test_runtime.py'] if p.is_file()}}
 (BUILD/'runtime-validation.json').write_text(json.dumps(proof,indent=2)+'\n');print('PASS: current complete native runtime validation')
if __name__=='__main__':main()
