; SPDX-License-Identifier: GPL-3.0-or-later
; Replacement TIM-S Plus bootstrap; original EPROM has not been archived.
; The host restores the unmodified 64K OS into resident RAM P8..P11 on reset.
; All switching uses the original documented I/O ports and a RAM trampoline.
 org 0
 di
 ld sp,08000h
 ld bc,00dfdh
 ld a,082h
 out (c),a
 ld bc,00cfdh
 ld a,012h
 out (c),a
 ld bc,00efdh
 ld a,002h
 out (c),a
 ld bc,05ffdh
 ld a,08ah
 out (c),a
 ld bc,05efdh
 ld a,00ch
 out (c),a
 ; Initialize the native serial clock and 50 Hz-derived FLASH divider.
 ld bc,09ffdh
 ld a,036h
 out (c),a
 ld bc,09cfdh
 ld a,13
 out (c),a
 xor a
 out (c),a
 ld bc,09ffdh
 ld a,076h
 out (c),a
 ld bc,09dfdh
 ld a,0b8h
 out (c),a
 ld a,088h
 out (c),a
 ld bc,0dffdh
 ld a,04eh
 out (c),a
 ld a,037h
 out (c),a
 ld bc,07ffdh
 xor a
 out (c),a
 ld bc,01ffdh
 out (c),a
 ld hl,trampoline
 ld de,0c000h
 ld bc,8
 ldir
 ld bc,00cfdh
 ld a,011h
 jp 0c000h
trampoline:
 out (c),a
 jp 0
 defs 2048-$,0ffh
