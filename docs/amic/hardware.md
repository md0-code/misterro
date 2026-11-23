# AMIC hardware and ports

aMIC exposes its keyboard and cassette PPI, an asynchronous 8251 serial port, and a second 8255 for parallel peripherals or a joystick. RAM configurations are selectable; the default is 32 KiB.

| Address | Interface |
| --- | --- |
| 0000-3FFF | Original monitor/BASIC ROM |
| 4000-5FFF | Linear 256 x 256 monochrome bitmap |
| 4000-7FFF / BFFF / FFFF | 16 / 32 / 48 KiB RAM configurations |
| 00 / 01 | 8251 data / status and command |
| 20-23 | Keyboard 8255 A, B, C, control |
| 40-43 | External 8255 A, B, C, control |

CPU: 2.5 MHz. Keyboard PC0-2 selects a row; PB5 SHIFT, PB6 CTRL, PB7 CAPS. PB0 is cassette input; PC7 is cassette output, PC3 the speaker and PC5 video inversion. The serial baud switch provides 1200, 600 or 300 baud with the firmware's x16 mode. The second PPI is exposed through GPIO0-23; joystick buttons pull its low five inputs down.

The raster uses nominal functional timings; the FPGA clock enables preserve the CPU and peripheral rates. Serial and GPIO signals are logical-level interfaces exposed by MiSTer; the core does not emulate analog voltage drivers.

MiSTer's UART bridge connects RX/TX, independent CTS/RTS and DSR/DTR. Modem pins use their active-low electrical convention; the core converts CTS and DSR into logical asserted inputs for each 8251. Unselected Plus channels are disconnected and report no external modem readiness. The native Z80 diagnostics loop RTS into CTS and DTR into DSR as well as TX into RX.
