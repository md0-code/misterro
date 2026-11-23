# Licensing

Original project code is GPL-3.0-or-later; the license is in `GPL-3.0.txt`.

The pinned MiSTer dependency retains each component's original notices.
In particular, T80 has its own redistribution terms in its VHDL headers,
the cassette player is GPL-3.0-or-later, and the MiSTer framework has the
licenses stated in its source headers. Altera-generated PLL and platform
files retain their FPGA-device use conditions.

The source package retains the complete relevant dependency sources and
their notices. Original HC-family firmware, documentation scans and cassette
recordings retain their original ownership; downloading them does not
relicense them as project code.

The HC-88 replacement disk includes CP/M 2.2 CCP and BDOS from the pinned
original source. Its retained redistribution licence is [cpm22.txt](cpm22.txt).
The HC-88 8272 implementation retains Gyorgy Szombathelyi's GPL-2.0-or-later
notice. New HC-88 hardware and software are GPL-3.0-or-later.

The AY implementation retains MikeJ and Sorgelig's BSD redistribution notice in
`rtl/hc_ay.sv`. Its constant lookup table uses a compiler-compatible function;
the tone, noise and envelope logic remains from the pinned upstream source.
