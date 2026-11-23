# CUB Z validation

## Native software gate

The release gate passes with the original T80 CPU and unmodified archived
software. The main run transfers 65,536 bytes through DMA with 278 SD reads
and three writes; the independent reboot/deletion run transfers 20,992 bytes
with 88 reads and one write. Neither run overflows the keyboard FIFO.
It requires all of these checks before writing `build/runtime-validation.json`:

- v1.3 and v1.4 monitor startup and keyboard echo through the serial protocol.
- Original boot-sector bytes copied into physical RAM through 8272/8257 DMA.
- Original 57K CP/M 2.2/4 startup from the bundled EDSK image.
- Turbo Pascal 3.00A loading, its native menu, keyboard input and exit to CP/M.
- CP/M directory listing, `SAVE 1 CUBZTEST.COM` and the created file's listing.
- An independent reboot of the modified image, finding that saved file,
  deleting it with ERA, and receiving the subsequent no-file result.
- Serial framing and native key repeat, DMA ownership/count/terminal count,
  CTC timer/IM2 vectors/priority/RETI, and full raster/scroll checks.

Only test copies of the disk are changed. The original demo's SHA-256 remains
`7ea2239733f01cbe70c4341fe40fc2600ff99128c33f5d8000582cb32d475d8a`.
The runtime receipt binds the tested RTL and harness hashes; packaging rejects
stale runtime or FPGA receipts. Terminal-control bytes are retained in raw
console captures; a second transcript removes terminal escape sequences for
text assertions. No firmware traps, CPU patches or RAM preloads are used.

## FPGA qualification

Quartus Prime Lite 17.0.2 completes synthesis, placement, routing and assembly
for the DE10-Nano. The 40 MHz machine clock supplies a 2.5 MHz Z80 and 10 MHz
pixel enables. All constrained setup, hold, recovery, removal and pulse-width
checks pass, with minimum slack **0.251 ns**.

The design uses 11,674 of 41,910 ALMs (28%), 1,445,477 block-memory bits (26%)
and 197 of 553 RAM blocks. External SDRAM is not required.

CUBZ.rbf SHA-256:
`15127cc5fb7c5d1cb63cdd466bb73934fe504c9079555f08596de074f39aadb6`.

The FDC rotation-period divider is an exact constant lookup. The machine PLL
uses the pinned framework's expected hierarchy, preserving its existing clock
groups. The timing gate is not bypassed by broad new exceptions.

## Captures and hardware testing

These are native bitmap captures from the RTL simulation, displayed at 4:3:

- [v1.3 monitor](images/monitor-v13.png)
- [v1.4 monitor](images/monitor-v14.png)
- [Turbo Pascal](images/turbo.png)
- [CP/M and saved-file listing](images/cpm.png)

The core has been run on a physical MiSTer (DE10-Nano): select CUBZ and mount
the demo disk.
