# CUB Z hardware and firmware

Primary evidence is the [CUB Z archive](https://www.z80-romania.ro/CUB_Z-173),
the bundled 1989 technical manual, original circuit drawings and EPROM dumps.
The archived VDT-52S conversion notes corroborate the EPROM order but are not
substituted for the CUB Z manual or circuit drawing.

## Memory and boot

| CPU address | Normal mapping |
|---|---|
| 0000-E7FF | System RAM |
| 8000-BFFF, PIO B2=1 | Separate 16 KiB bitmap RAM |
| E800-EFFF, PIO B3=1 | U6.2 EPROM |
| F000-F7FF, PIO B3=1 | U7.4 EPROM |
| F800-FFFF, PIO B3=1 | U7.2 EPROM |

The unpopulated U6.4 position leaves E000-E7FF as RAM for the stack, font copy
and monitor workspace. Reset aliases U7.2 across the CPU address space. Its
`JP F83F` runs the native initialization; `OUT (B0),A` releases the alias.
Normal ROM writes are inhibited. DMA accesses all 64 KiB of physical system
RAM, bypassing the CPU ROM and bitmap overlays. FPGA system RAM uses two
write-through M10K ports. Mixed-port read values during the other owner's
write are unused; BUSACK excludes simultaneous writes. Simulation-only peek
ports do not add FPGA RAM ports.

Bundled 8 KiB firmware follows the documented replacement layout: `C3 3F F8`,
2045 FF bytes, U6.2, U7.4, U7.2. The initial 2 KiB is not mapped over workspace
RAM during normal operation. Neither original EPROM nor CP/M code is patched.

v1.4 F83F configures PIO-B mode 3 and direction mask 60, writes output 09,
checks its readback, releases the alias and jumps E810. Initialization tests
RAM up to E800 and copies 95 printable character patterns from ROM into RAM
E3B6. Characters and graphics are drawn by the original CPU software.

## Video and keyboard

Manual pp. 23-25 and main-board sheets 8-14 describe the independent 10 MHz
dot clock, 64 microsecond lines, approximately 20 ms frames and 512 x 256
bitmap. CPU VRAM addressing is column-major: `{byte_column[5:0],line[7:0]}`.
F2 supplies the vertical scroll offset. PIO-B0 enables display, B1 drives
the beeper, B2 selects bitmap RAM and B3 enables ROM. CPU VRAM cycles use WAIT
in the P2 display half of each eight-dot access window; DMA continues to use
system RAM.

The FPGA emits 640 dots x 313 lines and normalizes the original PROM's long
15.2 microsecond horizontal sync to a conventional 4.8 microsecond pulse
inside blanking for MiSTer video output. Pixel data remains the native bitmap.
Original horizontal/vertical PROMs are included as checksum-locked references.

PIO-B5 reports keyboard busy, B6 reads serial data and B7 interrogates the
open-collector link. The receiver sends a zero start response and eight LSB
first data responses. It remains idle high otherwise. A key enters a 32-byte
FIFO and asserts busy for 100 microseconds. Held keys repeat at 10 Hz after
a 400 ms delay; duplicate host repeat events are suppressed. The original EBD8 firmware routine
performs all nine interrogations; there is no direct ASCII input port.

## I/O and floppy DMA

| Low port range | Function |
|---|---|
| 80-8F | Intel 8257 DMA registers |
| 90 / 91 | Intel 8272 main status / data |
| A0-A3 | GPZ board Z80 PIO: A data, A control, B data, B control |
| B0 | Boot-alias release; absent switches read high |
| C0-C3 | PIO data/control; native keyboard and video signals |
| D0-D3 | CTC counters |
| E0-E3 | Z80 SIO: A data, A control, B data, B control |
| F2 / F3 | Scroll / floppy option latch |

Channel 2 uses 84 address, 85 count/type and 88 mode/status. Address and count
are low byte then high byte; count is N-1 with two transfer-type bits. For
example the monitor programs 3000, 47FF, mode 64 to read 2048 bytes. BUSRQ and
BUSACK transfer ownership from the real T80 CPU, rather than substituting
host-side disk loads. Terminal count accompanies the final I/O strobe and is latched when the
FDC accepts that byte, before its end-of-sector decision. It ends the 8272
command successfully even
when the original monitor's EOT=26 exceeds the mounted disk's nine sectors.

`cubz_u765.sv` derives from the pinned Spectrum FDC. Changes add DRQ, terminal
count and interrupt outputs, preserve DMA CPU-status semantics throughout
execution and track reloads, and make timer widths explicit for the 8 MHz enable domain.
Rotation periods use an exact constant lookup for all 255 sector counts,
avoiding a hardware divider without changing the controller timing.
The engine keeps its normal internal RQM handshake for DMA; the CPU sees RQM,
DIO and EXM clear until result phase. This prevents polling firmware from
consuming bytes reserved for DMA. The vendor checkout is unchanged.

Main board I/O decode is qualified by IORQ, M1 and AEN. Disk-controller sheet
1 shows the optional K1/K2 connection from FDC INT to NMI. It is open here,
matching the polling monitor and supplied BIOS. Two image slots represent
the first two physical drives. Original EDSK geometry, track/sector status
and weak-sector copies are preserved; no disk-format conversion is needed.

The Z80 SIO (U2.2) provides the two asynchronous lines of the manual: channel A
with modem signals on MiSTer's UART pins, channel B (the serial printer line) on
the User port. CTC channel 0 clocks channel A and channel 1 channel B, as CLK0/CLK2
and CLK1 do on the board. Its interrupts follow the CTC in the daisy chain, with
the status-affected vector of channel B's WR2 and release by RETI. Synchronous
modes are not implemented.

The GPZ board's user Z80 PIO answers at A0-A3 in modes 0, 1, 2 and 3; port A bits
0-6 reach the User port, port B and the handshake lines are not connected and its
interrupt is not wired. The board's IEEE-488 controller (8291, 8292, 8293) has no
documented addresses in the manual's port table and is not included. CTC time constants, prescalers and
counters, channel priorities, IM2 interrupt vectors and RETI service release
operate independently of CPU bus ownership. CPU clock is 2.5 MHz;
video timing and keyboard busy timing do not accelerate during disk access.
