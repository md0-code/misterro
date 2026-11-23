# Validation

`build/family-validation.json` records the single CIP core's runtime checks and
source hashes. The actual T80, original firmware, PS/2 keyboard and pulse player
verify native CIP-01/02/03 startup, keyboard arithmetic, F11 recovery, resident
model changes and CIP-02 copier/resident switching. CIP-01 receives and byte-matches
all 16,383 original BASIC bytes through EAR before executing `PRINT 2+2`.

Independent units cover RAM beneath ROM, 2 KiB mirroring, EE selection, FE/A6
I/O, keyboard/audio, reset, clock schedules, BRIGHT/FLASH and tape controls.
The exact output bridge is compared with two native rasters at three 112/56 MHz
phases, including positive mixer sync, blanking, RGB and every pixel event.
Controller tests reject short/oversized firmware, retain it on switches and
read every original CIP-04 ROM bank.

`build/cip-fpga-validation.json` requires successful synthesis/fitting, current
source hashes, a fresh bitstream and nonnegative constrained slack. Native T80
internal state paths have a justified two-edge constraint: state commits once
per 32 system clocks. Inputs, bus outputs and enables remain single-edge.
The cassette engine runs at 56 MHz with a 3.5 MHz timing enable and a dual-clock buffer
written at 112 MHz. Independent tests cover uploads, autoplay, EAR pulses,
pause/resume, navigation and overflow across both clocks. All cassette-parser
and byte-handshake paths retain full clock timing requirements. Framework
external I/O retains upstream constraints.

Packaging checks ZIP CRC, all SHA256SUMS entries, one family bitstream, complete
model media and combined firmware, and reproduction of FPGA inputs from the
standalone source export.

Physical native startup/tape loading and original-board timing comparison are
separate gates. CIP-02 remains a firmware profile with undocumented physical
ROM selection. CIP-04 remains experimental: original ROM banks and the +3 paging
interface are retained, but full CPU/AY/disk operation needs physical testing and
the extra 128 KiB mapper still requires technical evidence.

## Family FPGA build

Minimum constrained slack: 0.206 ns. The core has been run on a physical MiSTer (DE10-Nano).

Bitstream SHA-256: `75ae8386a8d5b70857ffd820177dabc48759870610b267381ea23758955e27d4`.
