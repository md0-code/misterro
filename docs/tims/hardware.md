# TIMS hardware and ports

TIM-S provides its shadow RAM, 8255 keyboard/parallel interface, software serial port and cassette. Plus adds native 192 KiB paging, 64 KiB video RAM, hardware scroll and four display resolutions, two 8255s, 8253 timers, five 8251 serial channels, AY sound, two-drive 8272, Centronics output, network NMI and 4 MiB MICRONEXT memory.

| Address | TIM-S |
| --- | --- |
| E0 / E2 / E4 / E6 | 8255 A / B / C / control |
| FE / F9 input | Keyboard PPI alias |
| F0 output | Disable the startup ROM overlay |
| FE output | Spectrum colour, cassette and beeper |

Standard mode has 64 KiB shadow RAM and a 16 KiB startup ROM. PC1 protects lower RAM, PC2 inhibits video writes, PC3 selects the auxiliary CPU clock, PC4 enables RAM, PC0 transmits serial data. PA5 is serial READY, PA6 EAR and PA7 printer BUSY. PB0-6 carry printer data and PB7 is its strobe.

| Address | TIM-S Plus |
| --- | --- |
| 0CFD / 0DFD / 0EFD / 0FFD | PPI1 C / control / A / B |
| 5CFD / 5DFD / 5EFD / 5FFD | PPI2 A / B / C / control |
| 7FFD / 1FFD | Native Spectrum / CP/M paging, motor and printer strobe |
| 9CFD-9FFD | Base 8253, including serial and FLASH clocks |
| 8CFD-8FFD | Expansion serial-clock 8253 |
| DEFD / DFFD | Base 8251 data / status and command |
| AFFD | Serial-multiplexer control |
| CFFD / EFFD | Selected expansion 8251 data / status and command |
| 2FFD / 3FFD | 8272 status / data, two drives |
| BFFD / FFFD | AY data / address and readback |
| xx0F / xx1F / xx2F / xx3F | MICRONEXT address low / middle / high / data |
| xxF7 / xxF3 | Network data / arm synchronization NMI |

Plus has twelve 16 KiB RAM banks, including four resident system banks, and eight 8 KiB video pages. The CPU uses an acknowledged external SDRAM bus, including all MICRONEXT accesses. The 2 KiB startup EPROM overlays low addresses until PC0 changes; resident system banks are restored from a separate firmware cache on reset.

The display supports 256/320/512/640 by 192 pixels, interleaved video pages, hardware vertical scroll and attribute inhibition. Native control signals select the 3.5 MHz base clock or the configured 6/7/8 MHz auxiliary clock. A positive physical network SCOUT pulse generates NMI after F3 has armed reception, including when the CPU is halted.

The MiSTer virtual printer stores raw bytes and a committed byte count in an allocated PRN image. Full sectors and partial jobs persist, with write protection, capacity checks and backpressure. The User port can alternatively connect physical GPIO and BUSY/ACK signals.

The raster uses nominal functional timings; the FPGA clock enables preserve the CPU and peripheral rates. Serial and GPIO signals are logical-level interfaces exposed by MiSTer; the core does not emulate analog voltage drivers.

MiSTer's UART bridge connects RX/TX, independent CTS/RTS and DSR/DTR. Modem pins use their active-low electrical convention; the core converts CTS and DSR into logical asserted inputs for each 8251. Unselected Plus channels are disconnected and report no external modem readiness. The native Z80 diagnostics loop RTS into CTS and DTR into DSR as well as TX into RX.
