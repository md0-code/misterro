from project_paths import ROOT,DOCS
import hashlib,json,zipfile

def main():
 ref=DOCS/'reference';out=ROOT/'assets';out.mkdir(exist_ok=True)
 lock=json.loads((DOCS/'sources.lock.json').read_text())
 for name,v in lock.items():
  b=(ref/name).read_bytes()
  if len(b)!=v['bytes'] or hashlib.sha256(b).hexdigest()!=v['sha256']:raise ValueError('Source mismatch: '+name)
 for revision in ['3.0','4.0','5.0','5.0-alt']:
  with zipfile.ZipFile(ref/('bios-'+revision+'.zip')) as z:
   parts={Path(n).name.lower():z.read(n) for n in z.namelist() if not n.endswith('/')}
   a=parts['ic63_m27c256.bin'];b=parts['ic64_m27c256.bin'];assert len(a)==len(b)==32768
   rom=bytearray(65536);rom[::2]=a;rom[1::2]=b
  assert rom[-16:-11]==bytes.fromhex('ea00e000f0') and sum(rom)%256==0
  (out/('bios-'+revision+'.rom')).write_bytes(rom)
 with zipfile.ZipFile(ref/'video.zip') as z:
  names=[n for n in z.namelist() if n.lower().endswith('.bin')];assert len(names)==1
  font=z.read(names[0]);assert len(font)==2048
 (out/'chargen.rom').write_bytes(font)
 (out/'cga.hex').write_text(''.join(f'{x:02x}\n' for x in font*2))
 # Monochrome coupler font: the 8 glyph rows placed in the 14-line cell (MezinXT's rule).
 # hgc.hex holds lines 0-7 of every character, then lines 8-15.
 text=[-1,0,0,1,2,2,3,4,4,5,6,6,7,7];cell=bytearray(4096)
 for c in range(256):
  for line in range(14):
   row=(2*line+1)*2//7 if 0xB0<=c<=0xDF else text[line]
   cell[(line>>3)*2048+c*8+(line&7)]=0 if row<0 else font[c*8+row]
 (out/'hgc.hex').write_text(' '.join(f'{x:02X}' for x in cell)+'\n')
 # boot.rom: the BIOS, then the Winchester ROM padded to the 16 KiB socket.
 hdd=(out/'hdd.rom').read_bytes();assert len(hdd)<=16384 and hdd[:2]==b'\x55\xaa' and sum(hdd)%256==0
 for revision in ['3.0','4.0','5.0','5.0-alt']:
  (out/('boot-'+revision+'.rom')).write_bytes((out/('bios-'+revision+'.rom')).read_bytes()+hdd+bytes([255])*(16384-len(hdd)))
 (out/'boot.rom').write_bytes((out/'boot-4.0.rom').read_bytes())
 print('PASS: source checksums, four native interleaved BIOSes and native character ROM')
from pathlib import Path
if __name__=='__main__':main()
