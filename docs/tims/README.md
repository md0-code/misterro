# TIMS for MiSTer

TIM-S and TIM-S Plus in one core. TIM-S provides its shadow RAM, 8255 keyboard/parallel interface, software serial port and cassette. Plus adds native 192 KiB paging, 64 KiB video RAM, hardware scroll and four display resolutions, two 8255s, 8253 timers, five 8251 serial channels, AY sound, two-drive 8272, Centronics output, network NMI and 4 MiB MICRONEXT memory. An SDRAM module of at least 32 MiB is required.

## Start

1. Extract `MiSTerRO-<version>-TIMS.zip` onto the MiSTer card, preserving paths.
2. Select **TIMS** under Computers.
3. Enter `LOAD ""`, then select the model's `demo.tap` in **Load tape**. On the 48K keyword keyboard, J enters LOAD; Shift plus the quote key enters a double quote. The program autostarts.
4. On Plus, choose +3 BASIC from the start menu.

## Options

| Menu | Option | Choices |
| --- | --- | --- |
| System | Model | TIM-S, TIM-S Plus; a change resets the computer |
| System | CPU switch | 3.5, 6, 7, 8 MHz |
| System | Load firmware | `boot.rom` is loaded at start; another firmware file can be loaded |
| Ports & Controllers | Printer | Virtual, Physical |
| Ports & Controllers | Flush printer | writes the pending printer job |
| Ports & Controllers | UART channel | Native, Expansion 1 to 4 |
| Ports & Controllers | User port | GPIO 0-5, 6-11, 12-17, 18-23, Network |
| Audio & Video | Tape sound | On, Off |
| Audio & Video | Aspect ratio | Original, Full Screen, ARC1, ARC2 |
| Audio & Video | Scandoubler Fx | None, HQ2x, CRT 25%, CRT 50% |

## Tapes and disks

The original Plus 2 KiB bootstrap EPROM is not archived. The bundled, labelled replacement uses the documented paging ports to start the unmodified English +3 v4.1 system in resident RAM.

For persistent printer output, mount `support/printer.prn` in **Printer job** and choose the **Virtual** printer. The job flushes automatically; **Flush printer** writes it at once. Extract the raw output with `python src/shared/romanian/tools/printer.py extract printer.prn --output printout.bin`. Mounting starts a new job, so extract output before reusing an image. Create another job with the same tool's `create` command.

F5 plays or pauses the tape, F6 selects the previous block, F7 the next block, F10 sends NMI and F11 resets. Tape files are limited to 256 KiB; use PZX/TZX conversion for long audio recordings.

## Ports and controllers

**UART channel** selects which of Plus's five serial interfaces is connected to MiSTer's UART pins. The User port routes one bank of six GPIO lines at a time, or the native network wire. Consult [hardware and ports](hardware.md) for the register and pin assignments.

## Included files

`games/TIMS/` contains `boot.rom` and one folder for each model with a `demo` tape, its support files and a checksum manifest (`bundle.json`). [Provenance](provenance.md) identifies originals, family references and replacement software.

## Build

From `src/core-tims/`, use `tools/build.ps1 assets`, `tools/build.ps1 test`, `tools/build.ps1 quartus`, then `tools/build.ps1 package`. Windows builds use WSL Debian; Linux can run `python3 tools/build.py` with the same actions.

Required tools: Python 3 with Pillow, Verilator, Icarus Verilog, Pasmo, Docker and the pinned toolchain images in `dependencies.lock.json`. The MiSTer framework is the pinned submodule of the HC core (`git submodule update --init`).

The firmware and demos come from the release's assets archive (`python tools/assets.py unpack`, from the repository's root). `tools/build.ps1 fetch` downloads optional original reference sources and verifies their hashes.

[Validation](validation.md) records the native firmware and FPGA checks.
