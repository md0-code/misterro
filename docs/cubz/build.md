# Build CUBZ

Run tools from `src/core-cubz` in the repository or from the exported
`source` directory. Python locates component documentation in either layout.

1. `python3 tools/fetch_sources.py` downloads checksum-locked originals.
2. `python3 tools/prepare_assets.py` reproduces and verifies firmware layouts.
3. `python3 tools/test_units.py` checks keyboard and DMA interfaces.
4. `python3 tools/test_runtime.py` builds the real T80 simulator and checks native software.
5. `python3 tools/compile.py` compiles the MiSTer bitstream and validates timing.
6. `python3 tools/package.py` creates and verifies `dist/CUBZ.zip`.

Simulation requires Verilator, Icarus, a C++ compiler and Docker. FPGA building
uses the pinned Quartus container. The original T80 VHDL is synthesized by
GHDL only for simulation; Quartus builds the original VHDL directly. Compilation
runs on Linux temporary storage and returns full reports under `build/`.

Dependencies and toolchain images are pinned in `dependencies.lock.json`.
The framework submodule is `src/core-cubz/vendor/spectrum`; the standalone
export includes its corresponding RTL/framework files. Runtime and FPGA
receipts include source hashes. Packaging rejects stale receipts or failing
constrained timing. Downloaded originals and generated outputs stay ignored.
