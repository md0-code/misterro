"""Check native rendered pixels against the original ROM glyphs and persisted files."""
from build import ROOT,BUILD
from project_paths import DOCS
from validate_quartus import source_hashes
import hashlib,json,struct,zlib

def ppm(path):
 data=path.read_bytes();magic,dimensions,maximum,pixels=data.split(b'\n',3)
 width,height=map(int,dimensions.split())
 if magic!=b'P6' or maximum!=b'255' or len(pixels)!=width*height*3:raise ValueError('Invalid framebuffer')
 return width,height,pixels

def contains(frame,text,font,width):
 w,h,pixels=frame;columns=256//width
 for row in range(24):
  for col in range(columns-len(text)+1):
   match=True
   for n,c in enumerate(text):
    glyph=font[(ord(c)-32)*8:(ord(c)-31)*8]
    if len(glyph)!=8:raise ValueError('ROM glyph missing')
    for y in range(8):
     for x in range(width):
      p=((row*8+y)*w+(col+n)*width+x)*3
      ink=pixels[p:p+3]==b'\0\0\0'
      if ink!=bool(glyph[y]&(1<<(width-1-x))):match=False;break
     if not match:break
    if not match:break
   if match:return True
 return False

def png(frame,path):
 w,h,rgb=frame
 def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
 raw=b''.join(b'\0'+rgb[y*w*3:(y+1)*w*3] for y in range(h))
 path.parent.mkdir(parents=True,exist_ok=True)
 path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))

def main():
 basic=(ROOT/'assets/roms/hc85.rom').read_bytes()[0x3d00:0x4000]
 basic128=(ROOT/'assets/roms/hc128.rom').read_bytes()[0x7d00:0x8000]
 cpm=(ROOT/'assets/roms/hc2000-1.rom').read_bytes()[0x25ab:0x28a3]
 checks={}
 for name in ['hc85-dos','hc90-cpm','hc91-cpm','hc128-basic','hc128-cpm','hc2000-basic','hc2000-files']:
  frame=ppm(BUILD/(name+'.ppm'));status=json.loads((BUILD/(name+'.json')).read_text())
  if name=='hc85-dos':
   if not contains(frame,'42',basic,8) or status['sd_writes']<4:raise ValueError('HC85 native DOS format/SAVE/LOAD/RUN failed')
   disk=(BUILD/(name+'-disk0.dsk')).read_bytes()
   if disk==(ROOT/'assets/disks/hc85/blank.dsk').read_bytes():raise ValueError('HC85 DOS disk was unchanged')
   if bytes.fromhex('f5 34 32 0e 00 00 2a 00 00') not in disk:raise ValueError('HC85 saved BASIC program was not persisted')
  elif name=='hc128-basic':
   if not contains(frame,'4',basic128,8) or not contains(frame,'0 OK',basic128,8):raise ValueError('HC128 128 BASIC arithmetic failed')
  elif name=='hc2000-basic':
   if not contains(frame,'6',basic,8) or not contains(frame,'0 OK',basic,8):raise ValueError('HC2000 BASIC arithmetic after F11 failed')
  elif name=='hc2000-files':
   a=(BUILD/(name+'-disk0.dsk')).read_bytes();b=(BUILD/(name+'-disk1.dsk')).read_bytes()
   if not contains(frame,'B>',cpm,4) or not contains(frame,'CHECK',cpm,4) or not contains(frame,'CPM91',cpm,4) or contains(frame,'NO FILE',cpm,4):raise ValueError('HC2000 external-drive directory or saved file missing')
   if b'CHECK   COM' not in a or status['drive_writes'][0]<1 or status['drive_reads'][1]<4:raise ValueError('Native CP/M file persistence or drive B failed')
   if b!=(ROOT/'assets/disks/hc91/system.dsk').read_bytes() or status['drive_writes'][1]!=0:raise ValueError('Read-only drive B activity changed its image')
  else:
   if not contains(frame,'CP/M',cpm,4) or not contains(frame,'A>',cpm,4) or status['sd_reads']<10:raise ValueError('Original CP/M disk boot failed: '+name)
  png(frame,DOCS/'images'/(name+'.png'))
  checks[name]={'status':'passed','framebuffer_sha256':hashlib.sha256((BUILD/(name+'.ppm')).read_bytes()).hexdigest(),'runtime':status}
 (BUILD/'expansion-capture-validation.json').write_text(json.dumps({'status':'passed','project_sources':source_hashes(),'captures':checks},indent=2)+'\n')
 print('PASS: native BASIC arithmetic, original CP/M prompts, HC85 DOS SAVE/LOAD, persistent CP/M file and external drive B')
if __name__=='__main__':main()
