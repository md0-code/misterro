# AMIC provenance

Primary archive: https://www.z80-romania.ro/aMIC-95

The archived combined ROM equals its eight individual 2 KiB EPROM dumps byte for byte. Keyboard and bus interpretation were checked against the original books, schematic and the first-party emulator https://github.com/BDan/my-amic at c3d5834e71f819cf8e71a6465b714cd8da70ca9a.

`sources.lock.json` records asset sizes, SHA-256 values and origins; `bundles.json` maps them to the installed folders. `dependencies.lock.json` pins the shared MiSTer framework and build containers. Own demonstration software and replacement loaders carry their source beside the firmware. Original ROMs and recordings retain their original rights; new core and shared sources use GPL-3.0-or-later ([licence](../LICENSE)). Upstream files keep their original notices.

`boot.rom` includes reproducible compatibility repairs from `assets/roms/compatibility.py`: the RAM probe starts at 8000h and handles the 64K address wrap, and BASIC SAV/LOA call the archived cassette routines directly instead of the mismatched monitor argument entry points. The complete unmodified archive image is retained as `support/original.rom`.
