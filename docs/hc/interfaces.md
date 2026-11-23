# HC disk and expansion interfaces

The [HC85 Interface 1 technical manual and schematics](https://www.z80-romania.ro/198x_Interfata_1_pentru_HC_85-245),
[HC90/91 Interface 1 schematics](https://www.z80-romania.ro/1991_1992_Interfata_1_pentru_HC_90_sau_HC_91-198),
[HC91 Plus manual](https://www.z80-romania.ro/1994_Manual_de_utilizare_HC_91_Plus-28)
and [HC2000 circuit reconstruction](https://github.com/badrianiulian/HC2000/tree/Revision-E)
define the additional bus hardware. Download identities and archive members are
locked in [sources.lock.json](sources.lock.json).

## Model selection and firmware

The 64 KiB firmware container has a 1024-byte page table followed by a 63 KiB
dictionary area. Its 256-byte pages reconstruct the 159,744 bytes of firmware
banks losslessly; original ROMs and the labelled compatibility bridge have
separate virtual addresses. `tools/pack_firmware.py` checks reconstruction byte for byte. The table
and dictionary occupy separate synchronous memories. A two-stage read settles
before the CPU samples the bus.

| Virtual offset | Firmware |
| --- | --- |
| 00000 | HC85 BASIC, 16K |
| 04000 | HC90 BASIC, 16K |
| 08000 | HC91 BASIC, 16K |
| 0C000 | HC88 bootstrap, 2K |
| 0C800 | HC91 Plus BASIC, 32K |
| 14800 | HC2000 BASIC, 16K |
| 18800 | HC2000 CP/M, 16K |
| 1C800 | HC85 Interface 1, five original 2K EPROMs |
| 1F000 | HC90/91/2000 Interface 1, 16K |
| 23000 | Family CP/M compatibility entry and original Rev-E BIOS, 16K |

The HC2000 BASIC, CP/M and Interface 1 dumps match MAME's independent firmware
identities: `f8139fc38478691cf44944dc83fd6e70b0f002fb`,
`55a30d99c37c86c55ce6c8ecbe593b81d9819e90` and
`b76d2bebcd938238f790e395859d0d237637d33e` respectively. The locked Fuse-ro
archive supplies those unchanged dumps. HC2000 uses this v1 CP/M revision with
the original 720K system disk. Its external-drive DPB uses the 360K directory layout,
so the HC2000 bundle supplies an original HC91 disk as `support/external.dsk`.

HC90/91/128 use the original 8K Rev-E CP/M BIOS from offset C000 of the locked
64K dump, SHA-1 `eed54072c87255d8194bb021dfc610c9decb29cb`. Its format descriptors
match the original HC91 360K disks. A separate compatibility entry copies a
ten-byte trampoline into RAM, selects configuration 3 and jumps to F800, the
original Rev-E disk entry. `build_family_cpm_rom.py` reproduces this bridge;
the BIOS bytes and original disks remain unchanged. Their bundles label this
compatible bootstrap rather than presenting it as a recovered HC91-specific ROM. HC91's original BASIC launcher switches
to it through 7E. HC128 BREAK/reset and the CP/M startup option select it before
execution; the original 128K BASIC ROM has no bytes patched for disk boot.

## HC91 Plus paging and sound

Port 7FFD has the manual's layout: bits 0-2 select the C000 RAM page, bit 3 selects
the displayed screen, bit 4 selects the BASIC ROM page and bit 5 locks subsequent
paging writes until reset. RAM pages 5 and 2 remain at 4000 and 8000. Optional
AY-3-8912 register/data access uses FFFD/BFFD at a 1.75 MHz chip enable, including
tone, noise and envelopes. CP/M mode releases the AY decoding from disk ports.

Interface 1 automatic entry is enabled on the 48K BASIC page. It does not intercept
the 128K editor ROM's startup instruction at address 0009.

## Configuration and CP/M RAM

The HC90/91 family configuration and HC2000 use port 7E:

| Bit | Function |
| --- | --- |
| 0 | Select BASIC or CP/M firmware |
| 1 | Map RAM at 0000 and the upper ROM half at E000 |
| 2 | Lock configuration writes until reset |
| 3 | Select video RAM at 4000 or C000 |

C7 enables the upper-RAM A13 alias, making C000-DFFF access E000-FFFF RAM.
C5 releases it. ROM overlays remain read-only. Native CP/M firmware controls
these signals itself, including the video-screen selection.

## Interface 1 paging and ports

Opcode fetches at the decoded 0008/1708 entry windows assert PHANTOM/ROMCS.
The 0700 exit opcode is fetched from the interface; M1's trailing edge releases
the overlay. HC85 has 10K EPROM and 1K local RAM, with RAM mirrors in 2800-2FFF.
The later interface has a 16K EPROM and the 1K SRAM mirrors selected by A13/A11.

| Port | Function |
| --- | --- |
| 05/07 | Floppy control; A1 is an alias |
| 85 | 8272 main status |
| 87 | 8272 command/data/result register |
| EF | Serial/network mode, readiness and network WAIT control |
| F7 | Serial transmit bit, serial receive bit 7 |
| 1F | Kempston joystick input |

Floppy-control bits are TC, drive A, drive B, motor and reset-release in bits 0-4.
Motor feedback is active while the retriggerable delay runs. The selected drive,
mounted image, motor and reset signals gate controller readiness. Both DSK and
EDSK track/sector tables are honored, including 256- and 512-byte sectors.

HC88 keeps its distinct DD/DF, E7, EF and F7 decoding; see [HC88](hc88.md).

## Disk writes and formatting

READ/WRITE DATA operate on mounted images through MiSTer's sector interface.
FORMAT TRACK collects CHRN records, updates sector metadata, writes the fill byte
to every sector and invalidates cached track information. Partial host sectors
preserve neighboring bytes. Write-protected images reject writes and formatting.
A format that exceeds an allocated track is rejected without modifying the image.

The HC85 blank template allocates 40 double-sided cylinders with sixteen 256-byte
sectors per track. Later-model system images supply the original 360K or 720K
geometries. Use image copies when experimenting with formatting or native saves.

## Serial and local network

Original firmware generates the serial bit timing. UART-facing start/stop polarity
is normalized from the HC Interface 1 latch, and readiness uses the original
handshake bit. External UART and USER inputs are synchronized before reaching the
emulated bus. The Interface 1 serial channel can drive a serial terminal or printer.

The local-network line is an open-drain USER bit 0, with the transmitter's own state
included in readback. EF bit 5 (F7 bit 5 on HC88) arms the original WAIT-on-active-network function;
WAIT releases when the line becomes passive. USER output releases the line in
serial mode. Matching USER bits and ground can link MiSTers at 3.3V logic levels.
The original HC analog network and RS232 connectors require level conversion.

## Shared FPGA storage

One T80 and one 128K physical RAM serve every profile. The video mirror and HC88
attribute store preserve independent raster access. Tape bytes are packed into
10-bit M10K words, retaining the full 256 KiB input limit. An independent test
reads every byte, including upload gaps and the final partial word.
