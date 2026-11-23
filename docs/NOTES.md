# Notes

## Files on the card

Each archive is extracted onto the MiSTer card (`/media/fat`), preserving paths. It puts there the core
(`_Computer/<CORE>.rbf`), the machine's files (`games/<CORE>/`) and the documentation (`docs/MiSTerRO/`, the same in every
archive).

`games/<CORE>/boot.rom` is the firmware the core loads when it starts: for a core with several models, all their
firmware in one file. **Load firmware** in the System menu takes this file; the copies in the model folders are there
for reference. A core with one model has its files directly in `games/<CORE>/`, a core with several has a folder for
each model:

| File | |
|---|---|
| `boot.rom` | The model's own firmware |
| `demo.tzx`, `demo.tap`, `demo.pzx`, `demo.dsk`, `demo.img` | One demo, on tape or disk |
| `support/` | What else the model needs: system disks, blank disks, interface ROMs, the unmodified ROM where the default is repaired |
| `bundle.json` | Every file with its size, SHA-256 and origin |

| Core | Folders | Besides the firmware and the demo |
|---|---|---|
| HC | `HC85`, `HC88`, `HC90`, `HC91`, `HC128`, `HC2000` | The Interface 1 ROMs, a blank disk for the HC-85, the HC-91 CP/M disks, the HC-2000 system, demo and external-drive disks, the HC-88 system disk |
| CIP | `CIP01` to `CIP04` | `basic.tzx`, the BASIC the CIP-01 and the CIP-02 in copier mode load from tape |
| TIMS | `TIMS`, `TIMSPLUS` | A blank 720K disk, the Plus bootstrap and system ROMs, a printer job file |
| COBRA | `COBRA64`, `COBRA80` | The bootstrap ROMs and, for the 80K, the 80-column CP/M system disk |
| JET | | |
| CUBZ | | Monitor 1.3 (`firmware-v13.rom`), the keyboard and video timing PROMs |
| AMIC | | The unmodified ROM (`support/original.rom`) |
| PRAE | `PRAE36`, `PRAE35` | |
| JUNIORXT | | BIOS 3.0, 5.0 and 5.0-alt (`bios/`), the manual disk (`manual.img`), the character ROM |

Every archive also puts the M-CRT video preset in `Filters/`, `Gamma/` and `Presets/`.

## Firmware and media

The firmware is the machines' own, preserved by the [z80-romania.ro](https://www.z80-romania.ro/) archive and the other
sources each core's `provenance.md` and `sources.lock.json` name. What is not original is labelled in `bundle.json`:

- **aMIC**: `boot.rom` is the archived ROM with two faults repaired (the RAM probe and the entry points of the cassette
  routines BASIC calls); `support/original.rom` is the archived image.
- **TIM-S Plus**: its bootstrap EPROM is not archived. A replacement of the project's own starts the unmodified
  Spectrum +3 system ROMs.
- **HC-88**: the 2 KiB bootstrap is original; the CP/M system disk it boots is a replacement built from CP/M 2.2 and a
  BIOS of the project's own, with a launcher for the HC family's BASIC.
- **HC-90, HC-91, HC-91 Plus**: CP/M starts through a compatibility entry and the unchanged HC-2000 BIOS.
- **JUNIOR-XT**: the demo disk is FreeDOS with the project's own test programs; the manual disk is MezinXT's, a booter
  with the text of the 1989 technical manual.
- **Demos**: the HC and CIP demos are the manufacturers' cassettes; the HC-88, HC-128 and HC-2000 folders hold the
  cassette of a related model, labelled so. The JET, TIM-S and CoBra tape demos and the aMIC and PRAE ones are the
  project's own short BASIC programs, the latter two saved by the machines' own cassette routines.

Tape files of up to 256 KiB are accepted (TAP, TZX, PZX, CSW v1 on the HC and CIP; see each guide).

No manuals or schematics come with the cores. The z80-romania.ro archive holds the scans; the HC, CIP, CUB Z and
JUNIOR-XT tools download the ones the cores were built from into `docs/<family>/reference/`.

## Limitations

- Every core has been run on a MiSTer (DE10-Nano). None has been compared against the original machine with
  instruments: raster, interrupt and memory-contention timing follow the documents, not measurements.
- **CIP-02**: how the real machine selects its ROMs is not established; the **CIP-02 startup** option is a way to reach
  both of its modes, not a model of a switch.
- **CIP-04**: experimental. It runs its original ROMs on a Spectrum +3 memory map; the mapper of its extra 128 KiB is
  not known and not built.
- **CUB Z**: the IEEE-488 controller of the GPZ board is not built (the manual gives no register addresses).
- **JUNIOR-XT**: the 8087, the light pen, a third and fourth diskette drive, 8-inch drives, synchronous serial modes
  and the tape and instrumentation couplers are not built. The printer ports accept data but nothing prints.
- **JET**: no document specific to the JET is archived; the core is the Spectrum-compatible machine its ROM expects.
- **PRAE-M**: no floppy interface (the manual describes it as a future version).
- **Serial, parallel and network lines** come out as 3.3 V logic signals of the FPGA on MiSTer's UART and User port
  pins: a level adapter is needed for RS-232 and for the machines' own wiring.
- **M-CRT**: curvature, overscan, vignette, rounded corners and the monochrome modes of the shader it follows cannot be
  done by MiSTer's video pipeline.
