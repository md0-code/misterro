; JUNIOR-XT for MiSTer - the Winchester ROM, 8 KiB in the option ROM socket at C8000h.
;
; The project's own code, written for tools/asm86.py (tools/build_hdrom.py assembles it, pads it to
; 8 KiB and sets the checksum byte). It is MezinXT's Winchester coupler ROM (the same INT 13h service,
; parameter tables, messages and boot order) with another back end: the fixed disks are MiSTer's ATA
; drives behind the 8-bit bridge at 300h-30Fh, moved by programmed I/O. No code of IBM's, Xebec's or
; anyone else's ROM is in it.
;
; The POST (the BIOS scans C8000h for 55h AAh) calls the entry at offset 3:
;   - each drive is asked for its size (IDENTIFY; drive 0 first, a missing drive 0 ends the count) and
;     given MezinXT's geometry for an image of that size: 17 sectors a track, the heads its partition
;     table ends on, else the first of 4..16, 2, 3, 1 heads that divides its tracks into 2..1024
;     cylinders (615 x 4 for 20 MB, 733 x 5, 977 x 5, 977 x 7, 1024 x 8, 306 x 4);
;   - the fixed disk parameter tables (16 bytes, the PC/AT layout) are those of this ROM for the period
;     geometries, else built in 1 KiB taken from the top of memory; INT 41h points at drive 0's, INT 46h
;     at drive 1's;
;   - INT 13h moves to INT 40h (the Junior BIOS's diskette service, called from here for drives
;     00h-7Fh) and INT 13h becomes this ROM's; INT 19h boots from the diskette in A: first, then from
;     the fixed disk;
;   - 40:74h is the last status, 40:75h the number of fixed disks;
;   - a line for each drive is printed.
;
; INT 13h for DL = 80h, 81h: 00h reset, 01h status (AL), 02h read, 03h write, 04h verify, 08h
; parameters, 0Ch seek, 10h test ready, 15h disk type; 05h-07h (format), 09h, 0Dh, 11h-14h succeed
; without touching the disk (an image needs no low-level format); 0Ah, 0Bh, 0Eh, 0Fh (long and buffer
; transfers) are invalid commands. Sectors are addressed by LBA = (cylinder x heads + head) x 17 +
; sector - 1, so an image is the same disk here and in MezinXT.

org 0

DATA equ 300h                   ; data, low byte (a read latches the high byte)
DATAH equ 308h                  ; data, high byte (written first)
ERROR equ 301h
COUNT equ 302h
SECTOR equ 303h
CYLL equ 304h
CYLH equ 305h
DRVH equ 306h
STAT equ 307h                   ; status, command
CONTROL equ 30Eh                ; device control: bit 2 resets

; the frame of the INT 13h service and of the start-up code: BP, then
F_DX equ 2                      ; the caller's DX (DL at +2, DH at +3)
F_CX equ 4                      ; CX (CL +4, CH +5)
F_BX equ 6
F_ES equ 12
L_FUNC equ 8                    ; AH of the call
L_COUNT equ 9                   ; AL of the call (returned as AL)
L_UNIT equ 10
L_LEFT equ 11                   ; sectors left in a transfer
L_TRACKS equ 14                 ; the drive's tracks (start-up, word)
L_LBA equ 18                    ; [bp-18] .. [bp-15]: the first sector
L_BUF equ 24                    ; cylinders high and low, heads, sectors
L_TABLE equ 28                  ; the drive's table: offset [bp-28], segment [bp-26]
L_FOUND equ 30                  ; drives found (start-up)
L_RAM equ 32                    ; the segment of the RAM tables, 0 for none (start-up)
LOCALS equ 32

SCRATCH equ 7C00h               ; 0:7C00h, free until the boot: IDENTIFY data and the partition table

start:
 db 55h, 0AAh, 16               ; 16 blocks of 512 bytes
 jmp init

 db 'JUNIOR-XT Winchester ROM 1.0', 0

; --- start-up -------------------------------------------------------------------------------

init:
 pushf
 push ax
 push bx
 push cx
 push dx
 push si
 push di
 push ds
 push es
 push bp
 mov bp,sp
 sub sp,LOCALS
 cld
 mov word [bp-L_RAM],0
 mov byte [bp-L_FOUND],0
 mov byte [bp-L_FUNC],0
 mov si,banner
 call print
 xor ax,ax
 mov ds,ax
 mov byte [bp-L_UNIT],0
init_unit:
 call probe
 jc init_units_done
 call place_table
 inc byte [bp-L_FOUND]
 call show_drive
 inc byte [bp-L_UNIT]
 cmp byte [bp-L_UNIT],2
 jb init_unit
init_units_done:
 cmp byte [bp-L_FOUND],0
 jne init_hook
 mov si,no_drive
 call print
 jmp init_end
init_hook:
 xor ax,ax
 mov ds,ax
 cli
 mov ax,[4Eh]
 mov bx,cs
 cmp ax,bx
 je init_vectors                 ; INT 13h is ours already (a restart that kept the vectors): INT 40h has the diskettes
 mov ax,[4Ch]
 mov [100h],ax
 mov ax,[4Eh]
 mov [102h],ax
init_vectors:
 mov word [4Ch],int13
 mov [4Eh],cs
 mov word [64h],boot
 mov [66h],cs
 mov ax,40h
 mov ds,ax
 mov al,[bp-L_FOUND]
 mov [75h],al
 mov byte [74h],0
 mov byte [76h],0
 mov byte [77h],0
init_end:
 mov sp,bp
 pop bp
 pop es
 pop ds
 pop di
 pop si
 pop dx
 pop cx
 pop bx
 pop ax
 popf
 retf

; The geometry of drive [bp-L_UNIT] into [bp-L_BUF]: cylinders high and low, heads, sectors.
; CF set when there is no such drive.
probe:
 call select
 mov dx,STAT
 in al,dx
 cmp al,0FFh                     ; nothing mounted: the bridge reads FFh
 je probe_far
 call probe_wait
 jc probe_far
 mov al,0ECh                     ; IDENTIFY
 out dx,al
 call probe_wait
 jc probe_far
 test al,1
 jnz probe_far
 test al,8
 jnz probe_read
probe_far:
 jmp probe_none
probe_read:
 xor ax,ax
 mov es,ax
 mov di,SCRATCH
 call read_data
 mov ax,[es:SCRATCH+120]         ; words 60 and 61: the sectors
 mov dx,[es:SCRATCH+122]
 mov bx,ax
 or bx,dx
 jnz probe_size
 mov ax,[es:SCRATCH+2]           ; no LBA count: cylinders x heads x sectors
 mul word [es:SCRATCH+6]
 mul word [es:SCRATCH+12]
probe_size:
 cmp dx,4                        ; at most 1024 x 16 x 17 sectors
 jb probe_tracks
 ja probe_clamp
 cmp ax,4000h
 jbe probe_tracks
probe_clamp:
 mov dx,4
 mov ax,4000h
probe_tracks:
 mov bx,17
 div bx
 mov [bp-L_TRACKS],ax
 mov byte [bp-L_BUF+3],17
 ; an image of a period drive has its geometry at once
 mov si,known
 mov cx,KNOWN
probe_known:
 cmp ax,[cs:si]
 je probe_order
 add si,2
 loop probe_known
 ; else a partition that ends on the last sector of a track names the heads
 mov word [bp-L_LBA],0
 mov word [bp-L_LBA+2],0
 mov ax,2001h
 call command
 jc probe_order
 mov di,SCRATCH
 call get_sector
 or ah,ah
 jnz probe_order
 cmp word [es:SCRATCH+510],0AA55h
 jne probe_order
 mov si,SCRATCH+446
 mov cx,4
probe_entry:
 cmp byte [es:si+4],0
 je probe_next
 mov al,[es:si+6]
 and al,63
 cmp al,17
 jne probe_next
 mov bl,[es:si+5]
 inc bl
 cmp bl,16
 ja probe_next
 call try_heads
 jnc probe_end
probe_next:
 add si,16
 loop probe_entry
probe_order:
 mov si,order
 mov cx,ORDER
probe_try:
 mov bl,[cs:si]
 call try_heads
 jnc probe_end
 inc si
 loop probe_try
probe_none:
 cmp byte [bp-L_UNIT],0
 je probe_fail
 mov dx,CONTROL                  ; a second drive that never answered: a reset frees the first
 mov al,4
 out dx,al
 xor al,al
 out dx,al
 mov byte [bp-L_UNIT],0
 call select
 mov di,12
 call wait_bsy
 mov byte [bp-L_UNIT],1
probe_fail:
 stc
probe_end:
 ret

; BL heads: CF clear and the geometry set when they divide the tracks into 2..1024 cylinders.
try_heads:
 xor bh,bh
 mov ax,[bp-L_TRACKS]
 xor dx,dx
 div bx
 or dx,dx
 jnz th_no
 cmp ax,1024
 ja th_no
 cmp ax,2
 jb th_no
 mov [bp-L_BUF],ah
 mov [bp-L_BUF+1],al
 mov [bp-L_BUF+2],bl
 clc
 ret
th_no:
 stc
 ret

; Not busy within about a second for drive 0, a quarter for drive 1 (an absent second drive may never
; answer). DX = STAT, AL the status.
probe_wait:
 mov di,3
 cmp byte [bp-L_UNIT],0
 je wait_bsy
 mov di,1

; Waits until the drive is not busy; DI the outer loops (about a third of a second each at 4.77 MHz).
; DX = STAT and AL the status on return; CF set on a timeout.
wait_bsy:
 push cx
 mov dx,STAT
wb_outer:
 xor cx,cx
wb_inner:
 in al,dx
 test al,80h
 jz wb_ok
 loop wb_inner
 dec di
 jnz wb_outer
 pop cx
 stc
 ret
wb_ok:
 pop cx
 clc
 ret

; The parameter table of the drive's geometry: this ROM's own for a period drive, else one built in RAM taken
; from the top of memory; INT 41h (drive 0) or INT 46h (drive 1) then points at it. DS = 0.
place_table:
 mov ah,[bp-L_BUF]
 mov al,[bp-L_BUF+1]
 mov bl,[bp-L_BUF+2]
 mov si,tables
 mov cx,TABLES
pt_search:
 cmp ax,[cs:si]
 jne pt_next
 cmp bl,[cs:si+2]
 je pt_rom
pt_next:
 add si,16
 loop pt_search
 ; a geometry of its own: 16 bytes in RAM
 push ax
 cmp word [bp-L_RAM],0
 jne pt_have
 mov ax,[413h]
 dec ax
 mov [413h],ax
 mov cl,6
 shl ax,cl
 mov [bp-L_RAM],ax
pt_have:
 pop ax
 mov es,[bp-L_RAM]
 mov di,0
 cmp byte [bp-L_UNIT],0
 je pt_fill
 mov di,16
pt_fill:
 mov [es:di],ax
 mov [es:di+2],bl
 mov [es:di+3],ax
 mov [es:di+5],ax
 mov byte [es:di+7],0Bh
 mov byte [es:di+8],05h
 mov byte [es:di+9],0Ch
 mov byte [es:di+10],0B4h
 mov byte [es:di+11],28h
 mov [es:di+12],ax
 mov byte [es:di+14],17
 mov byte [es:di+15],0
 mov ax,es
 mov si,di
 jmp short pt_set
pt_rom:
 mov ax,cs
pt_set:
 mov bx,104h
 cmp byte [bp-L_UNIT],0
 je pt_vector
 mov bx,118h
pt_vector:
 mov [bx],si
 mov [bx+2],ax
 ret

; "Fixed disk 0: 615 cylinders, 4 heads, 17 sectors"
show_drive:
 mov si,msg_disk
 call print
 mov al,[bp-L_UNIT]
 add al,'0'
 call putc
 mov si,msg_colon
 call print
 mov ah,[bp-L_BUF]
 mov al,[bp-L_BUF+1]
 call print_dec
 mov si,msg_cyl
 call print
 mov al,[bp-L_BUF+2]
 xor ah,ah
 call print_dec
 mov si,msg_heads
 call print
 mov al,[bp-L_BUF+3]
 xor ah,ah
 call print_dec
 mov si,msg_sectors
 call print
 ret

; --- the drives -----------------------------------------------------------------------------

; Drive [bp-L_UNIT] selected, LBA addressing, the top address bits zero.
select:
 mov al,[bp-L_UNIT]
 mov cl,4
 shl al,cl
 or al,0E0h
 mov dx,DRVH
 out dx,al
 ret

; Command AH for AL sectors from [bp-L_LBA] on drive [bp-L_UNIT]. CF set and AH = 80h when the drive
; stays busy.
command:
 push ax
 call select
 mov di,12
 call wait_bsy
 pop ax
 jc cm_timeout
 mov dx,COUNT
 out dx,al
 mov al,[bp-L_LBA]
 mov dx,SECTOR
 out dx,al
 mov al,[bp-L_LBA+1]
 mov dx,CYLL
 out dx,al
 mov al,[bp-L_LBA+2]
 mov dx,CYLH
 out dx,al
 mov al,ah
 mov dx,STAT
 out dx,al
 clc
 ret
cm_timeout:
 mov ah,80h
 stc
 ret

; The drive's answer awaited: AH = 0 with data requested (CF clear) or none (CF set), else the BIOS
; status of its error.
answer:
 push di                         ; a transfer's destination
 call await
 pop di
 ret
await:
 mov di,24
 call wait_bsy
 jc an_timeout
 test al,1
 jnz an_error
 xor ah,ah
 test al,8
 jnz an_data
 stc
an_data:
 ret
an_timeout:
 mov ah,80h
 ret
an_error:
 mov dx,ERROR
 in al,dx
 mov ah,04h                      ; sector not found
 test al,10h
 jnz an_end
 mov ah,10h                      ; uncorrectable data
 test al,40h
 jnz an_end
 mov ah,0Ah                      ; bad sector
 test al,80h
 jnz an_end
 mov ah,01h                      ; the command refused
 test al,04h
 jnz an_end
 mov ah,0BBh
an_end:
 ret

; 256 words from the drive to ES:DI.
read_data:
 mov cx,256
 mov dx,DATA
rd_word:
 in al,dx
 stosb
 or dl,8
 in al,dx
 stosb
 and dl,0F7h
 loop rd_word
 ret

; A sector of a read command to ES:DI (dropped for function 04h). AH = 0 or the status.
get_sector:
 call answer
 or ah,ah
 jnz gs_end
 mov ah,0BBh
 jc gs_end
 cmp byte [bp-L_FUNC],4
 je gs_drop
 call read_data
 xor ah,ah
 ret
gs_drop:
 mov cx,256
 mov dx,DATA
gs_word:
 in al,dx
 loop gs_word
 xor ah,ah
gs_end:
 ret

; A sector of a write command from ES:SI. AH = 0 or the status.
put_sector:
 call answer
 or ah,ah
 jnz ps_end
 mov ah,0BBh
 jc ps_end
 mov cx,256
ps_word:
 mov ax,[es:si]
 add si,2
 xchg al,ah
 mov dx,DATAH
 out dx,al
 mov al,ah
 mov dx,DATA
 out dx,al
 loop ps_word
 xor ah,ah
ps_end:
 ret

; The parameter table of drive [bp-L_UNIT] into [bp-L_TABLE] (from INT 41h or INT 46h).
get_table:
 push es
 xor ax,ax
 mov es,ax
 mov bx,104h
 cmp byte [bp-L_UNIT],0
 je gt_vector
 mov bx,118h
gt_vector:
 mov ax,[es:bx]
 mov [bp-L_TABLE],ax
 mov ax,[es:bx+2]
 mov [bp-L_TABLE+2],ax
 pop es
 ret

; The caller's cylinder, head and sector into [bp-L_LBA]. CF set and AH = 04h when they are not on the drive.
make_lba:
 push es
 les di,[bp-L_TABLE]
 mov al,[bp+F_CX+1]
 mov ah,[bp+F_CX]
 mov cl,6
 shr ah,cl                       ; AX = the cylinder
 cmp ax,[es:di]
 jae ml_bad
 mov bl,[es:di+2]
 xor bh,bh
 cmp [bp+F_DX+1],bl
 jae ml_bad
 mov cl,[bp+F_CX]
 and cl,3Fh
 jz ml_bad
 cmp cl,17
 ja ml_bad
 mul bx
 mov bl,[bp+F_DX+1]
 add ax,bx
 mov bx,17
 mul bx
 dec cl
 xor ch,ch
 add ax,cx
 adc dx,0
 mov [bp-L_LBA],ax
 mov [bp-L_LBA+2],dx
 pop es
 clc
 ret
ml_bad:
 pop es
 mov ah,04h
 stc
 ret

; --- INT 13h --------------------------------------------------------------------------------

int13:
 sti
 cmp dl,80h
 jae hd
 int 40h                         ; a diskette: the BIOS's own service
 retf 2
hd:
 push ds
 push es
 push si
 push di
 push bx
 push cx
 push dx
 push bp
 mov bp,sp
 sub sp,LOCALS
 cld
 mov [bp-L_FUNC],ah
 mov [bp-L_COUNT],al
 mov al,dl
 sub al,80h
 mov [bp-L_UNIT],al
 mov ax,40h
 mov ds,ax
 mov ah,[bp-L_FUNC]
 cmp ah,8
 jne hd_check
 jmp f_params
hd_check:
 cmp ah,15h
 ja bad_command
 mov al,[bp-L_UNIT]
 cmp al,[75h]
 jae bad_command
 call get_table
 mov bl,[bp-L_FUNC]
 xor bh,bh
 shl bx,1
 jmp [cs:bx+ftable]

bad_command:
 mov ah,1

; AH = status: kept in 40:74h, CF set when it is not 0, AL = [bp-L_COUNT].
done:
 mov [74h],ah
 mov al,[bp-L_COUNT]
 mov sp,bp
 pop bp
 pop dx
 pop cx
 pop bx
 pop di
 pop si
 pop es
 pop ds
 cmp ah,1
 cmc
 retf 2

ftable:
 dw f_ok, f_status, f_read, f_write, f_read, f_ok, f_ok, f_ok
 dw f_params, f_ok, bad_command, bad_command, f_seek, f_ok, bad_command, bad_command
 dw f_ready, f_ok, f_ok, f_ok, f_ok, f_type

; 00h, 05h-07h, 09h, 0Dh, 11h-14h: nothing to do on an image.
f_ok:
 xor ah,ah
 jmp done

; 01h: the last status in AL.
f_status:
 mov al,[74h]
 mov [bp-L_COUNT],al
 xor ah,ah
 jmp done

; 02h and 04h: AL sectors read to ES:BX, or read and dropped.
f_read:
 mov al,[bp-L_COUNT]
 or al,al
 jz f_bad
 mov [bp-L_LEFT],al
 call make_lba
 jc fr_end
 mov ah,20h                      ; READ SECTORS
 mov al,[bp-L_COUNT]
 call command
 jc fr_end
 mov es,[bp+F_ES]
 mov di,[bp+F_BX]
fr_sector:
 call get_sector
 or ah,ah
 jnz fr_end
 dec byte [bp-L_LEFT]
 jnz fr_sector
fr_end:
 jmp done

f_bad:
 jmp bad_command

; 03h: AL sectors written from ES:BX.
f_write:
 mov al,[bp-L_COUNT]
 or al,al
 jz f_bad
 mov [bp-L_LEFT],al
 call make_lba
 jc fw_end
 mov ah,30h                      ; WRITE SECTORS
 mov al,[bp-L_COUNT]
 call command
 jc fw_end
 mov es,[bp+F_ES]
 mov si,[bp+F_BX]
fw_sector:
 call put_sector
 or ah,ah
 jnz fw_end
 dec byte [bp-L_LEFT]
 jnz fw_sector
 call answer                     ; the last sector stored
fw_end:
 jmp done

; 0Ch: the cylinder and head checked.
f_seek:
 and byte [bp+F_CX],0C0h
 or byte [bp+F_CX],1
 call make_lba
 jc fs_end
 xor ah,ah
fs_end:
 jmp done

; 10h: the drive ready.
f_ready:
 call select
 mov di,12
 call wait_bsy
 mov ah,80h
 jc fy_end
 mov ah,0AAh
 test al,40h
 jz fy_end
 xor ah,ah
fy_end:
 jmp done

; 08h: DL drives, DH the last head, CH and CL the last usable cylinder (the last one is kept for
; diagnostics, as on the PC/XT) and the sectors.
f_params:
 mov al,[75h]
 mov [bp+F_DX],al
 mov al,[bp-L_UNIT]
 cmp al,[75h]
 jb fp_drive
 mov word [bp+F_CX],0
 mov byte [bp+F_DX+1],0
 mov ah,7
 jmp done
fp_drive:
 call get_table
 push es
 les di,[bp-L_TABLE]
 mov ax,[es:di]
 mov bl,[es:di+2]
 pop es
 sub ax,2
 mov [bp+F_CX+1],al
 mov cl,2
 shr ax,cl
 and al,0C0h
 or al,17
 mov [bp+F_CX],al
 dec bl
 mov [bp+F_DX+1],bl
 mov byte [bp-L_COUNT],0
 xor ah,ah
 jmp done

; 15h (as on the PC/AT): AH = 3, a fixed disk; CX:DX its usable sectors.
f_type:
 push es
 les di,[bp-L_TABLE]
 mov ax,[es:di]
 dec ax
 mov bl,[es:di+2]
 pop es
 xor bh,bh
 mul bx
 mov bx,17
 mul bx
 mov [bp+F_CX],dx
 mov [bp+F_DX],ax
 mov byte [74h],0
 mov al,[bp-L_COUNT]
 mov sp,bp
 pop bp
 pop dx
 pop cx
 pop bx
 pop di
 pop si
 pop es
 pop ds
 mov ah,3
 clc
 retf 2

; --- INT 19h --------------------------------------------------------------------------------

; The diskette in drive A: first (through the BIOS's diskette service; an empty drive is not tried
; again), then the fixed disk's master boot record.
boot:
 sti
 cld
 xor ax,ax
 mov ds,ax
 mov es,ax
 mov si,3
bt_floppy:
 xor ax,ax
 xor dx,dx
 int 40h
 mov ax,0201h
 mov bx,7C00h
 mov cx,1
 xor dx,dx
 int 40h
 jnc bt_go_floppy
 cmp ah,80h
 je bt_fixed
 dec si
 jnz bt_floppy
bt_fixed:
 mov si,2
bt_fixed_try:
 xor ax,ax
 mov dx,80h
 int 13h
 mov ax,0201h
 mov bx,7C00h
 mov cx,1
 mov dx,80h
 int 13h
 jnc bt_check
 dec si
 jnz bt_fixed_try
 jmp short bt_none
bt_check:
 cmp word [7DFEh],0AA55h
 jne bt_none
 mov dx,80h
 jmp far 0:7C00h
bt_go_floppy:
 xor dx,dx
 jmp far 0:7C00h
bt_none:
 mov si,no_system
 call print
 xor ah,ah
 int 16h
 jmp boot

; --- text -----------------------------------------------------------------------------------

; The zero-ended text at CS:SI through the BIOS's teletype.
print:
 push ax
 push bx
pr_char:
 mov al,[cs:si]
 inc si
 or al,al
 jz pr_end
 call putc
 jmp short pr_char
pr_end:
 pop bx
 pop ax
 ret

putc:
 push ax
 push bx
 mov ah,0Eh
 mov bx,7
 int 10h
 pop bx
 pop ax
 ret

; AX in decimal.
print_dec:
 push ax
 push bx
 push cx
 push dx
 mov bx,10
 xor cx,cx
pd_digit:
 xor dx,dx
 div bx
 push dx
 inc cx
 or ax,ax
 jnz pd_digit
pd_out:
 pop ax
 add al,'0'
 call putc
 loop pd_out
 pop dx
 pop cx
 pop bx
 pop ax
 ret

banner: db 'JUNIOR-XT Winchester ROM 1.0', 13, 10, 0
no_drive: db 'Winchester coupler: no drive', 13, 10, 0
msg_disk: db 'Fixed disk ', 0
msg_colon: db ': ', 0
msg_cyl: db ' cylinders, ', 0
msg_heads: db ' heads, ', 0
msg_sectors: db ' sectors', 13, 10, 0
no_system: db 13, 10, 'No system disk: put one in drive A: and press a key', 13, 10, 0

; The tracks of the period drives' images, and the heads tried in turn for any other.
KNOWN equ 6
known: dw 2460, 3665, 4885, 6839, 8192, 1224
ORDER equ 16
order: db 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 2, 3, 1

; Fixed disk parameter tables of the period drives (the PC/AT layout): cylinders, heads, reduced write
; current and write precompensation cylinders (none: the cylinder count), ECC burst, control byte (step
; rate 70 us), the PC/XT's three timeouts, landing zone, sectors a track.
TABLES equ 6
tables:
 dw 615
 db 4
 dw 615, 615
 db 0Bh, 05h, 0Ch, 0B4h, 28h
 dw 615
 db 17, 0
 dw 733
 db 5
 dw 733, 733
 db 0Bh, 05h, 0Ch, 0B4h, 28h
 dw 733
 db 17, 0
 dw 977
 db 5
 dw 977, 977
 db 0Bh, 05h, 0Ch, 0B4h, 28h
 dw 977
 db 17, 0
 dw 977
 db 7
 dw 977, 977
 db 0Bh, 05h, 0Ch, 0B4h, 28h
 dw 977
 db 17, 0
 dw 1024
 db 8
 dw 1024, 1024
 db 0Bh, 05h, 0Ch, 0B4h, 28h
 dw 1024
 db 17, 0
 dw 306
 db 4
 dw 306, 306
 db 0Bh, 05h, 0Ch, 0B4h, 28h
 dw 306
 db 17, 0
