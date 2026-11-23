"""Verify the installation media and offline standalone source build."""
from project_paths import ROOT
from pathlib import Path,PurePosixPath
import hashlib,json,subprocess,sys,tempfile,zipfile,struct

def main():
 package=ROOT/'dist/JUNIORXT.zip';digest=hashlib.sha256(package.read_bytes()).hexdigest()
 if digest!=package.with_suffix('.zip.sha256').read_text().split()[0]:raise ValueError('Package checksum mismatch')
 with zipfile.ZipFile(package) as z:
  expected={n:h for h,n in (line.split('  ',1) for line in z.read('SHA256SUMS').decode().splitlines())}
  if set(z.namelist())!=set(expected)|{'SHA256SUMS'}:raise ValueError('Manifest membership mismatch')
  for n,h in expected.items():
   if n.startswith('/') or '..' in PurePosixPath(n).parts or hashlib.sha256(z.read(n)).hexdigest()!=h:raise ValueError('Unsafe or corrupt member: '+n)
  runtime=json.loads(z.read('docs/runtime-validation.json'))
  for scenario in runtime['scenarios']:
   if hashlib.sha256(z.read('docs/native-'+scenario['scenario']+'.log')).hexdigest()!=scenario['log_sha256']:raise ValueError('Native execution log mismatch')
  software_sources=json.loads(z.read('docs/software-sources.lock.json'))
  for name,v in software_sources.items():
   data=z.read('source/docs/reference/'+name)
   if len(data)!=v['bytes'] or hashlib.sha256(data).hexdigest()!=v['sha256']:raise ValueError('DOS source archive mismatch: '+name)
  import xml.etree.ElementTree as ET
  mgl=ET.fromstring(z.read('_Computer/JUNIORXT.mgl'))
  if mgl.findtext('rbf')!='_Computer/.JUNIORXT/JUNIORXT' or mgl.findtext('setname')!='JUNIORXT':raise ValueError('Wrong public launch identity')
  entries=mgl.findall('file')
  if len(entries)!=1 or entries[0].get('type')!='f' or entries[0].get('index')!='0' or entries[0].get('path')!='boot.rom':raise ValueError('Wrong automatic BIOS loader')
  if 'UART9600:19200:'  not in z.read('source/mister/menu.sv').decode():raise ValueError('Missing native host serial speeds')
  if 'CORE_NAME="PCXT"' not in z.read('source/mister/config.tcl').decode():raise ValueError('Missing PCXT HPS protocol identity')
  if '_Computer/.JUNIORXT/JUNIORXT.rbf' not in expected:raise ValueError('Missing launcher bitstream')
  required={'boot.rom','demo.img','manual.img','bundle.json','support/chargen.rom','bios/bios-3.0.rom','bios/bios-5.0.rom','bios/bios-5.0-alt.rom'}
  if {n[len('games/JUNIORXT/'):] for n in expected if n.startswith('games/JUNIORXT/')}!=required:raise ValueError('Incomplete installation media')
  rom=z.read('games/JUNIORXT/boot.rom');disk=z.read('games/JUNIORXT/demo.img');bios=rom[:65536];option=rom[65536:]
  if len(rom)!=81920 or bios[-16:-11]!=bytes.fromhex('ea00e000f0') or sum(bios)%256:raise ValueError('Wrong native firmware')
  if option[:2]!=bytes.fromhex('55aa') or sum(option[:option[2]*512])%256:raise ValueError('Wrong Winchester ROM')
  if len(disk)!=327680 or struct.unpack_from('<H',disk,24)[0]!=8:raise ValueError('Wrong native disk geometry')
  if disk[510:512]!=bytes.fromhex('55aa'):raise ValueError('Missing DOS boot signature')
  bundle=json.loads(z.read('games/JUNIORXT/bundle.json'))
  for n,v in bundle['files'].items():
   if hashlib.sha256(z.read('games/JUNIORXT/'+n)).hexdigest()!=v['sha256']:raise ValueError('Bundle manifest mismatch')
  with tempfile.TemporaryDirectory(prefix='juniorxt-source-check-') as folder:
   z.extractall(folder);source=Path(folder)/'source'
   for script in ['build_hdrom','prepare_assets','build_software','prepare_quartus','test_serial']:
    subprocess.run([sys.executable,'-B','tools/'+script+'.py'],cwd=source,check=True,stdout=subprocess.DEVNULL)
   if hashlib.sha256((source/'assets/demo.img').read_bytes()).hexdigest()!=hashlib.sha256(disk).hexdigest():raise ValueError('Demo image is not reproducible')
   if (source/'assets/boot.rom').read_bytes()!=rom:raise ValueError('Firmware is not reproducible')
 result={'status':'passed','zip_sha256':digest,'files':len(expected),'checks':['all ZIP members and bundle hashes','native V4 checksum and reset vector','Winchester ROM signature and checksum','320K eight-sector DOS boot image','manual, schematic, demo and manual disks, four BIOS revisions and character ROM','offline standalone firmware/media reproduction','standalone native serial regression and Quartus source preparation']}
 (ROOT/'build/package-validation.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS: complete package and standalone source export')
if __name__=='__main__':main()
