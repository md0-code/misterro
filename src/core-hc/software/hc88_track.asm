; SPDX-License-Identifier: GPL-3.0-or-later
; A long physical seek must finish in normal spindle/step timing.
 org 100h
 ld bc,79
 call 0e61eh
 ld bc,0
 call 0e621h
 ld bc,800h
 call 0e624h
 call 0e627h
 or a
 jr nz,error
 ld a,(800h)
 cp 0e5h
 jr nz,error
 ld de,ok
 jr report
error:
 ld de,fail
report:
 ld c,9
 call 5
 jp 0
ok: db 'PASS: native cylinder 79 seek/read',13,10,'$'
fail: db 'FAIL: native far-cylinder seek/read',13,10,'$'
 end
