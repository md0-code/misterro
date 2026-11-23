; SPDX-License-Identifier: GPL-3.0-or-later
; First disk sector, loaded at 8000 by the unmodified HC-88 ROM.
 org 8000h
 di
 ld sp,9000h
 ld hl,0266h
 ld de,9500h
 ld bc,19
 ldir
 ld hl,0d000h
 ld (9505h),hl
 ld a,2
 ld (9502h),a
 xor a
 ld (9503h),a
 ld a,1
 ld (slot),a
next:
 ld a,(slot)
 ld c,0
cylinder:
 cp 18
 jr c,head
 sub 18
 inc c
 jr cylinder
head:
 cp 9
 jr c,sector
 add a,7
sector:
 ld (9504h),a
 ld a,c
 ld (9503h),a
 ld a,1
 ld (950bh),a
 ld bc,9500h
 call 015ch
 jr c,next
 ld hl,(9505h)
 ld de,512
 add hl,de
 ld (9505h),hl
 ld a,(slot)
 inc a
 ld (slot),a
 cp 25
 jr c,next
 ld a,31h
 out (9fh),a
 jp 0e600h
slot: db 1
 ds 512-($-8000h),0
 end
