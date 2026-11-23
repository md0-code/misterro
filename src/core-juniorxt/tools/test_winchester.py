"""Winchester ROM: cold boot from a 20 MB fixed disk image, INT 13h parameters, write and read back."""
from project_paths import ROOT
from asm86 import assemble
import os,shutil,subprocess,sys
C,H,S=300,2,9
MBR="""
org 7C00h
 xor ax,ax
 mov ds,ax
 mov es,ax
 mov ss,ax
 mov sp,7C00h
 cld
 mov si,hello
 call print
 mov ah,8
 mov dl,80h
 int 13h
 jc fail
 push dx
 mov al,ch
 mov ah,cl
 and cl,63
 push cx
 mov cl,6
 shr ah,cl
 add ax,2
 call number
 pop cx
 pop dx
 mov al,dh
 xor ah,ah
 inc ax
 call number
 mov al,cl
 xor ah,ah
 call number
 mov di,8000h
 mov cx,512
fill:
 mov al,cl
 xor al,5Ah
 stosb
 loop fill
 mov ax,0301h
 mov bx,8000h
 mov cx,%d
 mov dx,%d
 int 13h
 jc fail
 mov ax,0201h
 mov bx,8200h
 mov cx,%d
 mov dx,%d
 int 13h
 jc fail
 mov si,8000h
 mov di,8200h
 mov cx,512
 repe cmpsb
 jne fail
 mov si,pass
 call print
stop:
 hlt
 jmp stop
fail:
 mov si,bad
 call print
 jmp stop
number:
 push cx
 push dx
 mov bx,10
 xor cx,cx
digit:
 xor dx,dx
 div bx
 push dx
 inc cx
 or ax,ax
 jnz digit
show:
 pop ax
 add al,'0'
 call putc
 loop show
 mov al,' '
 call putc
 pop dx
 pop cx
 ret
print:
 mov al,[si]
 inc si
 or al,al
 jz printed
 call putc
 jmp print
printed:
 ret
putc:
 push bx
 mov ah,0Eh
 mov bx,7
 int 10h
 pop bx
 ret
hello: db 'HD BOOT ', 0
pass: db 'HD PASS', 0
bad: db 'HD FAIL', 0
"""
def main():
 from sim import build
 build(3,'simhd');sim=ROOT/'build/simhd';work=ROOT/'build/winchester';work.mkdir(exist_ok=True)
 word=((C>>8)<<6|S)|((C&255)<<8);place=(H<<8)|0x80
 code=assemble(MBR%(word,place,word,place));assert len(code)<=446
 image=work/'hd.img'
 with image.open('wb') as f:f.write(code+bytes(510-len(code))+bytes([0x55,0xAA]));f.truncate(615*4*17*512)
 for f in ['mcl86_ucode.mem','cga.hex','hgc.hex','splash_320x200.hex']:shutil.copyfile(sim/f,work/f)
 log=ROOT/'build/winchester.log';env=dict(os.environ,JUNIOR_CFG='0x11',JUNIOR_RAM='1',JUNIOR_HD=str(image))  # 64 KiB: a short memory test
 with log.open('w') as f:r=subprocess.run([str(sim/'sim'),str(ROOT/'assets/boot.rom'),str(ROOT/'assets/demo.img'),'40','winchester'],cwd=work,env=env,stdout=f,stderr=subprocess.STDOUT)
 text=log.read_text(errors='replace')
 if r.returncode or 'RESULT: PASS Winchester ROM boot' not in text or 'HD BOOT 615 4 17' not in text:
  print('\n'.join(text.splitlines()[-30:]));raise RuntimeError('Winchester check failed')
 lba=(C*4+H)*17+S-1;sector=(work/'hd-modified.img').read_bytes()[lba*512:lba*512+512]
 if sector!=bytes(((512-i)&255)^0x5A for i in range(512)):raise ValueError('Written sector is not at its LBA in the image')
 print('PASS: Winchester ROM boots the fixed disk; 615 x 4 x 17 reported; sector written and read back at LBA',lba)
if __name__=='__main__':main()
