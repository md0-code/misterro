# COBRA hardware and ports

CoBra provides its native 8255, extended keyboard, serial and parallel interfaces, joystick, Z80 CTC and four-drive 8272 controller. Drives can be 5.25-inch or 8-inch, using FM or MFM sectors in DSK/EDSK images. The 80-column display modification is included.

| Address | Interface |
| --- | --- |
| xxFE input / output | 8255 keyboard, EAR, serial RX / port C |
| xx1F input | 8255 port B: joystick or external parallel data |
| xxDF output | 8255 mode and bit set/reset control |
| E3 / EB / F3 / FB | Z80 CTC channels 0-3 |
| F5 / FD | 8272 status / data, selected by A3 |

CPU: 3.5 MHz. The original 64K split-bank map and 80K independent video RAM are implemented. R7 switches the startup overlay; PC6 is latched when leaving it, selecting BASIC or CP/M. BASIC bank zero is write protected. The 64K model uses the fixed original 16 KiB BASIC EPROM; on the 80K firmware expansion, PC3 and PC7 select the system-ROM quarter during startup; PC3 later drives MIC, PC4 the speaker and PC7 serial TX.

The CTC counts byte requests through channels 0, 1 and 2 to produce terminal count. Channel 3 receives the frame pulse. IM2 vectors, nested priority and RETI are supported. The wider display uses PC5 and extends the Spectrum picture by 32 pixels on each side.

Each of the four disk units supports independent seek state and write protection. DSK tracks preserve sector sizes, IDs, deleted marks and stored CRC/status flags; FORMAT operates within the image's allocated track space. FM and MFM recording metadata are enforced. The form-factor setting selects 300 or 360 RPM rotation.

CTRL, PrintScreen, ScrollLock, Escape and F1-F4 use the native sixth keyboard input. TAB emits the factory EXTEND/P sequence. External parallel input uses GPIO0-7 for PB and GPIO8 for PA5 handshake; PC5 is available on GPIO5.

The raster uses nominal functional timings; the FPGA clock enables preserve the CPU and peripheral rates. Serial and GPIO signals are logical-level interfaces exposed by MiSTer; the core does not emulate analog voltage drivers.
