# CIP for MiSTer

Electronica CIP-01, CIP-02, CIP-03 and an experimental CIP-04 profile in one core.
CIP-01 retains BASIC loaded from tape at runtime; CIP-02/03 offer resident BASIC.
CIP-04 uses its original ROM set with the +3 128 KiB map, AY, DSK support and the
printer and serial ports its firmware drives; its extra 128 KiB mapper is unverified.
CIP-04 **requires SDRAM**; CIP-01/02/03 use on-chip RAM.

## Start

1. Extract `MiSTerRO-<version>-CIP.zip` onto the MiSTer card, preserving paths.
2. Select **CIP** under Computers. The root 83,968-byte `boot.rom` loads all original
   firmware banks automatically; model changes reset the computer and tape playback
   without reloading firmware.
3. Choose the **Model**.
4. CIP-01: press **L**, **Enter**, **Enter** to launch from cassette, choose
   **Load tape**, then `CIP01/basic.tzx`, and allow about two minutes for BASIC.
   CIP-02/03: press **Enter** at `Basic-S`.
5. Enter `LOAD ""` and select the model's `demo.tzx`. CIP-04 uses 48 BASIC.

## Options

| Menu | Option | Choices |
| --- | --- | --- |
| System | Model | CIP-01, CIP-02, CIP-03, CIP-04 experimental |
| System | CIP-02 startup | BASIC, Copier; a change resets the machine in CIP-02 mode |
| System | Load firmware | reloads the combined `boot.rom`; individual model ROM copies cannot replace it |
| Ports & Controllers | CIP-04 joystick | Kempston, Sinclair I, Sinclair II, Sinclair I+II, Cursor |
| Ports & Controllers | CIP-04 UART | Serial port, Printer |
| Audio & Video | Tape sound | On, Off |
| Audio & Video | Stereo mix | None, 25%, 50%, 100% |
| Audio & Video | Aspect ratio | Original, Full Screen, ARC1, ARC2 |
| Audio & Video | Scandoubler Fx | None, HQ2x, CRT 25%, CRT 50% |

## Tapes and disks

`basic.tzx` was recovered from the supplied `CipBas.mp3`. The original monitor
reads every cassette pulse through EAR; BASIC loads into RAM at runtime.
TAP, CSW v1, TZX and PZX tapes up to 256 KiB use the shared cassette buffer.

**CIP-02 startup** Copier uses the same cassette sequence as CIP-01. This is a
firmware compatibility control; physical CIP-02 ROM selection remains unverified.
In copier mode, reload BASIC after reset.

**Floppy A** takes a DSK image for CIP-04. See [model scope](models.md).

## Ports and controllers

F11 resets to the selected firmware; F12 opens the OSD. F1 pauses/resumes tape;
F2/F3 select previous/next blocks. Shift is CAPS SHIFT; Ctrl/Alt is SYMBOL SHIFT.
Cursor keys and Backspace provide Spectrum combinations. Native models use
Sinclair joystick mappings; CIP-04 has its own joystick selector.

**CIP-04 UART** connects MiSTer's UART pins to the serial port the CIP-04 firmware
drives through the sound chip's port (TXD, RXD and the two handshake lines), or to
its printer port: each byte the firmware prints (`LPRINT`, `LLIST`) is sent at
115200 baud, 8 data bits, no parity. The CIP manuals name a printer interface for
CIP-01/02/03 on the expansion connector but give no circuit for it.

## Included files

`games/CIP/` contains the combined `boot.rom` and one folder for each model
(`CIP01` to `CIP04`) with `boot.rom`, the original standalone `p` presentation as
`demo.tzx` and a checksum manifest (`bundle.json`); `CIP01` and `CIP02` also hold
`basic.tzx`. `bundle.json` records the scope, source and checksum of each file.

## Build

See [building](build.md), [hardware](hardware.md), [validation](validation.md)
and [licensing](licenses/README.md).
