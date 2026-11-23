"""Original firmware, native CPU bus and peripheral validation."""
from pathlib import Path
from PIL import Image,ImageOps
import hashlib,json,re,shutil,subprocess
import assets,diagnostics,unit_tests,tape_tests,screens

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def ocr(path,out,box=None):
 image=Image.open(path).convert('L');image=ImageOps.autocontrast(image)
 if box:image=image.crop(box)
 if image.getpixel((0,0))<128:image=ImageOps.invert(image)
 image=ImageOps.expand(image,10,255);image=image.resize((image.width*4,image.height*4),Image.Resampling.NEAREST);image.save(out)
 command=shutil.which('tesseract');target=str(out)
 if not command:
  command='/mnt/c/Program Files/Tesseract-OCR/tesseract.exe'
  if not Path(command).exists():raise ValueError('Install tesseract-ocr to verify original firmware screens')
  target=subprocess.check_output(['wslpath','-w',str(out)],text=True).strip()
 text=subprocess.check_output([command,target,'stdout','--psm','6'],stderr=subprocess.DEVNULL,text=True)
 return text

def main(root,shared,profile,source_hashes,diagnostic_only=False):
 build=root/'build';original=source_hashes()
 def runtime_inputs():return {'docs/runtime-cases.json':sha(assets.docs(root)/'runtime-cases.json'),**{p.relative_to(root).as_posix():sha(p) for p in sorted((root/'sim').rglob('*')) if p.is_file()}}
 def tool_inputs():return {p.relative_to(shared).as_posix():sha(p) for p in sorted((shared/'tools').glob('*.py')) if p.stem in ['toolchain','assets','diagnostics','unit_tests','tape_tests','runtime_tests','screens']}
 initial_runtime=runtime_inputs();initial_tools=tool_inputs();initial_assets=json.loads((assets.docs(root)/'sources.lock.json').read_text())
 if not diagnostic_only:assets.verify(root);unit_tests.run(shared,build);tape_tests.run(root,shared)
 binary=root/json.loads((build/'simulator-build.json').read_text())['binary'];runs={}
 for label,status,rom,marker in diagnostics.prepare(root,profile):
  prefix=build/label
  extra=['--joy','20'] if profile['name'] in ['JET','COBRA'] else []
  if label=='ports-plus':
   script=build/'network.script';script.write_text('network 0\nwait 0.01\n');extra=['--script',str(script),'--disk','0','assets/disks/blank.dsk']
  if label=='ports-keyboard-plus':
   script=build/'keyboard.script';script.write_text('key 66\nrelease 66\nwait 0.01\n');extra=['--script',str(script)]
  subprocess.run([str(binary),'--rom',str(rom),'--status',str(status),'--seconds','0.7' if label=='ports-plus' else '0.2','--loopback','--output',str(prefix),*extra],cwd=root,check=True)
  ram=prefix.with_name(prefix.name+'-ram.bin').read_bytes()
  if ram[marker:marker+6]!=b'RPASS!':raise ValueError('Native CPU bus diagnostic failed: '+label+' at '+hex(marker)+' '+ram[marker:marker+6].hex())
  if label=='ports-plus':
   if ram[0x8106]!=1:raise ValueError('Native network NMI did not wake the Z80')
   if prefix.with_name(prefix.name+'-printer.bin').read_bytes()!=b'A':raise ValueError('Native Centronics output')
  state=json.loads(prefix.with_name(prefix.name+'-state.json').read_text());runs[label]={'state':state,'diagnostic_sha256':sha(rom),'ram_sha256':sha(prefix.with_name(prefix.name+'-ram.bin'))}
 if diagnostic_only:
  if source_hashes()!=original:raise ValueError('Hardware changed during diagnostics')
  (build/'bus-validation.json').write_text(json.dumps({'status':'passed','inputs':original,'runs':runs},indent=2)+'\n');print('PASS native CPU bus diagnostics',profile['name']);return
 if profile['name'] in ['COBRA','TIMS']:
  obj=build/'fdc-obj';sources=[shared/'rtl/rp_u765.sv',shared/'sim/rp_fdc_sim.sv',shared/'sim/rp_fdc_main.cpp']
  with (build/'fdc-build.log').open('w') as log:subprocess.run(['verilator','--cc','--exe','--build','-j','4','--top-module','rp_fdc_sim','-Wno-fatal','-Wno-WIDTH','-Wno-CASEINCOMPLETE','--Mdir',str(obj),*map(str,sources)],check=True,stdout=log,stderr=subprocess.STDOUT)
  subprocess.run([str(obj/'Vrp_fdc_sim'),str(build/'fdc-validation.json')],check=True,cwd=root)
 cases=json.loads((assets.docs(root)/'runtime-cases.json').read_text())
 for label,case in cases.items():
  prefix=build/('verify-'+label);command=[str(binary),'--output',str(prefix),*case['arguments']]
  subprocess.run(command,cwd=root,check=True)
  state=json.loads(prefix.with_name(prefix.name+'-state.json').read_text())
  if not state['boot_ready'] or state['fetches']<case.get('minimum_fetches',10000):raise ValueError('Original firmware did not execute: '+label)
  ppm=prefix.with_suffix('.ppm');png=prefix.with_suffix('.png');Image.open(ppm).save(png)
  name=profile['name'];firmware=(root/'assets/roms/boot.rom').read_bytes();vram=prefix.with_name(prefix.name+'-vram.bin').read_bytes()
  if name in ['AMIC','PRAE']:text=screens.mono(firmware,vram,name=='PRAE')
  elif name in ['JET','TIMS']:text=screens.spectrum(firmware,vram,0x14500 if label=='plus-menu' else 0x3d00)
  elif name=='COBRA' and label.startswith('basic'):text=screens.spectrum(firmware,vram,0xbd00)
  else:text=screens.cpm(firmware,ppm)
  prefix.with_suffix('.txt').write_text(text)
  if re.search(r'TAPE.LOADING.ERROR|SYNTAX.ERROR|CHECKSUM.ERROR|BAD.CHECKSUM',text,re.I):raise ValueError('Native firmware reported an error: '+label+' '+text)
  for expected in case.get('screen',[]):
   if not re.search(expected,text,re.I|re.M):raise ValueError('Missing native firmware screen text '+repr(expected)+' in '+repr(text))
  if state['sd_reads']<case.get('minimum_sd_reads',0) or state['sd_writes']<case.get('minimum_sd_writes',0):raise ValueError('Native disk software did not access persistent media: '+label)
  disks={}
  for drive,pattern in case.get('disk_contains_hex',{}).items():
   image=prefix.with_name(prefix.name+'-disk'+drive+'.dsk')
   if bytes.fromhex(pattern) not in image.read_bytes():raise ValueError('Native disk directory did not persist: '+label)
   disks[drive]=sha(image)
  runs[label]={'disk_sha256':disks,'state':state,'frame_sha256':sha(ppm),'screen_text':text,'arguments':case['arguments']}
 if source_hashes()!=original:raise ValueError('Hardware changed while validating runtime')
 stamp=json.loads((build/'simulator-build.json').read_text())
 if stamp['inputs']!=original or stamp['binary_sha256']!=sha(binary):raise ValueError('Simulator build changed while testing')
 if initial_runtime!=runtime_inputs() or initial_tools!=tool_inputs() or initial_assets!=json.loads((assets.docs(root)/'sources.lock.json').read_text()):raise ValueError('Validation inputs changed while testing')
 proof={'runtime_sources':initial_runtime,'status':'passed','inputs':original,'simulator':stamp,'assets':initial_assets,'tools':initial_tools,'runs':runs}
 (build/'runtime-validation.json').write_text(json.dumps(proof,indent=2)+'\n');print('PASS native firmware and peripheral runtime',profile['name'])
