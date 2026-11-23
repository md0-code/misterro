"""Behavioural gates shared by native Romanian computer cores."""
from pathlib import Path
import hashlib,json,subprocess,tempfile

def hashes(shared):return {p.relative_to(shared).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for folder in ['rtl','sim'] for p in sorted((shared/folder).rglob('*')) if p.is_file()}
def run(shared,build):
 initial=hashes(shared);checks={}
 cases={'peripherals_tb':['rp_i8255','rp_i8251'],'timer_tb':['rp_i8253'],'ctc_tb':['rp_z80ctc'],'printer_tb':['rp_printer_spool'],'video_tb':['rp_tims_video'],'sdram_tb':['rp_sdram','rp_sdram_host']}
 with tempfile.TemporaryDirectory(prefix='romanian-unit-') as d:
  for top,modules in cases.items():
   binary=Path(d)/top
   subprocess.run(['iverilog','-g2012','-s',top,'-o',str(binary),*[str(shared/'rtl'/(m+'.sv')) for m in modules],str(shared/'sim'/(top+'.sv'))],check=True)
   output=subprocess.check_output(['vvp',str(binary)],text=True)
   if 'PASS' not in output:raise ValueError('Missing behavioural pass: '+top)
   print(output.strip(),flush=True);checks[top]=output.strip()
 if hashes(shared)!=initial:raise ValueError('Peripheral sources changed while testing')
 proof={'status':'passed','sources':initial,'checks':checks};(build/'unit-validation.json').write_text(json.dumps(proof,indent=2)+'\n')
 return proof
