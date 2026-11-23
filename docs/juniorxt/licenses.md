# Licences and provenance

The core derives from PCXT MiSTer under GNU GPL version 3, with component
licences retained in the complete source export. MCL86 carries its MIT licence;
the floppy controller and supporting FIFOs carry their original BSD notices.
The new Junior RTL and software sources use GPL-3.0-or-later.

The original Junior ROM dumps, manual and schematic scans are credited to
FEPER and preserved from the z80-romania.ro archive. Their exact source URLs,
sizes and hashes are recorded in `sources.lock.json`.

The demo disk derives from [Joris van Rantwijk's FreeDOS PC/XT boot floppy](https://jorisvr.nl/article/freedos),
based on FreeDOS 1.0 and Eric Auer's distribution. Its FreeDOS kernel 2036,
FreeCOM shell, FORMAT and CHKDSK retain their original copyright notices.
FreeDOS components are GPL software. Original kernel 2036, FreeCOM 0.82 pl 3,
FORMAT and CHKDSK source archives are in the release's assets archive, under
`docs/juniorxt/reference/`; their URLs and checksums are recorded in
[software sources](software-sources.lock.json). The original notices and build
instructions remain inside each archive.
The project's demonstration and serial test programs are supplied with source.

The Winchester ROM (`software/hdrom.asm`), its assembler (`tools/asm86.py`) and
the manual disk (`software/manual.img`) come from the MezinXT emulator, the same
author's GPL-3.0-or-later project. The manual disk carries the text of FEPER's
1989 technical manual.
