# JUNIOR-XT validation

Verified 2026-11-12 against the pinned sources and original V4 firmware.

## Native execution

Two independent cold starts execute the real 8086, chipset, PIC/PIT, keyboard,
CGA and floppy/DMA logic. External RAM and disk media are supplied by the test
host; BIOS services and CPU instructions are executed by RTL. Runtime acceptance
uses the Max CPU setting; the memory integration regression also covers all
three fixed clock selections.

- Original unmodified V4 POST detects 640 KiB and passes interrupt, timer,
  keyboard and floppy checks; both runs boot the bundled FreeDOS disk.
- Keyboard-driven DOS commands create and read a file. A fresh cold start from
  the modified image reads the same contents, deletes the file and verifies
  its absence.
- The original BIOS INT 14h initializes the native SIO at 9600 baud and passes
  a transmit/receive loopback.
- The native CGA raster is captured in text, 320x200 colour and 640x200 mono.
  Graphics memory is checked byte for byte; captures contain four and two
  colours respectively.
- The speaker test produces 448 gated PIT transitions and returns to DOS.
- With the monochrome coupler, 256 KiB and the PC serial board selected, the POST
  passes its display test, counts 256 KiB and boots FreeDOS on the monochrome
  text store.
- With the Winchester coupler on and no diskette, the Winchester ROM reports
  615 cylinders, 4 heads and 17 sectors for a 20 MB image and boots its master
  boot record; a sector written through INT 13h at cylinder 300, head 2,
  sector 9 is read back and found at LBA 20442 of the image
  (`tools/test_winchester.py`).
- The manual disk loads its nine-sector tracks under the V4 diskette table and
  shows its opening picture.

Runtime proof: `src/core-juniorxt/build/runtime-validation.json`, also included as
`docs/runtime-validation.json` in the release ZIP. It binds the hardware,
verification sources, original BIOS, disk and both run logs by SHA-256.

BIOS SHA-256 (the first 64 KiB of `boot.rom`): `d9edcd90a2c279adf2dd2c4a481fdc75ca24decc84bd96d66597fb1a40a0b27f`.
Demo SHA-256: `3fe8efc628f103d9f101a0b7326e74f109a969b1105fe8ca7acfa58865445fb2`.

Native captures: [text](images/demo-text.png),
[colour](images/demo-color.png), [monochrome](images/demo-mono.png).

## Circuit regressions

- Native 640 KiB map, 32 KiB CGA without a 16 KiB mirror, open expansion
  windows, the C8000 socket, the 256 KiB limit and firmware write protection pass.
- SDRAM command/pin model: 30,034 operations, 51,143 words read, 25,432 writes,
  256 refreshes and zero protocol errors.
- 8086-to-SDRAM integration passes at 4.77, 7.16, 9.54 MHz and Max, with matching
  reference checksums, zero chip errors and zero video underruns.
- Serial regression passes both channels, baud timing, buffered transmit,
  receive FIFO/overrun, register selection, the native BIOS probe, interrupt
  vectors, acknowledgement and in-service handling.

The demo image reproduces byte for byte from a separate source copy. The
source programs are assembled for the original 8086 instruction set.

## FPGA signoff

Quartus Prime 17.0.2 Lite successfully synthesizes and fits the complete
MiSTer wrapper for Cyclone V 5CSEBA6U23I7. All constrained setup, hold,
recovery, removal and pulse-width corners pass; minimum slack is
0.077 ns.

Fitting targets an extra 0.25 ns of internal CPU/SDRAM setup headroom. A
separate signoff checks the fitted netlist against the unchanged baseline
SDC requirements. Both constraint sets, the timing summary and artifact
hashes accompany the release. The bitstream remains identical during signoff.

Logic use is 46%; block-memory use is 20%. The original character ROM and
CPU microcode are present in the synthesis report. FPGA and native runtime
proofs bind the same hardware-source hashes.

RBF SHA-256: `a927809288a7d8d3bdb1737919528237f40be5a00b2f6c8a5541d02151570f55`.

The fixed disk is checked against a model of MiSTer's ATA service; the game
adapter, serial mouse, CGA monitors and the start-up screen have not been
exercised on a MiSTer.

Release evidence is under `docs/` in the ZIP: `fpga-validation.json`,
`fpga-signoff.json`, `fpga-timing.summary`, fitting/signoff QSF files,
`hardware-validation.json`, `serial-test.log` and both `native-*.log` files.
