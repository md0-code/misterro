"""Native unmodified V4 cold boot, DOS/serial/video/audio and independent disk reboot."""
from project_paths import ROOT,DOCS
from validate_quartus import source_hashes
from validation_inputs import harness_hashes
import hashlib,json,shutil,subprocess,time

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 from sim import build
 build(3);sim=ROOT/'build/sim3';inputs=json.loads((sim/'build-inputs.json').read_text())
 hw=json.loads((ROOT/'build/hardware-validation.json').read_text())
 if hw['status']!='passed' or hw['project_sources']!=source_hashes():raise ValueError('Run current hardware memory regression')
 media=ROOT/'assets/demo.img';media_hash=digest(media);rom_hash=digest(ROOT/'assets/boot.rom');results=[]
 for name,scenario,disk in [('first','first',media),('persist','persist',ROOT/'build/acceptance-first/modified.img')]:
  work=ROOT/('build/acceptance-'+name);work.mkdir(exist_ok=True)
  for f in ['mcl86_ucode.mem','cga.hex','hgc.hex','splash_320x200.hex']:shutil.copyfile(sim/f,work/f)
  start=time.time_ns();log=ROOT/('build/acceptance-'+name+'.log');disk_hash=digest(disk)
  print('Running native V4 cold-boot acceptance:',name,flush=True)
  with log.open('w') as f:r=subprocess.run([str(sim/'sim'),str(ROOT/'assets/boot.rom'),str(disk),'40',scenario],cwd=work,stdout=f,stderr=subprocess.STDOUT)
  text=log.read_text(errors='replace')
  if r.returncode or 'RESULT: PASS native unmodified BIOS' not in text:
   print('\n'.join(text.splitlines()[-35:]));raise RuntimeError('Native acceptance failed: '+name)
  if '640 KiB' not in text or 'DOS BOOTED' not in text:raise ValueError('Missing genuine POST/DOS completion')
  results.append({'scenario':name,'input_disk_sha256':disk_hash,'output_disk_sha256':digest(work/'modified.img'),'log_sha256':digest(log),'elapsed_seconds':round((time.time_ns()-start)/1e9,1)})
 first=ROOT/'build/acceptance-first'
 from PIL import Image
 for name in ['demo-text','demo-color','demo-mono']:
  frame=Image.open(first/(name+'.ppm')).convert('RGB')
  if frame.width<600 or frame.height<190 or len(frame.getcolors(frame.width*frame.height) or [])<2:raise ValueError('Invalid native raster: '+name)
  frame.resize((1280,960),Image.Resampling.NEAREST).save(DOCS/'images'/(name+'.png'))
 if inputs['project_sources']!=source_hashes() or inputs['harness_sha256']!=harness_hashes() or media_hash!=digest(media) or rom_hash!=digest(ROOT/'assets/boot.rom'):raise ValueError('Runtime inputs changed during acceptance')
 result={'status':'passed',**inputs,'media_sha256':media_hash,'bios_sha256':rom_hash,'checks':['unmodified V4 cold POST, 640 KiB, PIT/PIC and keyboard','native floppy DMA FreeDOS boot','keyboard-driven DOS create, TYPE and independent reboot/delete','original BIOS INT 14h SIO loopback','native text/320x200/640x200 raster captures and exact VRAM contents','native speaker waveform and return to DOS',*hw['checks']],'scenarios':results}
 (ROOT/'build/runtime-validation.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS: complete native JUNIOR-XT acceptance')
if __name__=='__main__':main()
