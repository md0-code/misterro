; SPDX-License-Identifier: GPL-3.0-or-later
org 0
 di
 ld sp,0xbff0
 ld hl,payload
 ld de,0x8000
 ld bc,payload_end-payload
 ldir
 jp 0x8000
payload:
; All eight physical RAM pages must retain distinct values. ld bc,0x7ffd
 ld e,0
bank_write:
 ld a,e
 out (c),a
 add a,0x40
 ld (0xc000),a
 inc e
 ld a,e
 cp 8
 jr nz,bank_write
 xor a
 out (c),a
 ld a,0x6e
 ld (0xc000),a
 ld e,0
 ld hl,0x9000
bank_read:
 ld a,e
 out (c),a
 ld a,(0xc000)
 ld (hl),a
 inc hl
 inc e
 ld a,e
 cp 8
 jr nz,bank_read
; Select screen 7 and ROM 1, then lock further paging.
 ld a,0x3f
 out (c),a
 xor a
 out (c),a
 ld a,(0xc000)
 ld (0x9008),a
; AY tone period 16, channel A tone enabled, maximum volume.
 ld bc,0xfffd
 xor a
 out (c),a
 ld b,0xbf
 ld a,16
 out (c),a
 ld b,0xff
 ld a,1
 out (c),a
 ld b,0xbf
 xor a
 out (c),a
 ld b,0xff
 ld a,7
 out (c),a
 ld b,0xbf
 ld a,0x3e
 out (c),a
 ld bc,0xfffd
 ld a,8
 out (c),a
 ld b,0xbf
 ld a,15
 out (c),a
 ld b,0xff
 in a,(c)
 ld (0x9009),a
 ld a,0x5a
 ld (0x90ff),a
 halt
payload_end:
