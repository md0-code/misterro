.code16
.arch i8086
.intel_syntax noprefix
.section .text
.global _start
_start:
 cli
 xor ax,ax
 mov ds,ax
 mov ss,ax
 mov sp,0x7c00
 mov al,0x13
 out 0x20,al
 mov al,8
 out 0x21,al
 mov al,9
 out 0x21,al
 mov al,0xbe
 out 0x21,al
 mov al,0x36
 out 0x43,al
 xor al,al
 out 0x40,al
 out 0x40,al
 sti
 xor ax,ax
 xor dx,dx
 int 0x13
 mov al,0x40
 out 0xe9,al
 mov si,0
next:
 mov ax,0x500
 mov es,ax
 xor bx,bx
 mov ax,si
 xor dx,dx
 mov cx,8
 div cx
 mov cl,dl
 inc cl
 mov dh,al
 xor dl,dl
 xor ch,ch
 mov ax,0x201
 int 0x13
 pushf
 push ax
 mov ax,si
 out 0xe9,al
 pop ax
 mov al,ah
 out 0xe9,al
 popf
 jc failed
 inc si
 cmp si,16
 jb next
 mov al,0xff
 out 0xe9,al
 halt:hlt
 jmp halt
failed:
 mov al,0xfe
 out 0xe9,al
 jmp halt
