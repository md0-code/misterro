from project_paths import ROOT,DOCS
from common import run
import shutil,os,struct
b=ROOT/'build/software';b.mkdir(parents=True,exist_ok=True)
for name in ['demo','siotest']:
 run(['as','--32','-o',b/(name+'.o'),ROOT/'software'/(name+'.S')])
 run(['ld','-m','elf_i386','-Ttext','0x100','--oformat','binary','-o',b/(name.upper()+'.COM'),b/(name+'.o')])
ref=DOCS/'reference/freedos360.img'
for name in ['KERNEL.SYS','COMMAND.COM','FORMAT.EXE','CHKDSK.EXE']:
 target=b/name
 if target.exists():
  target.chmod(0o644);target.unlink()
 run(['mcopy','-o','-i',ref,'::'+name,b/name])
image=ROOT/'assets/demo.img'
if image.exists():image.unlink()
# V4's original ROM diskette table uses eight sectors, two heads, forty tracks.
run(['mformat','-C','-i',image,'-f','320','-N','0x4a585438','-v','JUNIORXT','::'])
raw=bytearray(image.read_bytes());boot=bytearray(ref.read_bytes()[:512]);boot[11:62]=raw[11:62];raw[:512]=boot;image.write_bytes(raw)
files=[(b/name,name) for name in ['KERNEL.SYS','COMMAND.COM','FORMAT.EXE','CHKDSK.EXE','DEMO.COM','SIOTEST.COM']]
files += [(ROOT/'software'/name,name) for name in ['CONFIG.SYS','AUTOEXEC.BAT']]
for src,name in files:
 # Fixed FAT times make the derived image reproducible.
 os.utime(src,(599616000,599616000))
 run(['mcopy','-m','-o','-i',image,src,'::'+name])
raw=bytearray(image.read_bytes());root=(struct.unpack_from('<H',raw,14)[0]+raw[16]*struct.unpack_from('<H',raw,22)[0])*512
for i in range(struct.unpack_from('<H',raw,17)[0]):
 off=root+i*32
 if not raw[off]:break
 raw[off+13:off+26]=bytes(13)
 raw[off+22:off+26]=bytes.fromhex('00002112')
image.write_bytes(raw)
assert len(raw)==327680 and struct.unpack_from('<H',raw,24)[0]==8
print('PASS: reproducible native 320K FreeDOS demo with 8086 CGA/speaker and SIO utilities')
