"""Verify native HC88 framebuffer glyphs and save readable runtime captures."""
from project_paths import ROOT,DOCS
from pathlib import Path
from PIL import Image
import hashlib,json
BUILD=ROOT/'build'
FONT=(ROOT/'assets/roms/hc85.rom').read_bytes()[0x3d00:0x4000]

def rows(vram,columns):
 width=6 if columns==80 else 8
 glyphs={bytes((value>>1)&63 if width==6 else value for value in FONT[(c-32)*8:(c-31)*8]):chr(c) for c in range(32,127)}
 result=[]
 for row in range(24):
  text=''
  for col in range(columns):
   glyph=[]
   for line in range(8):
    y=row*8+line;bits=0
    for dot in range(width):
     x=col*width+dot;byte=x//8;bank=(byte&1) if columns==80 else 0;column=byte//2 if columns==80 else byte
     address=bank*8192+((y&192)<<5)+((y&7)<<8)+((y&56)<<2)+column
     bits=(bits<<1)|((vram[address]>>(7-(x&7)))&1)
    glyph.append(bits)
   text+=glyphs.get(bytes(glyph),'?')
  result.append(text.rstrip())
 return result

def picture(vram,hires,target):
 width=512 if hires else 256;image=Image.new('RGB',(width,192));pixels=image.load()
 for y in range(192):
  for x in range(width):
   byte=x//8;bank=(byte&1) if hires else 0;col=byte//2 if hires else byte
   bitmap=vram[bank*8192+((y&192)<<5)+((y&7)<<8)+((y&56)<<2)+col]
   attribute=vram[bank*8192+6144+(y//8)*32+col];ink=(bitmap>>(7-(x&7)))&1
   colour=(attribute&7) if ink else (attribute>>3)&7;level=255 if attribute&64 else 192
   pixels[x,y]=(level if colour&2 else 0,level if colour&4 else 0,level if colour&1 else 0)
 image.resize((width*2,384),Image.Resampling.NEAREST).save(target)

def main(basic_prefix="hc88-runtime"):
 reports={};captures={}
 for stage,columns in [('runtime',80),('runtime-reset',80),('runtime-basic',32),('runtime-tape',32)]:
  prefix='hc88-runtime' if stage=='runtime' else basic_prefix+stage[len('runtime'):]
  path=BUILD/f'{prefix}-vram.bin';data=path.read_bytes()
  if len(data)!=16384:raise ValueError('Incomplete native framebuffer: '+stage)
  reports[stage]=rows(data,columns);captures[path.name]=hashlib.sha256(data).hexdigest()
 if not any(line.strip()=='4' for line in reports['runtime-basic']):raise ValueError('Native BASIC framebuffer did not show 4')
 if not any(line.strip()=='7319' for line in reports['runtime-tape']):raise ValueError('EAR-loaded BASIC did not display 7319')
 for stage in ['runtime','runtime-reset']:
  if 'HC-88 persistent floppy write verified.' not in '\n'.join(reports[stage]):raise ValueError('Native terminal framebuffer missing persistent file contents: '+stage)
 console=(BUILD/(basic_prefix+'-reset-console.txt')).read_text()
 if basic_prefix!='hc88-runtime':console+=(BUILD/'hc88-runtime-console.txt').read_text()
 if console.count('HC-88 persistent floppy write verified.')<2:raise ValueError('File was not reread after F11')
 for stage,hires in [('runtime',True),('runtime-demo',True),('runtime-basic',False),('runtime-tape',False)]:
  prefix='hc88-'+stage if stage in ['runtime','runtime-demo'] else basic_prefix+stage[len('runtime'):]
  picture((BUILD/f'{prefix}-vram.bin').read_bytes(),hires,BUILD/f'hc88-{stage}.png')
 receipt={'status':'passed','framebuffer_sha256':captures,'rows':reports,'checks':['Independent 80-column glyph decoding','BASIC PRINT 2+2 pixels','Native EAR-loaded PRINT 7319 pixels','Persistent file contents before and after F11']}
 (BUILD/'hc88-capture-validation.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print('PASS: independent HC88 terminal, BASIC, cassette and post-reset framebuffer checks')
if __name__=='__main__':main()
