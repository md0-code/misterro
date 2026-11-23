"""Rebuild a labelled HC-88 system disk from the original bootstrap and CP/M sources."""
from pathlib import Path
import hashlib,json,re,subprocess
from project_paths import ROOT,DOCS
BUILD=ROOT/'build/hc88-software'
PAIR={'b':'bc','d':'de','h':'hl','sp':'sp','psw':'af'}
def reg(s):return '(hl)' if s.lower()=='m' else s

def convert_8080(source,origin):
 out=[f'origin equ {origin:05x}h']
 for line in source.splitlines():
  quoted=None;end=len(line)
  for i,ch in enumerate(line):
   if ch in (chr(34),chr(39)) and (quoted is None or ch==quoted):quoted=None if quoted else ch
   elif ch==';' and not quoted:end=i;break
  code=line[:end].strip()
  if not code:continue
  label=''
  found=re.match(r'^([A-Za-z_][A-Za-z0-9_]*):(.*)$',code)
  if found:label=found[1]+':';code=found[2].strip()
  elif not line[0].isspace():
   parts=code.split(None,1)
   if len(parts)>1 and parts[1].split()[0].lower() in ['equ','set']:label=parts[0];code=parts[1]
  if not code:out.append(label);continue
  parts=code.split(None,1);op=parts[0].lower();arg=parts[1].strip() if len(parts)>1 else ''
  if op in ['.cpu','title']:continue
  if op=='ifdef':op='if';arg='1' if arg=='origin' else '0'
  elif op=='ifndef':op='if';arg='0' if arg=='origin' else '1'
  elif op=='set':op='equ'
  elif op in ['mov','mvi']:
   dst,src=map(str.strip,arg.split(',',1));arg=reg(dst)+','+(('0+('+src+')') if op=='mvi' else reg(src));op='ld'
  elif op=='lxi':dst,src=map(str.strip,arg.split(',',1));op='ld';arg=PAIR[dst.lower()]+',0+('+src+')'
  elif op in ['inx','dcx']:op='inc' if op=='inx' else 'dec';arg=PAIR[arg.lower()]
  elif op in ['inr','dcr']:op='inc' if op=='inr' else 'dec';arg=reg(arg)
  elif op in ['push','pop']:arg=PAIR[arg.lower()]
  elif op in ['ldax','stax']:arg=('a,('+PAIR[arg.lower()]+')') if op=='ldax' else '('+PAIR[arg.lower()]+'),a';op='ld'
  elif op in ['lda','sta','lhld','shld']:
   arg=({'lda':'a,('+arg+')','sta':'('+arg+'),a','lhld':'hl,('+arg+')','shld':'('+arg+'),hl'})[op];op='ld'
  elif op=='dad':op='add';arg='hl,'+PAIR[arg.lower()]
  elif op in ['add','adc','sub','sbb','ana','xra','ora','cmp','adi','aci','sui','sbi','ani','xri','ori','cpi']:
   operation={'add':'add','adc':'adc','sub':'sub','sbb':'sbc','ana':'and','xra':'xor','ora':'or','cmp':'cp','adi':'add','aci':'adc','sui':'sub','sbi':'sbc','ani':'and','xri':'xor','ori':'or','cpi':'cp'}[op]
   arg=('0+('+arg+')') if op in ['adi','aci','sui','sbi','ani','xri','ori','cpi'] else reg(arg);arg=('a,'+arg) if operation in ['add','adc','sbc'] else arg;op=operation
  elif op in ['jmp','jz','jnz','jc','jnc','jp','jm','jpe','jpo']:
   cond={'jmp':'','jz':'z','jnz':'nz','jc':'c','jnc':'nc','jp':'p','jm':'m','jpe':'pe','jpo':'po'}[op];op='jp';arg=(cond+',' if cond else '')+arg
  elif op in ['cz','cnz','cc','cnc','cp','cm','cpe','cpo']:
   cond={'cz':'z','cnz':'nz','cc':'c','cnc':'nc','cp':'p','cm':'m','cpe':'pe','cpo':'po'}[op];op='call';arg=cond+','+arg
  elif op in ['rz','rnz','rc','rnc','rp','rm','rpe','rpo']:arg={'rz':'z','rnz':'nz','rc':'c','rnc':'nc','rp':'p','rm':'m','rpe':'pe','rpo':'po'}[op];op='ret'
  elif op in ['rlc','rrc','ral','rar','cma','stc','cmc','xchg','xthl','sphl','pchl','hlt']:
   op,arg={'rlc':('rlca',''),'rrc':('rrca',''),'ral':('rla',''),'rar':('rra',''),'cma':('cpl',''),'stc':('scf',''),'cmc':('ccf',''),'xchg':('ex','de,hl'),'xthl':('ex','(sp),hl'),'sphl':('ld','sp,hl'),'pchl':('jp','(hl)'),'hlt':('halt','')}[op]
  pieces=re.split(r"""("[^"]*"|'[^']*')""",arg)
  arg=''.join(part if i%2 else part.replace('~','NOT ').replace('&',' AND ').replace('|',' OR ') for i,part in enumerate(pieces))
  out.append(label+'\t'+op+'\t'+arg)
 return '\n'.join(out)+'\n'

def assemble(source,name):
 path=BUILD/(name+'.asm');path.write_text(source)
 output=BUILD/(name+'.bin')
 subprocess.run(['pasmo','--bin',str(path),str(output),str(BUILD/(name+'.sym'))],check=True,cwd=ROOT)
 return output.read_bytes()

def make_disk(files,boot,payload):
 # The original ROM uses odd/even skew only for its reserved system tracks.
 skew=[1,3,5,7,9,2,4,6,8]
 data=bytearray([0xe5])*(80*2*9*512)
 def put_slot(slot,block):
  cyl,rem=divmod(slot,18);head,index=divmod(rem,9)
  start=((cyl*2+head)*9+skew[index]-1)*512
  data[start:start+512]=block
 put_slot(0,boot)
 for n in range(24):put_slot(n+1,payload[n*512:(n+1)*512])
 directory=bytearray([0xe5])*4096;block=2;entry=0
 for name,content in files.items():
  stem,suffix=name.split('.');records=(len(content)+127)//128
  for extent,offset in enumerate(range(0,max(records,1),128)):
   count=min(128,records-offset);piece=content[offset*128:(offset+count)*128]
   allocation=[]
   for pos in range(0,len(piece),2048):
    allocation.append(block);start=4*9216+block*2048
    data[start:start+2048]=piece[pos:pos+2048].ljust(2048,b'\x1a');block+=1
   record=bytearray(32);record[1:9]=stem.upper().encode().ljust(8);record[9:12]=suffix.upper().encode().ljust(3)
   record[12]=extent&31;record[14]=extent>>5;record[15]=count
   for i,b in enumerate(allocation):record[16+i*2:18+i*2]=b.to_bytes(2,'little')
   directory[entry*32:(entry+1)*32]=record;entry+=1
 data[4*9216:4*9216+4096]=directory
 header=bytearray(256);header[:34]=b'EXTENDED CPC DSK File\r\nDisk-Info\r\n';header[34:48]=b'HC88 MiSTer   '
 header[48:50]=bytes([80,2]);header[52:212]=bytes([19])*160
 disk=bytearray(header)
 for c in range(80):
  for h in range(2):
   track=bytearray(256);track[:12]=b'Track-Info\r\n';track[16:24]=bytes([c,h,0,0,2,9,0x4e,0xe5])
   for r in range(9):track[24+r*8:32+r*8]=bytes([c,h,r+1,2,0,0,0,2])
   start=(c*18+h*9)*512;disk+=track+data[start:start+4608]
 return disk

def main():
 BUILD.mkdir(parents=True,exist_ok=True)
 ref=DOCS/'reference/hc88/cpm22';parts={}
 for name,origin,length in [('ccp',0xd000,2048),('bdos',0xd800,3584)]:
  binary=assemble(convert_8080((ref/(name+'.asm')).read_text(),origin),name)
  if len(binary)>length:raise ValueError(f'{name} exceeds original system slot: {len(binary)}')
  parts[name]=binary.ljust(length,b'\0');(BUILD/(name+'.bin')).write_bytes(parts[name]);print(name,len(binary))
 for name in ['bios','boot','basic','demo','write','track','drives']:
  parts[name]=assemble((ROOT/f'software/hc88_{name}.asm').read_text(),name)
 payload=bytearray(12288);payload[:2048]=parts['ccp'];payload[2048:5632]=parts['bdos']
 payload[0x1600:0x1600+len(parts['bios'])]=parts['bios']
 payload[0x2800:0x2b00]=(ROOT/'assets/roms/hc85.rom').read_bytes()[0x3d00:0x4000]
 (BUILD/'system.bin').write_bytes(payload)
 files={'DRIVES.COM':parts['drives'],'TRACK.COM':parts['track'],'WRITE.COM':parts['write'],'BASIC.COM':parts['basic'],'DEMO.COM':parts['demo'],
 'README.TXT':b'HC-88 replacement CP/M 2.2 system disk.\r\nOriginal 2K bootstrap ROM remains unmodified.\r\nBASIC starts bundled HC-family cassette BASIC.\r\nDEMO exercises native 512-pixel video and sound.\r\n',
 'HELLO.TXT':b'HC-88 native floppy read test OK.\r\n'}
 disk=make_disk(files,parts['boot'],payload)
 out=ROOT/'assets/disks/hc88/system.dsk';out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(disk)
 manifest={name:hashlib.sha256(value).hexdigest() for name,value in parts.items()}
 manifest['system.dsk']=hashlib.sha256(disk).hexdigest();(BUILD/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(out,len(disk),manifest['system.dsk'])
if __name__=='__main__':main()
