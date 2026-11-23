# JUNIOR-XT hardware

The implementation specializes [PCXT MiSTer](https://github.com/MiSTer-devel/PCXT_MiSTer)
at `fa80b4050b1d790425f56edf22411914a18d6a5e`. Its MCL86 execution unit,
8086/8088 bus interface, 8288, 8237, 8259, 8253, 8255, CGA, monochrome coupler,
floppy controller, 8250 ports and game adapter execute the original firmware
and DOS software. The board options match the MezinXT emulator's. There are no BIOS service traps
or host-assisted disk-sector injection into CPU memory: disks enter through the
controller FIFO and 8237 byte DMA.

## Original references

[The Junior technical book and circuit archive](https://www.z80-romania.ro/1989_Carte_tehnica_Microcalculatorul_JUNIOR_XT-162)
provide the sources recorded in `sources.lock.json`.

- Manual PDF pages 13–15: CPU, 4.77 MHz clock, RAM, DMA, interrupts and keyboard.
- Pages 25–26: system address map. Pages 45–56: CGA modes and register programming.
- Pages 57–64: serial/parallel adapter, ports, interrupts and modem connections.
- Pages 75–76: compatibility and the replacement of the 8250 with a Z80-SIO.
- Schematics sheets 1–5: motherboard; 8–10: CGA; 13–15: floppy;
  17–19: SIO/parallel; 26: keyboard.

## Firmware

The original IC63 and IC64 EPROM dumps are interleaved into the low and high byte
lanes of `F0000h–FFFFFh`. The reset vector is the original far jump to `F000:E000`.
All four archived interleavings have zero additive checksum. No firmware bytes
are patched in the installation.

V4 probes SIO channel B at `253h` by writing/reading WR2, and installs the native
serial control addresses `251h` and `253h` in the BIOS data area. Its INT 14h
routine programs the SIO and baud 8253. V3 and both V5 archives instead probe
8250 interrupt-identification ports `3FAh` and `2FAh`. The bundled V4 therefore
matches the manual's serial board; the others run with the PC serial board.

## Memory and video

Conventional RAM starts at `00000h` and ends after the fitted banks: 64, 128,
192 or 256 KiB on the board, 640 KiB with the 384 KiB module. Addresses above it,
`A0000h` and the unpopulated `C0000h–EFFFFh` extension windows are open bus.
DIP switches SW3–4 report the board's banks, SW5–6 the display coupler and
SW7–8 the diskette drives; SW2 reports no 8087. CGA occupies `B8000h–BFFFFh`.
The schematic uses sixteen 4116 devices and retains CPU A14 and CRTC MA13:
its 32 KiB video store does not mirror at 16 KiB. The manual's memory table
reserves the upper 16 KiB, while its display description specifies 32 KiB.
The circuit address wiring determines the implemented decode.

Text is 40/80 columns by 25 rows with the original `CHAR_RF5.bin` 8×8 glyphs.
Graphics are the original CGA 320×200 four-colour and 640×200 monochrome modes.
Tandy, PCjr, EGA, EMS, UMBs and ISA audio extensions are disabled in this
profile.

The CGA coupler's three outputs (schematic sheet 10) are three monitors. The
nine-pin connector carries RGBI. Each RCA colour jack sums its colour line and
the intensity line through equal 470 Ω resistors, giving the levels 0, 111 and
255 of 255: fifteen colours, colour 6 dark yellow, colours 7 and 8 alike. The
composite jack sums red, green, blue and intensity through 1.2 kΩ, 560 Ω, 12 kΩ
and 3.7 kΩ: sixteen brightness levels (0, 7, 153, 160, 71, 79, 225, 232, 23, 30,
176, 184, 95, 102, 248, 255), shown in green. The derivation is in MezinXT's
hardware notes.

The monochrome coupler (catalogue 703.300.003) is not documented in the manual
and is implemented as its PC/XT equivalent: a 6845 at `3B4h/3B5h`, mode control
`3B8h`, status `3BAh`, text store at `B0000h`, a printer port at `3BCh`, 80×25
cells of 9×14 dots. Its font is made from the Junior character ROM: each glyph's
eight rows are placed on lines 1–13 of the cell (rows 0, 2, 4, 6 and 7 twice),
and the line-drawing characters `B0h–DFh` are stretched over all fourteen lines
so that they join. One display coupler is fitted at a time.

## Option ROM socket and Winchester coupler

The memory module's EPROM socket at `C8000h–CBFFFh` holds either a loaded option
ROM or, with the Winchester coupler on, the project's Winchester ROM. The BIOS
finds it by its `55h AAh` signature, checks its sum and calls offset 3.

The catalogue's Winchester coupler (703.300.006) is undocumented apart from its
ports and interrupt. The core provides the fixed disk through MiSTer's ATA
service behind an 8-bit bridge at `300h–30Fh`; the ROM (`software/hdrom.asm`)
is MezinXT's INT 13h fixed-disk service with an ATA back end. It reads each
drive's size, presents MezinXT's geometry (17 sectors a track, cylinders and
heads by image size) and addresses sectors by LBA, so that images move between
the emulator and the core. `boot.rom` carries the ROM after the 64 KiB BIOS.

## Game adapter and PC serial ports

The game adapter (703.300.008) answers at `200h–207h` as the PC/XT game control
adapter, fed by MiSTer controllers. The PC serial board is a pair of 8250 ports
at `3F8h` (IRQ4) and `2F8h` (IRQ3) for the 3.0 and 5.0 BIOS revisions; COM1
carries a Microsoft serial mouse. It shares IRQ4 with the native adapter, so
one of the two boards is fitted.

The private 8086 word path is enabled only during CPU ownership. DMA transfers
remain byte-wide even when a CPU word request is held while the bus is granted
to the DMA controller.

## Native serial adapter

| Ports | Function |
| --- | --- |
| `250h`, `251h` | Channel A data/control |
| `252h`, `253h` | Channel B data/control |
| `254h–257h` | Three-channel baud 8253 |
| `258h–25Bh` | SIO interrupt acknowledge |
| `25Ch–25Fh` | Channel A DSR in bit 0 |

The schematic's 18.432 MHz crystal is divided by U5 (7490) to 1.8432 MHz before
feeding the baud timer. The SIO applies its programmed x1/x16/x32/x64 divisor.
Both asynchronous channels provide 5–8 data bits, parity, selectable stops,
three-byte receive FIFO, buffered transmit, modem control and vectored
receive/transmit/status interrupts. The adapter inserts its documented I/O wait.
Synchronous modem-clock/SDLC wiring and the optional alternate address/IRQ jumper
configuration are not exposed by the MiSTer base profile. The adapter's printer
port is a data latch at `378h` with status and control registers; no printer is
attached.

## Floppy media

The original V4 ROM diskette parameter table has EOT=8. The demo is a 320 KiB
FAT12 image built from the archived FreeDOS 8086 kernel/shell and original boot
code, with a regenerated eight-sector BPB and the project's native COM programs.
The original ROM's disk driver performs all reads and writes through the µPD765
and 8237. A nine-sector image needs boot software that supplies an appropriate
RAM diskette parameter table, as on the original computer. As on the µPD765,
the table's EOT ends a multi-sector transfer only: a single sector beyond it is
read, which is how the manual disk loads its nine-sector tracks.

## MiSTer launch identity

[MiSTer Main's PCXT detection](https://github.com/MiSTer-devel/Main_MiSTer/blob/master/user_io.cpp)
selects the host floppy service from the original conf-string name. The RBF
therefore keeps `PCXT` as its protocol identity. The standard
[MGL launcher](https://mister-devel.github.io/MkDocs_MiSTer/advanced/mgl/)
sets the public name to `JUNIORXT`, so configuration and firmware live under
Junior's own name and folder. `_Computer/JUNIORXT.mgl` is the sole visible entry;
its private bitstream is `_Computer/.JUNIORXT/JUNIORXT.rbf`. The launcher loads
V4 and the Winchester ROM through ROM slot 0. No MiSTer Main replacement is needed. The PCXT start-up
picture is removed: the screen stays dark until the BIOS is loaded and the POST
draws.
