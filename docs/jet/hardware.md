# JET hardware and ports

JET provides its 48 KiB Spectrum-compatible memory map, keyboard, colour display with BRIGHT and FLASH, beeper, cassette input/output and Kempston joystick.

| Address | Interface |
| --- | --- |
| 0000-3FFF | Original JET ROM |
| 4000-FFFF | 48 KiB RAM |
| xxFE | Keyboard / EAR input; colour, MIC and beeper output |
| xx1F | Kempston joystick |

CPU: 3.5 MHz. Display: 256 x 192 bitmap and Spectrum attributes with BRIGHT/FLASH, within a nominal PAL raster. The source page supplies no JET-specific expansion schematic; this profile implements the documented Spectrum-compatible base interfaces.

The raster uses nominal functional timings; the FPGA clock enables preserve the CPU and peripheral rates.
