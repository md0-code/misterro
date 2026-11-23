# Building and validation

Run from `src/core-hc/` or its standalone source export. Linux/WSL needs Docker,
Icarus Verilog, Verilator, make, g++, Pasmo and Python Pillow. Pinned GHDL and Quartus
17.0.2 Lite/Cyclone V images are in `dependencies.lock.json`. Docker builds
are network-disabled; Quartus uses the original T80 VHDL.

Initialize the submodules and run `python3 tools/fetch_sources.py` to obtain
locked assets and archival references. The source export already contains the
inputs needed to build and test. `tools/build_hc88_disk.py`
rebuilds the HC88 replacement disk from the locked CP/M sources and `software/`.
On Debian, install Pasmo with `apt-get install pasmo`.

```powershell
./tools/build.ps1 lint
./tools/build.ps1 test
./tools/build.ps1 quartus
./tools/build.ps1 package
```

Linux uses `python3 tools/build.py` with the same arguments. The default target
is **HC**, producing `build/quartus-HC/output_files/HC.rbf`.

`test` checks the three resident BASIC ROMs, keyboard arithmetic, F11 recovery, live
transitions 85 -> 90 -> 91 -> 85, arithmetic after switching, firmware bounds
and retention across all six selectors, model-specific bus decoding/clock behavior, BRIGHT/FLASH and
tape controls. It also runs the HC88 original-ROM disk, CP/M file read/write,
512-pixel video/sound, runtime BASIC, EAR cassette and F11 tests, plus independent
80 KiB memory/paging and 256/512-pixel serializer checks. Expansion checks cover
HC128 banking, screen isolation, optional AY, configuration locks, Interface 1
entry/exit, UART, network WAIT, joystick, two-drive read/write/format, protection
and track bounds. Native ROM runs exercise HC85 DOS format/SAVE/LOAD, HC128
BASIC, HC90/91/128 original CP/M disks and HC2000 file creation plus drive B.
The tape test reads every supported byte and checks TZX stop48 in both modes.
Receipts are tied to source hashes. `sim --seconds N` runs the
family simulation without the full suite; `lint` checks the family machine.

Fixed `--model HC85`, `HC90`, `HC91` targets remain diagnostic options.
`test --model HC90 --tape assets/tapes/hc90/serpenti.tzx --seconds 16` checks
that original tape bootstrap through EAR. `tools/test_tapes.py` runs the three
isolated cassette diagnostics. Full large demo completion and original gate
timing comparison remain separate gates.

`package` requires current family runtime and FPGA receipts, fresh source hashes
and nonnegative constrained slack. It exports exactly one `HC.rbf`, all model
media, combined firmware, corresponding sources, licenses and SHA256SUMS. Its
source-export check reproduces generated FPGA inputs, the lossless 64 KiB
firmware, compatibility entry, HC85 blank disk and HC88 replacement disk without
Git metadata or downloads.
External framework I/O paths retain their upstream constraints.
