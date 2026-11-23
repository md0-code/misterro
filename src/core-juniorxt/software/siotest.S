.code16
.arch i8086
.intel_syntax noprefix
.section .text
.global _start
_start:
 push cs
 pop ds
 xor dx,dx
 mov ax,0x00e3
 int 0x14
 mov ax,0x0155
 int 0x14
 test ah,0x80
 jnz fail
 mov ah,2
 int 0x14
 test ah,0x80
 jnz fail
 cmp al,0x55
 jne fail
 mov dx,offset passed
 jmp print
fail:
 mov dx,offset failed
print:
 mov ah,9
 int 0x21
 mov ax,0x4c00
 int 0x21
passed:.ascii "SIO BIOS PASS\r\n$"
failed:.ascii "SIO BIOS FAIL - connect a serial loopback to channel A\r\n$"
