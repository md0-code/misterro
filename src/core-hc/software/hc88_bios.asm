; SPDX-License-Identifier: GPL-3.0-or-later
; Replacement HC-88 CP/M 2.2 BIOS. Original 2K bootstrap is unmodified.
; The display is a software-rendered 80x24 terminal in native 512-pixel mode.
 org 0e600h
 jp cold
 jp warm
 jp const
 jp conin
 jp conout
 jp listout
 jp punch
 jp reader
 jp home
 jp seldsk
 jp settrk
 jp setsec
 jp setdma
 jp read
 jp write
 jp listst
 jp sectran
cold:
 di
 ld sp,0fff0h
 ld a,31h
 out (9fh),a
 xor a
 ld (0003h),a
 ld (0004h),a
 ld (drive),a
 ld (held),a
 ld (pending),a
 ld a,0ffh
 ld (position),a
 ld (position+1),a
 ld (cache_c),a
 call fdcinit
 call cls
 ld hl,banner
 call puts
 jp enterccp
warm:
 di
 ld sp,0fff0h
 ld a,31h
 out (9fh),a
 xor a
 ld (drive),a
 ld (boot_index),a
 ld hl,0d000h
 ld (boot_target),hl
warm_loop:
 ld a,(boot_index)
 inc a
 call boot_location
 call raw_read
 or a
 jp nz,boot_error
 ld hl,0fb00h
 ld de,(boot_target)
 ld bc,512
 ldir
 ld (boot_target),de
 ld a,(boot_index)
 inc a
 ld (boot_index),a
 cp 11
 jr c,warm_loop
enterccp:
 ld a,0c3h
 ld (0),a
 ld hl,0e603h
 ld (1),hl
 ld (5),a
 ld hl,0d806h
 ld (6),hl
 ld hl,0080h
 ld (dma),hl
 xor a
 ld (track),a
 ld (track+1),a
 ld (sector),a
 ld (sector+1),a
 ld (drive),a
 ld a,0ffh
 ld (cache_c),a
 ld a,(0004h)
 ld c,a
 jp 0d003h
boot_error:
 ld hl,diskerror
 call puts
 jp warm
; Physical location of boot payload slot A, including the ROM's odd/even skew.
boot_location:
 ld c,0
bl_cyl:
 cp 18
 jr c,bl_head
 sub 18
 inc c
 jr bl_cyl
bl_head:
 ld (physical_c),a ; replaced below with cylinder C
 ld b,a
 ld a,c
 ld (physical_c),a
 ld a,b
 ld c,0
 cp 9
 jr c,bl_sector
 sub 9
 inc c
bl_sector:
 ld b,0
 ld hl,skew
 ld e,a
 ld d,0
 add hl,de
 ld a,(hl)
 ld (physical_r),a
 ld a,c
 ld (physical_h),a
 ret
skew: db 1,3,5,7,9,2,4,6,8
; All standard CP/M BIOS entry points.
listout: ret
punch: ret
reader: ld a,1ah
 ret
listst: xor a
 ret
home: ld bc,0
settrk: ld (track),bc
 ret
setsec: ld (sector),bc
 ret
setdma: ld (dma),bc
 ret
seldsk:
 ld hl,0
 ld a,c
 cp 2
 ret nc
 ld a,(drive)
 push af
 ld a,c
 ld (drive),a
 call drive_latch
 out (0e7h),a
 ld a,4
 call send
 ld a,(drive)
 call send
 call receive
 jr c,select_fail
 and 20h
 jr z,select_fail
 pop af
 ld a,0ffh
 ld (cache_c),a
 ld hl,dph0
 ld a,(drive)
 or a
 ret z
 ld hl,dph1
 ret
select_fail:
 pop af
 ld (drive),a
 ld hl,0
 ret
sectran: ld h,b
 ld l,c
 ret
read:
 call fetch_sector
 or a
 ret nz
 call cache_pointer
 ld de,(dma)
 ld bc,128
 ldir
 xor a
 ret
write:
 call fetch_sector
 or a
 ret nz
 call cache_pointer
 ex de,hl
 ld hl,(dma)
 ld bc,128
 ldir
 call raw_write
 ret
cache_pointer:
 ld a,(sector)
 and 3
 ld l,a
 ld h,0
 add hl,hl
 add hl,hl
 add hl,hl
 add hl,hl
 add hl,hl
 add hl,hl
 add hl,hl
 ld de,0fb00h
 add hl,de
 ret
fetch_sector:
 ld a,(track)
 ld (physical_c),a
 ld a,(sector)
 srl a
 srl a
 ld c,0
 cp 9
 jr c,fs_head
 sub 9
 inc c
fs_head:
 inc a
 ld (physical_r),a
 ld a,c
 ld (physical_h),a
 ld a,(cache_c)
 ld hl,physical_c
 cp (hl)
 jr nz,fs_load
 ld a,(cache_h)
 inc hl
 cp (hl)
 jr nz,fs_load
 ld a,(cache_r)
 inc hl
 cp (hl)
 jr nz,fs_load
 ld a,(cache_d)
 ld hl,drive
 cp (hl)
 jr nz,fs_load
 xor a
 ret
fs_load:
 call raw_read
 or a
 ret nz
 ld hl,physical_c
 ld de,cache_c
 ld bc,3
 ldir
 ld a,(drive)
 ld (cache_d),a
 xor a
 ret
fdcinit:
 xor a
 out (0e7h),a
 call drive_latch
 out (0e7h),a
 ld a,3
 call send
 ld a,0efh
 call send
 ld a,1
 call send
 ret
drive_latch:
 ld a,(drive)
 or a
 ld a,1ah
 ret z
 ld a,1ch
 ret
send:
 push af
 push bc
 ld bc,0
send_wait:
 in a,(0ddh)
 and 0c0h
 cp 80h
 jr z,send_ready
 dec bc
 ld a,b
 or c
 jr nz,send_wait
 pop bc
 pop af
 scf
 ret
send_ready:
 pop bc
 pop af
 out (0dfh),a
 or a
 ret
receive:
 push bc
 ld bc,0
receive_wait:
 in a,(0ddh)
 and 0c0h
 cp 0c0h
 jr z,receive_ready
 dec bc
 ld a,b
 or c
 jr nz,receive_wait
 pop bc
 scf
 ret
receive_ready:
 in a,(0dfh)
 pop bc
 or a
 ret
seek:
 ld a,(drive)
 ld e,a
 ld d,0
 ld hl,position
 add hl,de
 ld a,(hl)
 cp 0ffh
 jr nz,seek_known
 ; Recalibrate unknown drives: resetting the 8272 does not move a real head.
 push hl
 ld a,7
 call send
 ld a,(drive)
 call send
 call seek_wait
 pop hl
 or a
 ret nz
 ld (hl),0
seek_known:
 ld a,(physical_c)
 cp (hl)
 jr nz,seek_move
 xor a
 ret
seek_move:
 push hl
 ld a,0fh
 call send
 ld a,(physical_h)
 add a,a
 add a,a
 ld c,a
 ld a,(drive)
 or c
 call send
 ld a,(physical_c)
 call send
 call seek_wait
 pop hl
 or a
 ret nz
 ld a,(physical_c)
 ld (hl),a
 xor a
 ret
seek_wait:
 ld bc,8192
seek_poll:
 push bc
 ld a,8
 call send
 call receive
 jr c,seek_error_pop
 ld (result),a
 cp 80h
 jr z,seek_next
 ; Every interrupt result except the single-byte 80h needs its PCN consumed.
 call receive
 jr c,seek_error_pop
 ld (result+1),a
 ld a,(result)
 and 0c0h
 jr nz,seek_error_pop
 ld a,(result)
 and 20h
 jr nz,seek_ok
seek_next:
 pop bc
 dec bc
 ld a,b
 or c
 jr nz,seek_poll
seek_error:
 ld a,1
 or a
 ret
seek_error_pop:
 pop bc
 jr seek_error
seek_ok:
 pop bc
 xor a
 ret
raw_read:
 ld a,46h
 jr raw_command
raw_write:
 ld a,45h
raw_command:
 ld (operation),a
 call drive_latch
 out (0e7h),a
 call seek
 or a
 ret nz
 ld a,(operation)
 call send
 ld a,(physical_h)
 add a,a
 add a,a
 ld c,a
 ld a,(drive)
 or c
 call send
 ld a,(physical_c)
 call send
 ld a,(physical_h)
 call send
 ld a,(physical_r)
 call send
 ld a,2
 call send
 ld a,9
 call send
 ld a,1bh
 call send
 ld a,0ffh
 call send
 ld hl,0fb00h
 ld de,512
 ld a,(operation)
 cp 46h
 jr nz,write_loop
read_loop:
 call receive
 jr c,io_error
 ld (hl),a
 inc hl
 dec de
 ld a,d
 or e
 jr nz,read_loop
 jr transfer_end
write_loop:
 ld a,(hl)
 call send
 jr c,io_error
 inc hl
 dec de
 ld a,d
 or e
 jr nz,write_loop
transfer_end:
 call drive_latch
 or 1
 out (0e7h),a
 and 0feh
 out (0e7h),a
 ld hl,result
 ld b,7
results:
 call receive
 jr c,io_error
 ld (hl),a
 inc hl
 djnz results
 ld a,(result)
 and 0c0h
 ret z
io_error:
 ld a,0ffh
 ld (cache_c),a
 ld a,1
 or a
 ret
; Matrix keyboard through the native FE port. No host ASCII injection.
const:
 push bc
 push de
 push hl
 ld a,(pending)
 or a
 jr nz,const_yes
 call scan_key
 ld c,a
 or a
 jr nz,const_key
 ld (held),a
 jr const_no
const_key:
 ld a,(held)
 cp c
 jr z,const_no
 ld a,c
 ld (held),a
 ld (pending),a
const_yes:
 ld a,0ffh
 jr const_exit
const_no:
 xor a
const_exit:
 pop hl
 pop de
 pop bc
 ret
conin:
 call const
 or a
 jr z,conin
 ld a,(pending)
 push af
 xor a
 ld (pending),a
 pop af
 ret
scan_key:
 ld bc,0fefeh
 in a,(c)
 and 1
 ld (caps),a
 ld bc,7ffeh
 in a,(c)
 bit 1,a
 ld a,0
 jr nz,sk_sym
 inc a
sk_sym:
 ld (symbol),a
 ld bc,0fefeh
 ld hl,keymap
 ld a,(symbol)
 or a
 jr z,sk_row
 ld hl,symmap
sk_row:
 in a,(c)
 cpl
 and 1fh
 ld d,a
 ld e,5
sk_bit:
 bit 0,d
 jr z,sk_next
 ld a,(hl)
 or a
 jr z,sk_next
 ld e,a
 ld a,(caps)
 or a
 ld a,e
 ret nz
 cp '0'
 jr nz,sk_break
 ld a,8
 ret
sk_break:
 cp ' '
 jr nz,sk_plain
 ld a,3
 ret
sk_plain:
 ld a,e
 ret
sk_next:
 inc hl
 srl d
 dec e
 jr nz,sk_bit
 rlc b
 jr c,sk_row
 xor a
 ret
keymap: db 0,'Z','X','C','V','A','S','D','F','G','Q','W','E','R','T'
 db '1','2','3','4','5','0','9','8','7','6','P','O','I','U','Y'
 db 13,'L','K','J','H',' ',0,'M','N','B'
symmap: db 0,':',0,3,'/','~','|',92,'{','}', '<','>','[',']','^'
 db '!','@','#','$','%','_',')','(',39,'&',34,';','?',']','['
 db 13,'=','+','-','^',' ',0,'.',',','*'
; Native software bitmap terminal. Character buffer is separate from VRAM.
conout:
 push af
 push bc
 push de
 push hl
 ld a,c
 cp 13
 jr nz,co_lf
 xor a
 ld (column),a
 jr co_done
co_lf:
 cp 10
 jr nz,co_bs
 call newline
 jr co_done
co_bs:
 cp 8
 jr nz,co_ff
 ld a,(column)
 or a
 jr z,co_done
 dec a
 ld (column),a
 ld a,' '
 call draw
 jr co_done
co_ff:
 cp 12
 jr nz,co_print
 call cls
 jr co_done
co_print:
 cp 32
 jr c,co_done
 cp 128
 jr nc,co_done
 call draw
 ld a,(column)
 inc a
 cp 80
 jr c,co_column
 xor a
 ld (column),a
 call newline
 jr co_done
co_column:
 ld (column),a
co_done:
 pop hl
 pop de
 pop bc
 pop af
 ret
puts:
 ld a,(hl)
 or a
 ret z
 ld c,a
 push hl
 call conout
 pop hl
 inc hl
 jr puts
cls:
 ld a,11h
 out (9fh),a
 ld hl,4000h
 ld de,4001h
 ld bc,3fffh
 ld (hl),0
 ldir
 ld hl,5800h
 ld de,5801h
 ld bc,02ffh
 ld (hl),7
 ldir
 ld hl,7800h
 ld de,7801h
 ld bc,02ffh
 ld (hl),7
 ldir
 ld a,31h
 out (9fh),a
 ld hl,0f000h
 ld de,0f001h
 ld bc,1919
 ld (hl),' '
 ldir
 xor a
 ld (column),a
 ld (row),a
 ret
line_address:
 ld l,a
 and 7
 or 40h
 ld h,a
 ld a,l
 and 0c0h
 rrca
 rrca
 rrca
 or h
 ld h,a
 ld a,l
 and 38h
 rlca
 rlca
 ld l,a
 ret
draw:
 ld (character),a
 ; record printable character in the 80x24 software terminal buffer
 ld a,(row)
 ld h,0
 ld l,a
 add hl,hl
 add hl,hl
 add hl,hl
 add hl,hl
 ld e,l
 ld d,h
 add hl,hl
 add hl,hl
 add hl,de
 ld a,(column)
 ld e,a
 ld d,0
 add hl,de
 ld de,0f000h
 add hl,de
 ld a,(character)
 ld (hl),a
 sub 32
 ld h,0
 ld l,a
 add hl,hl
 add hl,hl
 add hl,hl
 ld de,0f800h
 add hl,de
 ld (glyph),hl
 ld a,(column)
 ld h,0
 ld l,a
 add hl,hl
 ld e,l
 ld d,h
 add hl,hl
 add hl,de
 ld a,l
 and 7
 ld b,a
 ld a,80h
 jr z,draw_mask_done
mask_loop:
 rrca
 djnz mask_loop
draw_mask_done:
 ld (mask),a
 srl h
 rr l
 srl h
 rr l
 srl h
 rr l
 ld a,l
 ld (byte_column),a
 ld a,(row)
 add a,a
 add a,a
 add a,a
 ld (draw_y),a
 ld a,8
 ld (draw_lines),a
 ld a,11h
 out (9fh),a
draw_line:
 ld a,(draw_y)
 call line_address
 ld a,(byte_column)
 srl a
 or l
 ld l,a
 ld a,(byte_column)
 bit 0,a
 jr z,draw_bank
 set 5,h
draw_bank:
 ld de,(glyph)
 ld a,(de)
 inc de
 ld (glyph),de
 add a,a
 ld e,a
 ld a,(mask)
 ld d,a
 ld b,6
draw_dot:
 ld a,d
 bit 7,e
 jr nz,dot_set
 cpl
 and (hl)
 jr dot_store
dot_set:
 or (hl)
dot_store:
 ld (hl),a
 sla e
 rrc d
 jr nc,dot_same_byte
 bit 5,h
 jr nz,dot_bank1
 set 5,h
 jr dot_same_byte
dot_bank1:
 res 5,h
 inc l
dot_same_byte:
 djnz draw_dot
 ld a,(draw_y)
 inc a
 ld (draw_y),a
 ld a,(draw_lines)
 dec a
 ld (draw_lines),a
 jr nz,draw_line
 ld a,31h
 out (9fh),a
 ret
newline:
 ld a,(row)
 inc a
 cp 24
 jr c,nl_store
 call scroll
 ld a,23
nl_store:
 ld (row),a
 ret
scroll:
 ld hl,0f050h
 ld de,0f000h
 ld bc,1840
 ldir
 ld hl,0f730h
 ld de,0f731h
 ld bc,79
 ld (hl),' '
 ldir
 ld a,11h
 out (9fh),a
 xor a
 ld (draw_y),a
scroll_line:
 ld a,(draw_y)
 call line_address
 ex de,hl
 ld a,(draw_y)
 add a,8
 call line_address
 push de
 push hl
 ld bc,32
 ldir
 pop hl
 pop de
 set 5,h
 set 5,d
 ld bc,32
 ldir
 ld a,(draw_y)
 inc a
 ld (draw_y),a
 cp 184
 jr c,scroll_line
scroll_clear:
 ld a,(draw_y)
 call line_address
 push hl
 ld b,32
 xor a
clear0:
 ld (hl),a
 inc hl
 djnz clear0
 pop hl
 set 5,h
 ld b,32
clear1:
 ld (hl),a
 inc hl
 djnz clear1
 ld a,(draw_y)
 inc a
 ld (draw_y),a
 cp 192
 jr c,scroll_clear
 ld a,31h
 out (9fh),a
 ret
banner: db 'HC-88 / CP/M 2.2',13,10,'Replacement system disk - original 2K bootstrap',13,10
 db 'DEMO tests video, sound and disk; BASIC starts cassette BASIC.',13,10,0
diskerror: db 13,10,'Disk boot error - insert the HC-88 system disk.',13,10,0
; One 720K disk is 80 cylinders, two heads, nine 512-byte sectors per head.
dph0: dw 0,0,0,0,0fd00h,dpb,csv0,alv0
dph1: dw 0,0,0,0,0fd00h,dpb,csv1,alv1
dpb: dw 72
 db 4,15,0
 dw 341,127
 db 0c0h,0
 dw 32,4
track: dw 0
sector: dw 0
dma: dw 80h
drive: db 0
physical_c: db 0
physical_h: db 0
physical_r: db 1
cache_c: db 0ffh
cache_h: db 0
cache_r: db 0
cache_d: db 0
position: db 0ffh,0ffh
operation: db 0
result: ds 7
column: db 0
row: db 0
character: db 0
glyph: dw 0
draw_y: db 0
draw_lines: db 0
byte_column: db 0
mask: db 0
held: db 0
pending: db 0
symbol: db 0
caps: db 1
boot_index: db 0
boot_target: dw 0
bios_end:
 if bios_end > 0f000h
 .error 'BIOS overlaps the console buffer'
 endif
 org 0fd80h
csv0: ds 32
csv1: ds 32
alv0: ds 43
alv1: ds 43
 end
