# Hardware reference

The HC-85 target is the unexpanded HC-85 represented by ICE Felix drawing
869.400.001, ten sheets, in the 1987 revised technical manual. The local PDF
page number is one greater than its printed sheet number.

| Circuit | Source | Implementation |
| --- | --- | --- |
| Z80A and memory strobes | sheet 1; manual 4.2 | Pinned MiSTer T80pa, both clock enables |
| 16 KiB ROM, eight 2716 chips | sheet 2; manual 4.3 | Writable on-chip ROM bank, protected from CPU writes |
| 32 KiB additional RAM | sheet 3; manual 4.5 | Independent upper RAM bank at 8000-FFFF |
| 16 KiB video/program RAM | sheet 4; manual 4.4 | Shared bank at 4000-7FFF, separate video read port |
| Sync and access arbitration | sheets 5-6; manual 4.4-4.6 | Raster generator and CPU clock enable arbitration |
| Bitmap, ink, paper, FLASH | sheet 7; manual 4.6 | Serial display pipeline, 8x8 attributes |
| Keyboard, two joysticks, cassette, bell | sheet 8; manual 4.7-4.8 | Matrix keyboard, Sinclair sockets, EAR pulse playback, bit 4 beeper |
| PAL coder and power | sheets 9-10 | Digital RGB and audio use MiSTer platform outputs |

## Established circuit details

- Address map: 0000-3FFF ROM, 4000-7FFF shared RAM, 8000-FFFF additional RAM.
- Attribute bit 6 has no display connection. BRIGHT therefore has no visual effect.
- The keyboard/cassette port requires A0=0 and A6=1, not just an even address.
- Video RAM arbitration stops the processor clock. WAIT remains inactive.
- The cassette clock must continue during processor contention.
- Both Sinclair joystick sockets share the keyboard matrix.
- The master oscillator is 14 MHz. The implementation uses a 56 MHz FPGA
  clock with enables; no combinationally generated FPGA clocks are used.

## Timing status

The initial implementation uses a 448-pixel, 312-line PAL envelope and
half-slot video RAM arbitration. These are working bring-up parameters, not
yet a gate-level transcription of the D5/D4/D3/E3 counter reloads or B4/A3
arbitration circuit. Interrupt placement, fetch phase, and border alignment
must be reconciled with those gates before cycle-accuracy is claimed.

Simulation and operation on a physical MiSTer establish original-ROM operation,
keyboard input, cassette loading, and functional display output. Traces from an
original HC-85 are required for final electrical and timing validation.

## Reference material

`reference/hc85/`, `reference/hc90/` and `reference/hc91/` contain the original manuals and schematic scans.
The HC-90/91 circuit differences are documented in [models.md](models.md).
HC91 Plus paging, HC2000 configuration and the disk/serial/network expansion
boards are described in [interfaces.md](interfaces.md), with original source
identities and model-specific register layouts.
The independent HC-88 disk computer and its drawing 869.300.350 are described
in [hc88.md](hc88.md).
`sources.lock.json` records their source URLs and SHA-256 hashes, plus the
ROM and demonstration tapes. Run `tools/fetch_sources.py` to restore them.
The ROM is checked against MAME's HC-85 SHA-1:
`a4189db0bcdf8b39ed782b398828efb408fc4817`.
