# COBRA for MiSTer

CoBra in its original 64 KiB and documented 80 KiB configurations: native 8255, extended keyboard, serial and parallel interfaces, joystick, Z80 CTC and four-drive 8272 controller, with the 80-column display modification.

## Start

1. Extract `MiSTerRO-<version>-COBRA.zip` onto the MiSTer card, preserving paths.
2. Select **COBRA** under Computers.
3. Mount `games/COBRA/COBRA80/support/system.dsk` in **Floppy A**, select the 80K memory, reset and press D to boot CP/M. `DIR` lists the disk.
4. B starts Spectrum BASIC; C starts the monitor cassette loader. For a tape demo, enter `LOAD ""` and select the model's `demo.tap` in **Load tape**.

## Options

| Menu | Option | Choices |
| --- | --- | --- |
| System | Memory | 80K upgrade, 64K original; a change resets the computer |
| System | 80-column hardware | On, Off |
| System | Load firmware | `boot.rom` is loaded at start; another firmware file can be loaded |
| Ports & Controllers | Drive A to Drive D | 5.25 inch, 8 inch |
| Ports & Controllers | External parallel input | Off, On |
| Ports & Controllers | User port | GPIO 0-5, 6-11 |
| Audio & Video | Tape sound | On, Off |
| Audio & Video | Aspect ratio | Original, Full Screen, ARC1, ARC2 |
| Audio & Video | Scandoubler Fx | None, HQ2x, CRT 25%, CRT 50% |

## Tapes and disks

Drives take FM or MFM sectors in DSK/EDSK images; the form factor selects 300 or 360 RPM. Keep a copy of writable disk images before use.

F5 plays or pauses the tape, F6 selects the previous block, F7 the next block, F10 sends NMI and F11 resets. Tape files are limited to 256 KiB; use PZX/TZX conversion for long audio recordings.

## Ports and controllers

Software RS-232 uses MiSTer's UART pins. The User port routes six parallel/GPIO signals at a time. Consult [hardware and ports](hardware.md) for the register and pin assignments.

## Included files

`games/COBRA/` contains `boot.rom` and one folder for each model with a `demo` tape, its support files and a checksum manifest (`bundle.json`). [Provenance](provenance.md) identifies originals, family references and replacement software.

## Build

From `src/core-cobra/`, use `tools/build.ps1 assets`, `tools/build.ps1 test`, `tools/build.ps1 quartus`, then `tools/build.ps1 package`. Windows builds use WSL Debian; Linux can run `python3 tools/build.py` with the same actions.

Required tools: Python 3 with Pillow, Verilator, Icarus Verilog, Pasmo, Docker and the pinned toolchain images in `dependencies.lock.json`. The MiSTer framework is the pinned submodule of the HC core (`git submodule update --init`).

The firmware and demos come from the release's assets archive (`python tools/assets.py unpack`, from the repository's root). `tools/build.ps1 fetch` downloads optional original reference sources and verifies their hashes.

[Validation](validation.md) records the native firmware and FPGA checks.
