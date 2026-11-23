"""CPU-executed native bus diagnostics; no memory injection or CPU-register shortcuts."""
from pathlib import Path
import subprocess

def prepare(root,profile):
 name=profile['name'];build=root/'build';romsize=profile['firmware_bytes']
 common='di\n ld sp,0bfffh\n'
 def out(port,value):return f' ld bc,{port:05x}h\n ld a,{value:03x}h\n out (c),a\n'
 def compare(port,value):return f' ld bc,{port:05x}h\n in a,(c)\n cp {value:03x}h\n jp nz,fail\n'
 def mem(addr,value):return f' ld a,{value:03x}h\n ld ({addr:05x}h),a\n ld a,({addr:05x}h)\n cp {value:03x}h\n jp nz,fail\n'
 def uart(data,command):
  return out(command,0x4e)+out(command,0x37)+out(data,0xa5)+f' ld bc,{command:05x}h\n rx{data:x}: in a,(c)\n and 2\n jr z,rx{data:x}\n'+compare(data,0xa5)+f' ld bc,{command:05x}h\n in a,(c)\n and 080h\n cp 080h\n jp nz,fail\n'
 programs=[]
 if name=='AMIC':
  s=common+out(0x23,0x92)+out(0x22,0)+compare(0x20,255)+compare(0x21,255)+out(0x43,0x80)
  for port,val in [(0x40,0xa5),(0x41,0x5a),(0x42,0x3c)]:s+=out(port,val)+compare(port,val)
  s+=uart(0,1)+mem(0x8000,0x63);programs=[('ports',0,s,0xb100)]
 elif name=='PRAE':
  s=common+compare(0x0080,0xff)+out(0x80,0)+out(0x80,0xc0)+mem(0x4000,0x63)+mem(0xe000,0xa5)
  programs=[('ports',0,s,0xc100)]
 elif name=='JET':
  s=common+compare(0x00fe,0xff)+compare(0x001f,0x14)+out(0xfe,0x1f)+mem(0x4000,0xa5)+mem(0xffff,0x5a)
  programs=[('ports',0,s,0xc100)]
 elif name=='COBRA':
  common+=' ld a,080h\n ld r,a\n'
  s=common+out(0xdf,0x92)+out(0xfe,0x40)+compare(0x00fe,0x7f)+compare(0x001f,0x14)+mem(0x8100,0x63)+mem(0xc000,0xa5)+out(0xfe,0)+mem(0xc000,0x5a)+out(0xfe,0x40)
  s+=' ld a,(0c000h)\n cp 0a5h\n jp nz,fail\n'+compare(0xf5,0x80)+out(0xe3,0xd7)+out(0xe3,3)
  # Three CTC pulses are generated from the real interrupt / DRQ input in disk tests.
  programs=[('ports80',0,s,0x8200),('ports64',64,common+out(0xdf,0x92)+out(0xfe,0x40)+compare(0x00fe,0x7f)+compare(0x001f,0x14)+mem(0x8100,0x63)+mem(0xc000,0xa5),0x8200)]
 elif name=='TIMS':
  s=common+out(0xe6,0x80)+out(0xe0,0xa5)+compare(0xe0,0xa5)+out(0xe2,0x5a)+compare(0xe2,0x5a)+out(0xe6,0x92)+out(0xe4,0xff)+compare(0xfe,0x7f)
  programs.append(('ports-standard',0,s,0x8100))
  s=common+out(0xdfd,0x82)+out(0xcfd,0x12)
  for bank in range(12):
   s+=out(0xcfd,0x12 if bank<8 else 0x16)+out(0x7ffd,bank if bank<8 else bank-8)+mem(0xc123,0x40+bank)
  for bank in range(12):
   s+=out(0xcfd,0x12 if bank<8 else 0x16)+out(0x7ffd,bank if bank<8 else bank-8)+f' ld a,(0c123h)\n cp {0x40+bank:03x}h\n jp nz,fail\n'
  for page in range(4):s+=out(0x7ffd,4+page)+mem(0xc100,0xa0+page)
  for page in range(4):s+=out(0x7ffd,4+page)+f' ld a,(0c100h)\n cp {0xa0+page:03x}h\n jp nz,fail\n'
  s+=out(0xcfd,0x12)
  for address,val in [(0x0f,0x34),(0x1f,0x12),(0x2f,0x3f)]:s+=out(address,val)
  s+=out(0x3f,0x6d)+compare(0x3f,0x6d)+out(0x9ffd,0x36)+out(0x9cfd,13)+out(0x9cfd,0)
  s+=uart(0xdefd,0xdffd)+out(0x9ffd,0xb6)+out(0x9efd,13)+out(0x9efd,0)
  for channel in range(3):s+=out(0x8ffd,(channel<<6)|0x36)+out(0x8cfd+(channel<<8),13)+out(0x8cfd+(channel<<8),0)
  for channel in range(4):s+=out(0xaffd,channel)+uart(0xcffd,0xeffd).replace('rx','rx'+str(channel))
  s+=compare(0x2ffd,0x80)+out(0xfffd,0)+out(0xbffd,0x55)+compare(0xfffd,0x55)
  s+=out(0x1ffd,8)+out(0x0ffd,0x41)+out(0x1ffd,24)+out(0x1ffd,8)
  for value in [3,0xdf,2,0x45,0,0,0,1,2,1,0x2a,255]:s+=f' ld a,{value:03x}h\n call fdc_send\n'
  s+=' ld de,512\n fdc_fill: ld a,0b6h\n call fdc_send\n dec de\n ld a,d\n or e\n jr nz,fdc_fill\n call fdc_results\n'
  for value in [0x46,0,0,0,1,2,1,0x2a,255]:s+=f' ld a,{value:03x}h\n call fdc_send\n'
  s+=' ld de,512\n fdc_read: call fdc_get\n cp 0b6h\n jp nz,fail\n dec de\n ld a,d\n or e\n jr nz,fdc_read\n call fdc_results\n'

  programs.append(('ports-plus',64,s,0x8100))
  keyboard=common+out(0xdfd,0x82)+out(0xcfd,0x12)
  keyboard+=' key_wait: ld bc,0fefeh\n in a,(c)\n and 01fh\n cp 01fh\n jr z,key_wait\n'
  keyboard+=compare(0xfefe,0xfe)+compare(0xeffe,0xfe)+out(0xcfd,2)+compare(0xfefe,0xff)+compare(0xeffe,0xff)
  keyboard+=' ld bc,0f7feh\n in a,(c)\n and 080h\n jp nz,fail\n'+out(0xcfd,0x12)
  programs.append(('ports-keyboard-plus',64,keyboard,0x8100))
 output=[]
 for label,status,s,marker in programs:
  if label=='ports-plus':s+=' xor a\n ld (08106h),a\n'
  arm=out(0xf3,0) if label=='ports-plus' else ''
  recover=out(0xcfd,0x12) if label=='ports-keyboard-plus' else ''
  s+=f' ld hl,passed\n ld de,{marker:05x}h\n ld bc,6\n ldir\n{arm} done: halt\n jr done\n fail: {recover} ld ({marker+6:05x}h),a\n ld a,0eeh\n ld ({marker:05x}h),a\n halt\n jr fail\n passed: db "RPASS!"\n'
  if label=='ports-plus':s+=' fdc_send: push af\n ld bc,02ffdh\n fdc_send_wait: in a,(c)\n and 0c0h\n cp 080h\n jr nz,fdc_send_wait\n pop af\n ld bc,03ffdh\n out (c),a\n ret\n fdc_get: ld bc,02ffdh\n fdc_get_wait: in a,(c)\n and 0c0h\n cp 0c0h\n jr nz,fdc_get_wait\n ld bc,03ffdh\n in a,(c)\n ret\n fdc_results: call fdc_get\n call fdc_get\n and 07fh\n jp nz,fail\n call fdc_get\n and 0bfh\n jp nz,fail\n call fdc_get\n call fdc_get\n call fdc_get\n call fdc_get\n ret\n'
  asm=build/(label+'.asm');binary=build/(label+'.bin');asm.write_text((' org 0\n jp 0100h\n defs 066h-$,0\n push af\n ld a,(08106h)\n inc a\n ld (08106h),a\n pop af\n retn\n defs 0100h-$,0\n' if label=='ports-plus' else ' org 0\n')+s)
  subprocess.run(['pasmo','--bin',str(asm),str(binary)],check=True)
  data=bytearray([255]*romsize);code=binary.read_bytes()
  if name=='COBRA':
   offset=0x3000 if status==64 else 0x3800;data[offset:offset+len(code)]=code
  elif name=='TIMS' and status==64:
   if len(code)>2048:raise ValueError('Plus diagnostic exceeds native bootstrap EPROM')
   data[16384:16384+len(code)]=code
  else:data[:len(code)]=code
  path=build/(label+'.rom');path.write_bytes(data)
  physical=0x200 if name=='COBRA' else marker
  output.append((label,status,path,physical))
 return output
