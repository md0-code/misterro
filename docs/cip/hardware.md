# Hardware implementation

The source references are the [CIP-01 archive](https://www.z80-romania.ro/CIP_01-34),
the Electronica AX1587/AX1632 four-sheet circuit diagram and the 1989 user manual.
Original downloads are kept outside Git under `docs/reference/`; their checksums
and URLs are recorded in `sources.lock.json`.

## Memory and bootstrap

The 2716 EPROM contains 2,048 bytes. A0-A10 select its contents, mirrored across
the bottom 16 KiB while the boot latch selects EPROM. RAM covers all 64 KiB;
writes beneath the EPROM reach RAM without changing the bootstrap.

Sheet 1 IC35 decodes I/O with A0 low and A6 high. A4 selects the normal FE
keyboard/cassette/border/audio interface or the EE boot latch. IC37A stores D0;
its complementary output selects EPROM when D0=0, RAM when D0=1. Upper address
bits are not decoded. The original monitor uses OUT EE to execute its tape
reader from RAM and eventually launch the interpreter loaded at address zero.
The IC26 PROM dump corroborates the low-memory EPROM/RAM read selection and RAM
writes; external ROM/video inhibit expansion lines are held in their base-machine state.

The power-up signal resets the boot latch, independently of the CPU's RESET
button. The machine module models both controls separately and preserves RAM.
The supplied BASIC writes temporary floating-point values over its first five
startup bytes during PRINT. A raw CPU reset can consequently execute a damaged
entry sequence. MiSTer F11/button/OSD reset therefore also resets the boot latch,
returning reliably to the monitor. Load BASIC again after resetting.

## Clocks and video

Sheet 2 IC20 divides the 14 MHz crystal by four for the 3.5 MHz Z80 clock.
Unlike HC-85, this clock is continuous. The core derives that clock and the
7 MHz pixel enable from the pinned 56 MHz MiSTer PLL. Dual-port FPGA RAM models
the interleaved CPU/display accesses.

The display uses the Spectrum bitmap/attribute layout, 256 by 192 active pixels,
a nominal 448 by 312 PAL envelope and frame interrupt. Sheet 3 routes ATTR6 to
BRIGHT and ATTR7 to FLASH. Digital RGB uses levels 205 and 255; the original PAL
analogue encoder and component tolerances are not synthesized. Raster/interrupt
edge placement still requires comparison with physical CIP measurements.

## Cassette and input

The original ROM executes all tape-reading code. The tape player produces EAR
pulses in real time; it has no CPU trap, instantaneous byte transfer or BASIC
memory preload. Its clock continues while CPU RESET is asserted. Buffering is
limited to 256 KiB, with oversized files rejected rather than wrapped.

`CipBas.mp3` decodes into a CODE header and a 16,383-byte payload starting at
zero. Four Schmitt thresholds independently recover identical blocks with
valid XOR checksums. `prepare_assets.py` regenerates standard-speed TZX blocks
from those bytes. MP3 noise and pulse jitter are removed; interpreter bytes
remain identical. `audio-conversion.json` records this evidence. The extracted
payload in `build/expected-basic.bin` is a test oracle only and is never loaded
into the FPGA or a simulation memory array.

PS/2 keyboard events feed an active-low 8 by 5 matrix. FE bit 6 reads EAR;
bits 0-2 select border, bit 3 MIC and bit 4 the speaker. MIC is mixed into audio
so SAVE waveforms can be recorded from MiSTer audio output. Physical tape input
through the ADC is not part of this file-based cassette interface.
