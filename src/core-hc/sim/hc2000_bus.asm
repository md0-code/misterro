; SPDX-License-Identifier: GPL-3.0-or-later
org 0
 di
 ld sp,0xbff0
 jp start
org 0x100
start:
 ld hl,payload
 ld de,0x8000
 ld bc,payload_end-payload
 ldir
 jp 0x8000
payload:
 ld a,1
 out (0x7e),a
 ld a,(0)
 ld (0x9000),a
 ld a,0x11
 ld (0xc000),a
 ld a,0x22
 ld (0xe000),a
 ld a,3
 out (0x7e),a
 ld a,0x66
 ld (0),a
 ld a,(0)
 ld (0x9001),a
 ld a,(0xe000)
 ld (0x9002),a
 xor a
 out (0xc7),a
 ld a,(0xc000)
 ld (0x9003),a
 out (0xc5),a
 ld a,(0xc000)
 ld (0x9004),a
 ld a,7
 out (0x7e),a
 xor a
 out (0x7e),a
 in a,(0x7e)
 ld (0x9005),a
 ld a,0x5a
 ld (0x90ff),a
 halt
payload_end:
