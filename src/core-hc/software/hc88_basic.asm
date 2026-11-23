; SPDX-License-Identifier: GPL-3.0-or-later
; Load the unmodified, bundled HC-family BASIC into HC-88 system RAM.
 org 0100h
 di
 ld hl,firmware
 ld de,8000h
 ld bc,4000h
 ldir
 ld hl,trampoline
 ld de,0c000h
 ld bc,trampoline_end-trampoline
 ldir
 jp 0c000h
trampoline:
 ld hl,8000h
 ld de,0000h
 ld bc,4000h
 ldir
 ld hl,8000h
 ld de,4000h
 ld bc,4000h
 ldir
 ld a,3
 out (9fh),a
 jp 0
trampoline_end:
firmware:
 incbin 'assets/roms/hc85.rom'
 end
