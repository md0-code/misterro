; SPDX-License-Identifier: GPL-3.0-or-later
 org 100h
 ld c,0
 call 0e61bh
 ld a,h
 or l
 ld de,a_ready
 jr nz,report_a
 ld de,a_empty
report_a:
 ld c,9
 call 5
 ld c,1
 call 0e61bh
 ld a,h
 or l
 ld de,b_ready
 jr nz,report_b
 ld de,b_empty
report_b:
 ld c,9
 call 5
 ld c,0
 call 0e61bh
 jp 0
a_ready: db 'A: ready',13,10,'$'
a_empty: db 'A: not ready',13,10,'$'
b_ready: db 'B: ready',13,10,'$'
b_empty: db 'B: not ready',13,10,'$'
 end
