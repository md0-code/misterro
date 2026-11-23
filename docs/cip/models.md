# CIP model profiles

## CIP-01

Original 2 KiB copier, 64 KiB RAM and BASIC loaded from cassette at runtime.
Select CIP-01 in the single CIP core; use `CIP01/basic.tzx` after L/Enter/Enter.

## CIP-02

The [archive](https://www.z80-romania.ro/CIP_02-62) identifies a transitional model
with the CIP-01 2 KiB copier and the CIP-03 16 KiB BASIC ROM. Both original ROMs
are retained in the native section of the shared family `boot.rom`. **CIP-02 Startup** chooses resident
BASIC or the copier; changing it resets the CPU. Resident BASIC boots without
a cassette. Press Enter at the Basic-S screen to activate the K cursor.

This is a firmware compatibility profile. The physical board's ROM-selection
wiring has not been established. The OSD selection is an explicit host control,
not a claimed reconstruction of undocumented banking hardware.

## CIP-03

The [original ROM and manual](https://www.z80-romania.ro/CIP_03-63) supply the
resident 16 KiB BASIC and document its initial Enter key. This profile maps that
EPROM at 0000-3FFF and retains the shared 64 KiB RAM, display, keyboard and tape
interface. The bundle includes the copier for CIP-02 packaging consistency;
CIP-03 does not map it. CPU writes cannot modify the resident EPROM.

Cold boot, PRINT 2+2, F11 restart and PRINT 3+3 after restarting are checked in
the actual T80/PS2 RTL. No cassette or interpreter-memory injection is used.

## CIP-04 experimental compatibility profile

The [CIP-04 archive](https://www.z80-romania.ro/CIP_04-96) supplies four 16 KiB ROM
banks and identifies 256 KiB installed RAM. Its DOS bank is byte-identical to
the local original +3 DOS ROM; the other banks contain small changes to the
+3 ROMs. The firmware therefore provides direct evidence for the +3 paging and
disk interface. It does not establish how the extra 128 KiB is addressed.

Bank 0 redirects startup at 0009 to 37E0. There it executes `LD BC,5FFD`,
`XOR A`, `OUT (C),A`, then jumps back to 010F. This proves a CIP-specific
control-port initialization to zero; it does not reveal that port's nonzero
bit meanings. No extra-RAM layout is inferred from that single write.

The experimental OSD model uses the pinned +3 platform with the original CIP-04
ROM set, standard 7FFD/1FFD paging, AY sound and the u765 DSK interface. It
requires MiSTer SDRAM. The CPU address map currently exposes the verified
128 KiB +3 layout. **This is not full 256 KiB CIP-04 support.** Establishing
whether/how the remaining RAM is wired requires a schematic, traced board,
or equivalent technical evidence.

The firmware's printer and serial routines define two ports. The printer routine
(bank 0 at 2503h, bank 1 at 20B4h) waits for bit 0 of port 0FFD to clear, writes
the byte to 0FFD and pulses bit 4 of 1FFD low. The serial routines select AY
register 14 and use bit 3 as TXD, bit 2 as CTS out, bit 7 as RXD and bit 6 as
DTR in. `rtl/cip04_ports.sv` implements both on MiSTer's UART pins. The CIP
manuals name a printer interface for CIP-01/02/03 without a circuit; none is
implemented for them.

Only disk images in DSK format are offered by this profile. Its custom keyboard
uses the same GPL matrix implementation as CIP-01/02/03. Generic Spectrum
hardware-model choices and unrelated expansion menus are not exposed.

FPGA compilation and ROM-layout auditing are separate from physical startup,
keyboard, tape, AY and disk checks. Do not treat this profile as hardware-validated.
