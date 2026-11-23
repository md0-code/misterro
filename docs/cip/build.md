# Build and validation

Run from `src/core-cip/` or its standalone source export. Linux/WSL needs Docker,
Verilator, Icarus Verilog, make, g++ and Python Pillow. GHDL and Quartus 17.0.2
Lite/Cyclone V Docker images are pinned in `dependencies.lock.json`. Compilation
is network-disabled and uses the original T80 VHDL.

Initialize the pinned submodule with `git submodule update --init --recursive`.
`python3 tools/prepare_assets.py --mp3 /path/to/CipBas.mp3` fetches/checks locked
assets and recovers BASIC using FFmpeg and independent thresholds. Standalone
exports already contain firmware, documents and the original MP3.

```powershell
./tools/build.ps1 lint
./tools/build.ps1 test
./tools/build.ps1 quartus
./tools/build.ps1 package
```

Linux uses `python3 tools/build.py` with the same arguments. The default target
is **CIP**, producing `build/quartus-CIP/output_files/CIP.rbf`.

`test` covers native CIP-01/02/03 startup, all 16,383 BASIC bytes received through
EAR, arithmetic, F11 recovery, live model and copier/resident switching, combined
firmware bounds and every CIP-04 ROM bank. Video tests compare two complete
rasters at three relative clock phases through the exact 112-to-56 MHz bridge.
The native CPU remains 3.5 MHz, video 7 MHz and cassette time 3.5 MHz. Long CPU
tests compress the master scheduler while preserving event ratios; independent
units retain full divider schedules. `sim --seconds N` runs the native family
path without the full suite; `lint` checks that path. Quartus compiles the entire
family wrapper, including the experimental CIP-04 CPU, AY and disk path.

`prepare_family.py` combines the native machine and locked +3 platform behind one
HPS interface and video mixer. Unexposed expansion modules are removed to fit
on-chip firmware, native RAM and the shared 256 KiB cassette buffer. Host uploads
write that dual-clock buffer at 112 MHz; the unchanged pulse engine reads at
56 MHz with a 3.5 MHz enable. Ready and controls are synchronized; mode, length
and file bytes settle before playback is released.

Native T80 internal state paths have a two-edge constraint because they commit
once per 32 system clocks. CPU bus outputs, enables, RAM and the cassette parser
retain their full clock timing requirements. Packaging rejects any negative
constrained slack or stale runtime/FPGA source hashes.

Fixed `--model CIP01/02/03/04` test and Quartus targets remain diagnostics.
`reference` checks an original-scheduler BASIC prefix. CIP-04 remains an
experimental 128 KiB +3 profile; native simulated success does not establish
its physical startup or the undocumented extra 128 KiB mapper.

`package` requires current family runtime and FPGA evidence, nonnegative
constrained timing and fresh source hashes. It emits exactly one `CIP.rbf`,
all model media, combined firmware, corresponding sources, licenses and checksums.
The exported source must reproduce generated FPGA inputs without Git metadata.
