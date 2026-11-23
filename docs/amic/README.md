# AMIC for MiSTer

aMIC with its original Z80 monitor and BASIC: keyboard and cassette PPI, an asynchronous 8251 serial port, a second 8255 for parallel peripherals or a joystick, and 16, 32 or 48 KiB of RAM.

## Start

1. Extract `MiSTerRO-<version>-AMIC.zip` onto the MiSTer card, preserving paths.
2. Select **AMIC** under Computers.
3. At the monitor prompt enter `G0800` to start BASIC.
4. Load the demo from BASIC with `LOA`, select `demo.pzx` in **Load tape**, then enter `RUN` when READY returns. `SAV` saves through the native cassette output.

## Options

| Menu | Option | Choices |
| --- | --- | --- |
| System | Memory | 32 KiB, 16 KiB, 48 KiB |
| System | Load firmware | `boot.rom` is loaded at start; another firmware file can be loaded |
| Ports & Controllers | Serial baud | 1200, 600, 300 |
| Ports & Controllers | User port | GPIO 0-5, 6-11, 12-17, 18-23 |
| Audio & Video | Tape sound | On, Off |
| Audio & Video | Aspect ratio | Original, Full Screen, ARC1, ARC2 |
| Audio & Video | Scandoubler Fx | None, HQ2x, CRT 25%, CRT 50% |

## Tapes and disks

The default firmware repairs the archived LP & CO monitor/BASIC RAM probe and cassette entry points; the unmodified ROM is supplied as `support/original.rom`.

F5 plays or pauses the tape, F6 selects the previous block, F7 the next block, F10 sends NMI and F11 resets. Tape files are limited to 256 KiB; use PZX/TZX conversion for long audio recordings.

## Ports and controllers

Serial output uses MiSTer's UART pins. The User port routes one bank of six of the 24 native GPIO lines at a time; a MiSTer joystick pulls the low five inputs of the second 8255. Consult [hardware and ports](hardware.md) for the register and pin assignments.

## Included files

`games/AMIC/` contains `boot.rom`, the `demo` tape, its support files and a checksum manifest (`bundle.json`). [Provenance](provenance.md) identifies originals, family references and replacement software.

## Build

From `src/core-amic/`, use `tools/build.ps1 assets`, `tools/build.ps1 test`, `tools/build.ps1 quartus`, then `tools/build.ps1 package`. Windows builds use WSL Debian; Linux can run `python3 tools/build.py` with the same actions.

Required tools: Python 3 with Pillow, Verilator, Icarus Verilog, Pasmo, Docker and the pinned toolchain images in `dependencies.lock.json`. The MiSTer framework is the pinned submodule of the HC core (`git submodule update --init`).

The firmware and demos come from the release's assets archive (`python tools/assets.py unpack`, from the repository's root). `tools/build.ps1 fetch` downloads optional original reference sources and verifies their hashes.

[Validation](validation.md) records the native firmware and FPGA checks.
