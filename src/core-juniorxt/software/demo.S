.code16
.arch i8086
.intel_syntax noprefix
.section .text
.global _start
_start:
 cld
 push cs
 pop ds
 mov ax,3
 int 0x10
menu:
 mov dx,offset title
 mov ah,9
 int 0x21
 xor ah,ah
 int 0x16
 cmp al,27
 je quit
 cmp al,'1'
 je mode40
 cmp al,'2'
 je mode80
 cmp al,'3'
 je color
 cmp al,'4'
 je mono
 or al,0x20
 cmp al,'s'
 je speaker
 jmp menu
mode40:
 mov ax,1
 int 0x10
 mov dx,offset text40
 jmp text
mode80:
 mov ax,3
 int 0x10
 mov dx,offset text80
text:
 mov ah,9
 int 0x21
 xor ah,ah
 int 0x16
 mov ax,3
 int 0x10
 jmp menu
color:
 mov ax,4
 int 0x10
 mov ax,0xb800
 mov es,ax
 xor di,di
 mov cx,8192
color_fill:
 mov ax,di
 xor ah,al
 stosw
 loop color_fill
 jmp wait_graphics
mono:
 mov ax,6
 int 0x10
 mov ax,0xb800
 mov es,ax
 xor di,di
 mov ax,0x55aa
 mov cx,8192
 rep stosw
wait_graphics:
 xor ah,ah
 int 0x16
 mov ax,3
 int 0x10
 jmp menu
speaker:
 mov al,0xb6
 out 0x43,al
 mov ax,1193
 out 0x42,al
 mov al,ah
 out 0x42,al
 in al,0x61
 mov bl,al
 or al,3
 out 0x61,al
 mov ah,0
 int 0x1a
 mov si,dx
beep_wait:
 mov ah,0
 int 0x1a
 sub dx,si
 cmp dx,5
 jb beep_wait
 mov al,bl
 out 0x61,al
 jmp menu
quit:
 mov ax,3
 int 0x10
 mov ax,0x4c00
 int 0x21
title:
 .ascii "\r\nFEPER JUNIOR-XT\r\n"
 .ascii "1  40-column text\r\n2  80-column text\r\n"
 .ascii "3  320x200 CGA colour\r\n4  640x200 monochrome\r\n"
 .ascii "S  PC speaker\r\nEsc  Return to DOS\r\n$"
text40:
 .ascii "JUNIOR-XT 40-column text\r\n"
 .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZ\r\nabcdefghijklmnopqrstuvwxyz\r\n0123456789 !@#%&*()+-=\r\n"
 .ascii "Press any key...$"
text80:
 .ascii "JUNIOR-XT 80-column text, original 1989 character generator\r\n"
 .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789\r\n"
 .ascii "Press any key...$"
