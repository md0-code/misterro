# JUNIOR-XT for MiSTer

FEPER JUNIOR-XT with its original BIOS and character ROM: 8086 or 8088 CPU,
64 to 640 KiB RAM, CGA or monochrome display coupler, PC speaker, XT keyboard,
floppy DMA, Winchester coupler, the native dual Z80-SIO serial and printer
adapter or PC serial ports with a mouse, and a game adapter. Requires a
MiSTer-compatible SDRAM module.

## Start

1. Extract `MiSTerRO-<version>-JUNIORXT.zip` onto the MiSTer card, preserving paths.
2. Select **JUNIORXT** under Computers. The launcher loads the original V4 BIOS;
   the screen stays dark until the POST starts.
3. Open the OSD with **Win + F12** and mount a disk in **Floppy A**:
   `games/JUNIORXT/manual.img` (the technical manual as a bootable application)
   or `games/JUNIORXT/demo.img` (FreeDOS; enter `DEMO` for text, graphics and
   speaker tests).
4. Select **Reset**.

Save the MiSTer configuration to keep the settings and mounted disks. F12
pauses the computer. Board options take effect at once; select **Reset** so
that the BIOS detects them.

## Options

| Menu | Option | Choices |
| --- | --- | --- |
| System | CPU | 8086 (original), 8088 |
| System | CPU speed | 4.77 MHz (original), 7.16 MHz, 9.54 MHz, Max |
| System | Memory | 640 KiB (256 KiB board and the 384 KiB module), 256, 192, 128, 64 KiB |
| System | Display coupler | CGA 80 columns, CGA 40 columns, Monochrome (MDA), None |
| System | Winchester coupler | Off, On: fixed disks 1 and 2 |
| System | Junior BIOS | `boot.rom` (V4) or a file from `games/JUNIORXT/bios/` |
| System | Option ROM C8000 | a ROM image of up to 16 KiB for the memory module's socket |
| Ports & Controllers | Serial board | Junior SIO + printer, PC COM1 (mouse), PC COM1 + COM2, None |
| Ports & Controllers | Game adapter | Off, On; joysticks analog, digital or disabled |
| Audio & Video | CGA monitor | RGBI, RGB, Composite green |

The DIP switches follow the options: memory banks, display coupler and the
number of diskette drives (one, or two when Floppy B holds a disk).

## Tapes and disks

Diskette images are raw sector dumps. The bundled FreeDOS disk uses the native
**320 KB, 40-track, two-head, eight-sector** format of the V4 diskette table;
boot software for other formats must supply matching disk parameters. Disk
changes persist unless **Write Protect** is enabled.

With the **Winchester coupler** on, **Fixed disk 1** and **2** take raw images
of 17-sector tracks, the same files MezinXT uses: 21,411,840 bytes is a 20 MB
disk of 615 cylinders and 4 heads; 30, 40, 60 and 70 MB sizes follow the same
rule. The Winchester ROM occupies the C8000 socket, adds fixed-disk services to
INT 13h and boots the diskette in A first, then the fixed disk. A new disk needs
`FDISK` and `FORMAT`. The second disk needs the first.

A loaded **Option ROM C8000** takes the socket while the Winchester coupler is
off. ROMs for the sockets at F0000 and F8000 are loaded as part of a 64 KiB
**Junior BIOS** image.

## Ports and controllers

The CGA coupler drives three monitors, as the card's three outputs do: **RGBI**
(16 colours), **RGB** (the RCA jacks mix intensity into each channel: 15
colours, dark yellow instead of brown) and **Composite green** (16 brightness
levels from the card's resistor network). The monochrome coupler shows 80x25
text in 9x14 cells from the Junior character ROM on a green monitor, and
carries a second printer port at `3BCh`.

**Junior SIO + printer** is the board the V4 BIOS expects: the Z80-SIO at
`250h–25Fh` with IRQ4 and its own baud timer, and the printer port at `378h`.
Channel A uses MiSTer's HPS serial bridge; set the MiSTer UART baud to match the
guest program (default 9600). Channel B uses the USER I/O connector: RX pin 0,
TX 1, RTS 2, CTS 3, DTR 4, DSR 5 and DCD 6. These are FPGA logic-level signals;
use a suitable adapter for an RS-232 device. `SIOTEST` exercises the BIOS serial
API with a channel A loopback connected.

**PC COM1 / COM2** replaces that board with 8250 ports at `3F8h` (IRQ4) and
`2F8h` (IRQ3), which BIOS 3.0 and 5.0 expect. COM1 carries the MiSTer mouse as a
Microsoft serial mouse; COM2 uses the HPS serial bridge.

## Included files

`games/JUNIORXT/` contains `boot.rom` (the original interleaved V4 firmware
followed by the Winchester ROM), the original 3.0, 5.0 and 5.0-alt firmware
under `bios/`, the manual disk (`manual.img`), the boot/demo disk (`demo.img`), the character EPROM under `support/` and a
checksum/provenance manifest (`bundle.json`). The character ROM is already built
into the core.

## Not included

The 8087, the light pen, a third and fourth diskette drive, 8-inch drives,
synchronous serial modes and the tape and instrumentation couplers are not
implemented. Printer ports accept data but no printer is attached.

## Build

Initialize the pinned dependency with `git submodule update --init --recursive`.
Use WSL Debian with Python 3 and Pillow, Verilator, Icarus Verilog, GNU binutils, mtools,
make, a C++ compiler and Docker. From the repository's root:

```powershell
.\src\core-juniorxt\tools\build.ps1 fetch
.\src\core-juniorxt\tools\build.ps1 assets
.\src\core-juniorxt\tools\build.ps1 test
.\src\core-juniorxt\tools\build.ps1 quartus
.\src\core-juniorxt\tools\build.ps1 package
```

Quartus uses placement seed 5 and extra timing optimization by default. Override it with `quartus --seed N`
when building for a different toolchain; packaging still requires every
constrained timing corner to pass.

See [hardware](hardware.md), [sources](sources.lock.json) and
[licences](licenses.md).
