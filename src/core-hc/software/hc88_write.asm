; SPDX-License-Identifier: GPL-3.0-or-later
; Exercise BDOS create, write, close, reopen and read through native floppy I/O.
 org 100h
 ld de,fcb
 ld c,19
 call 5
 ld de,fcb
 ld c,22
 call 5
 inc a
 jp z,error
 ld de,record
 ld c,26
 call 5
 ld de,fcb
 ld c,21
 call 5
 or a
 jp nz,error
 ld de,fcb
 ld c,16
 call 5
 inc a
 jp z,error
 xor a
 ld (fcb+32),a
 ld de,fcb
 ld c,15
 call 5
 inc a
 jp z,error
 ld de,buffer
 ld c,26
 call 5
 ld de,fcb
 ld c,20
 call 5
 or a
 jp nz,error
 ld hl,record
 ld de,buffer
 ld b,128
compare:
 ld a,(de)
 cp (hl)
 jp nz,error
 inc hl
 inc de
 djnz compare
 ld de,ok
 ld c,9
 call 5
 jp 0
error:
 ld de,fail
 ld c,9
 call 5
 jp 0
ok: db 'PASS: native BDOS create/write/close/read/compare',13,10,'$'
fail: db 'FAIL: native BDOS file persistence',13,10,'$'
fcb: db 0,'CHECK   TXT'
 ds 24,0
record: db 'HC-88 persistent floppy write verified.',13,10
 ds 128-($-record),1ah
buffer: ds 128
 end
