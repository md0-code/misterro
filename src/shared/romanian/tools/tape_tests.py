"""Exercise the installed cassette player, including dense RAM and TZX modes."""
from pathlib import Path
import hashlib,json,subprocess
import assets

def run(root,shared):
 build=root/'build';up=root/'vendor/spectrum'
 if not up.exists():up=root.parent/'core-hc/vendor/spectrum'
 dep=json.loads((assets.docs(root)/'dependencies.lock.json').read_text())
 vhdl=up/'rtl/tzxplayer.vhd';target=build/'tzxplayer.v';stamp=build/'tzxplayer.sha256'
 fingerprint=hashlib.sha256(dep['ghdl_image'].encode()+vhdl.read_bytes()).hexdigest()
 if not target.exists() or not stamp.exists() or stamp.read_text()!=fingerprint:
  data=subprocess.check_output(['docker','run','--rm','--network','none','--entrypoint','ghdl','-v',str(up)+':/up',dep['ghdl_image'],'--synth','--std=08','-fsynopsys','--out=verilog','-gTZX_MS=3500','/up/rtl/tzxplayer.vhd','-e','tzxplayer']).decode()
  target.write_text(data.replace('module tzxplayer\n','module tzxplayer #(parameter TZX_MS = 3500)\n'));stamp.write_text(fingerprint)
 sources=[shared/'rtl/rp_tape.sv',up/'rtl/tape.sv',up/'rtl/pzxplayer.sv',target]
 checks={}
 for top,mode in [('tape_memory_tb',None),('tape_controls_tb',None),('tape_mode_tb',0),('tape_mode_tb',1)]:
  label=top+('' if mode is None else str(mode));obj=build/label
  command=['verilator','--binary','--timing','-j','4','-Wno-fatal','-Wno-WIDTH','-Wno-CASEINCOMPLETE','-Wno-COMBDLY','--top-module',top,'--Mdir',str(obj)]
  if mode is not None:command+=['-GMODE48='+str(mode)]
  with (build/(label+'.log')).open('w') as log:subprocess.run([*command,*map(str,sources),str(shared/'sim'/(top+'.sv'))],stdout=log,stderr=subprocess.STDOUT,check=True)
  output=subprocess.check_output([str(obj/('V'+top))],text=True)
  if 'PASS' not in output:raise ValueError('Cassette test failed: '+label)
  print(output.strip(),flush=True);checks[label]=output.strip()
 (build/'tape-validation.json').write_text(json.dumps({'status':'passed','checks':checks,'sources':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}},indent=2)+'\n')
