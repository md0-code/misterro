# JET for MiSTer

Electromagnetica JET with its original BASIC ROM: 48 KiB Spectrum-compatible memory map, keyboard, colour display with BRIGHT and FLASH, beeper, cassette input/output and Kempston joystick.

## Start

1. Extract `MiSTerRO-<version>-JET.zip` onto the MiSTer card, preserving paths.
2. Select **JET** under Computers.
3. Enter `LOAD ""`, then select `demo.tap` in **Load tape**. On the 48K keyword keyboard, J enters LOAD; Shift plus the quote key enters a double quote. The program autostarts.

## Options

| Menu | Option | Choices |
| --- | --- | --- |
| System | Load firmware | `boot.rom` is loaded at start; another firmware file can be loaded |
| Audio & Video | Tape sound | On, Off |
| Audio & Video | Aspect ratio | Original, Full Screen, ARC1, ARC2 |
| Audio & Video | Scandoubler Fx | None, HQ2x, CRT 25%, CRT 50% |

## Tapes and disks

F5 plays or pauses the tape, F6 selects the previous block, F7 the next block, F10 sends NMI and F11 resets. Tape files are limited to 256 KiB; use PZX/TZX conversion for long audio recordings.

## Ports and controllers

The MiSTer gamepad supplies the five Kempston direction/fire bits. Consult [hardware and ports](hardware.md) for the register and pin assignments.

## Included files

`games/JET/` contains `boot.rom`, the `demo` tape, its support files and a checksum manifest (`bundle.json`). [Provenance](provenance.md) identifies originals, family references and replacement software.

## Build

From `src/core-jet/`, use `tools/build.ps1 assets`, `tools/build.ps1 test`, `tools/build.ps1 quartus`, then `tools/build.ps1 package`. Windows builds use WSL Debian; Linux can run `python3 tools/build.py` with the same actions.

Required tools: Python 3 with Pillow, Verilator, Icarus Verilog, Pasmo, Docker and the pinned toolchain images in `dependencies.lock.json`. The MiSTer framework is the pinned submodule of the HC core (`git submodule update --init`).

The firmware and demos come from the release's assets archive (`python tools/assets.py unpack`, from the repository's root). `tools/build.ps1 fetch` downloads optional original reference sources and verifies their hashes.

[Validation](validation.md) records the native firmware and FPGA checks.
