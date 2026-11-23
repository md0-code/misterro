; SPDX-License-Identifier: GPL-3.0-or-later
 org 100h
 ld de,message
 ld c,9
 call 5
 ld a,11h
 out (9fh),a
 ld hl,4000h
 ld de,4001h
 ld bc,17ffh
 ld (hl),55h
 ldir
 ld hl,6000h
 ld de,6001h
 ld bc,17ffh
 ld (hl),0aah
 ldir
 ld hl,5800h
 ld de,7800h
 ld bc,768
attr:
 ld a,l
 and 7
 or 40h
 ld (hl),a
 xor 80h
 ld (de),a
 inc hl
 inc de
 dec bc
 ld a,b
 or c
 jr nz,attr
 ld de,1000
sound:
 ld a,e
 and 10h
 or 1
 out (0feh),a
 ld b,70
wait: djnz wait
 dec de
 ld a,d
 or e
 jr nz,sound
 ld a,31h
 out (9fh),a
 ld de,done
 ld c,9
 call 5
 ld c,1
 call 5
 ld a,12
 ld e,a
 ld c,2
 call 5
 jp 0
message: db 'Native HC-88 512-pixel video / BRIGHT / FLASH / speaker demo',13,10,'$'
done: db 13,10,'Press a key to return to CP/M.',13,10,'$'
 end
