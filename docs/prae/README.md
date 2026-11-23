# PRAE for MiSTer

PRAE-M with selectable BASIC 3.6 and 3.5: native 8 by 5 keyboard, software RS-232, cassette input/output, speaker and 256 by 256 monochrome display. The CPU-visible archived ROMs account for the crossed D3/D4 EPROM data lines.

## Start

1. Extract `MiSTerRO-<version>-PRAE.zip` onto the MiSTer card, preserving paths.
2. Select **PRAE** under Computers.
3. Press Enter for the local console, press Enter past the welcome page, then press Enter at `HIGHEST MEMORY?`.
4. Load the demo with `ALOAD "DEMO"`, select the model's `demo.pzx` in **Load tape** and enter `RUN` when READY returns.

## Options

| Menu | Option | Choices |
| --- | --- | --- |
| System | Firmware | BASIC 3.6, BASIC 3.5; a change resets the computer |
| System | Load firmware | `boot.rom` is loaded at start; another firmware file can be loaded |
| Audio & Video | Tape sound | On, Off |
| Audio & Video | Aspect ratio | Original, Full Screen, ARC1, ARC2 |
| Audio & Video | Scandoubler Fx | None, HQ2x, CRT 25%, CRT 50% |

## Tapes and disks

F5 plays or pauses the tape, F6 selects the previous block, F7 the next block, F10 sends NMI and F11 resets. Tape files are limited to 256 KiB; use PZX/TZX conversion for long audio recordings.

## Ports and controllers

Software RS-232 uses MiSTer's UART pins; its framing and baud rate remain under the original firmware's control. Consult [hardware and ports](hardware.md) for the register and pin assignments.

## Included files

`games/PRAE/` contains `boot.rom` and one folder for each model with a `demo` tape, its support files and a checksum manifest (`bundle.json`). [Provenance](provenance.md) identifies originals, family references and replacement software.

## Build

From `src/core-prae/`, use `tools/build.ps1 assets`, `tools/build.ps1 test`, `tools/build.ps1 quartus`, then `tools/build.ps1 package`. Windows builds use WSL Debian; Linux can run `python3 tools/build.py` with the same actions.

Required tools: Python 3 with Pillow, Verilator, Icarus Verilog, Pasmo, Docker and the pinned toolchain images in `dependencies.lock.json`. The MiSTer framework is the pinned submodule of the HC core (`git submodule update --init`).

The firmware and demos come from the release's assets archive (`python tools/assets.py unpack`, from the repository's root). `tools/build.ps1 fetch` downloads optional original reference sources and verifies their hashes.

[Validation](validation.md) records the native firmware and FPGA checks.
