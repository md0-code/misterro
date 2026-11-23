"""Validate the 84 MHz cassette adapter against transport and packed-RAM gates."""
from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[1];shared=root/'shared/romanian'
if not shared.exists():shared=root.parent/'shared/romanian'
doc=root/'docs'
if not (doc/'dependencies.lock.json').exists():doc=root.parent.parent/'docs/tims'
build=root/'build';build.mkdir(exist_ok=True);up=root/'vendor/spectrum'
if not up.exists():up=root.parent/'core-hc/vendor/spectrum'
dep=json.loads((doc/'dependencies.lock.json').read_text());vhdl=up/'rtl/tzxplayer.vhd';target=build/'tzxplayer.v';stamp=build/'tzxplayer.sha256'
fingerprint=hashlib.sha256(dep['ghdl_image'].encode()+vhdl.read_bytes()).hexdigest()
if not target.exists() or not stamp.exists() or stamp.read_text()!=fingerprint:
 data=subprocess.check_output(['docker','run','--rm','--network','none','--entrypoint','ghdl','-v',str(up)+':/up',dep['ghdl_image'],'--synth','--std=08','-fsynopsys','--out=verilog','-gTZX_MS=3500','/up/rtl/tzxplayer.vhd','-e','tzxplayer']).decode()
 target.write_text(data.replace('module tzxplayer\n','module tzxplayer #(parameter TZX_MS = 3500)\n'));stamp.write_text(fingerprint)
sources=[root/'mister/tims_tape.sv',shared/'rtl/rp_tape.sv',up/'rtl/tape.sv',up/'rtl/pzxplayer.sv',target];checks={};local=[root/'mister/tims_tape.sv']
for top,mode in [('tims_tape_memory_tb',None),('tims_tape_controls_tb',None),('tims_tape_mode_tb',0),('tims_tape_mode_tb',1)]:
 label=top+('' if mode is None else str(mode));obj=build/label;bench=root/'mister'/(top+'.sv');local.append(bench)
 command=['verilator','--binary','--timing','-j','4','-Wno-fatal','-Wno-WIDTH','-Wno-CASEINCOMPLETE','-Wno-COMBDLY','--top-module',top,'--Mdir',str(obj)]
 if mode is not None:command+=['-GMODE48='+str(mode)]
 with (build/(label+'.log')).open('w') as log:subprocess.run([*command,*map(str,sources),str(bench)],stdout=log,stderr=subprocess.STDOUT,check=True)
 output=subprocess.check_output([str(obj/('V'+top))],text=True)
 if 'PASS' not in output:raise ValueError('TIMS cassette adapter failed: '+label)
 print(output.strip(),flush=True);checks[label]=output.strip()
(build/'adapter-validation.json').write_text(json.dumps({'status':'passed','checks':checks,'inputs':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in set(local)}},indent=2)+'\n')
