"""Read native bitmap text using the character generators in the original ROMs."""
def mono(rom,vram,prae=False):
 base,stride=(0x34bd,5) if prae else (0x3e53,6)
 glyphs={rom[base+(c-32)*stride:base+(c-31)*stride]:chr(c) for c in range(32,96 if not prae else 128)}
 glyphs[bytes(stride)]=' '
 rows=[]
 for y in range(0,256,8):
  line=''
  for x in range(32):
   raw=[vram[(y+p)*32+x] for p in range(8)]
   if prae:
    glyph=bytes(sum(((raw[p]>>(7-i))&1)<<p for p in range(8)) for i in range(2,7))
    char=glyphs.get(glyph,'?')
   else:
    glyph=bytes(v^255 for v in raw[1:7]);char=glyphs.get(glyph,'?')
   line+=char
  rows.append(line.rstrip())
 return '\n'.join(rows)

def spectrum(rom,vram,offset=0x3d00):
 glyphs={rom[offset+(c-32)*8:offset+(c-31)*8]:chr(c) for c in range(32,127)}
 rows=[]
 for row in range(24):
  line=''
  for col in range(32):
   glyph=bytes(vram[((row*8+p)&0xc0)*32+((row*8+p)&7)*256+((row*8+p)&0x38)*4+col] for p in range(8))
   line+=glyphs.get(glyph,'?')
  rows.append(line.rstrip())
 return '\n'.join(rows)


def cpm(rom,frame):
 from PIL import Image
 image=Image.open(frame).convert('L');base=0x12b76
 glyphs={rom[base+(c-32)*8:base+(c-31)*8]:chr(c) for c in range(32,127)}
 glyphs[bytes(8)]=' ';rows=[]
 for row in range(24):
  line=''
  for col in range(80):
   glyph=bytes(sum((image.getpixel((col*4+x,row*8+y))<30)<<(7-x) for x in range(4)) for y in range(8))
   line+=glyphs.get(glyph,glyphs.get(bytes(v^0xf0 for v in glyph),'?'))
  rows.append(line.rstrip())
 return '\n'.join(rows)
