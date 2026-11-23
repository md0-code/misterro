# HC model differences

| Property | HC-85 | HC-90 | HC-91 |
| --- | --- | --- | --- |
| BASIC ROM | Original HC85 16 KiB | Original HC90 16 KiB | Original HC91 16 KiB |
| CPU-visible RAM | 4000-FFFF | 4000-FFFF | 4000-FFFF |
| Keyboard/cassette decode | A0=0, A6=1 | A0=0, A7=1 | A0=0, A7=1 |
| Attribute BRIGHT | Unconnected | Bit 6 | Bit 6 |
| Base CPU clock | Existing HC85 arbitration | Direct X2L, 3.5 MHz | Direct X2L, 3.5 MHz |

All six profiles share one retained-firmware HC core. The original indices remain
0=HC85, 1=HC90, 2=HC91 and 3=HC88; HC128 and HC2000 use indices 4 and 5.

| Property | HC-88 | HC-91 Plus / HC-128 | HC-2000 |
| --- | --- | --- | --- |
| Resident ROM | Original 2K bootstrap | Original 32K BASIC | Original 16K BASIC + 16K CP/M |
| RAM | 64K system + separate 16K video | 128K, eight 16K pages | 64K |
| Paging | Native 9F, LOCK and video overlays | 7FFD, ROM/screen selection and 48K lock | 7E configuration and C5/C7 alias |
| Disk | Built-in 8272, two drives | Optional HC90/91 Interface 1 | Built-in 8272, internal/external drives |
| Sound | Beeper | Beeper and optional AY-3-8912 | Beeper |

See [interfaces](interfaces.md) for the additional hardware and ROM provenance.

## Circuit evidence

The [HC-90 schematics](https://www.z80-romania.ro/1990_Scheme_logice_HC_90-260),
drawing 869594934 revision B, establish the following connections:

- CPU-ROM sheet 1 (PDF page 3): F7 74LS138 enables are A0, IORQ and M1;
  select inputs are WR, A7 and RD. INFEL is Y3 and OUTFEL is Y6. A6 is unused.
- CPU-ROM sheet 1 and counters sheet 4 (PDF page 6): CPU CLK is X2L from the
  free-running 14 MHz divider. WAIT is pulled high in the base machine.
- RGB sheet 6 (PDF page 8): attribute bit 6 reaches the BRIGHT output;
  the border path supplies zero brightness.
- Memory-selection sheet 2 and memory sheet 8 establish the ROM/RAM selection.
  The 64 KiB physical DRAM does not imply extra CPU-visible RAM under BASIC ROM.

The [HC-91 schematics](https://www.z80-romania.ro/1991_Scheme_logice_HC_91-261),
revision C dated February 1992, establish equivalent base-machine connections:

- CPU sheet 1: F4 74LS138 selects INFEL Y3 / OUTFEL Y6 using WR, A7 and RD,
  enabled by IORQ, A0 and M1. CPU CLK is connected to X2L.
- NUM sheet 2 supplies the divider. MEM sheet 6 contains the two 4464 DRAMs.
- CLK sheet 7 routes the attribute latch to RGB and BRIGHT; border brightness is zero.
- MUX sheet 4 contains the F3 configuration latch: B/OL, CPMP/CPMPL, CVS and
  write lock. SEL sheet 8 applies these signals to ROM/RAM selection and uses
  the external interface's CPM signal for the upper-RAM alias. These functions
  are enabled for disk operation in the family core.

The [HC-90](https://www.z80-romania.ro/1990_Manual_de_utilizare_HC_90-49) and
[HC-91](https://www.z80-romania.ro/1991_Manual_de_utilizare_HC_91-27) manuals describe
the 16 KiB BASIC, 48 KiB accessible RAM, keyboard, cassette, BRIGHT and FLASH.
ROM hashes also match the independent MAME firmware identities in
[sources.lock.json](sources.lock.json).

## Memory and display

HC-85/90/91/128/2000 share the nominal 448x312 raster and Spectrum-compatible
bitmap layout. HC128 selects RAM page 5 or 7 for video. The HC90/91 configuration
CVS bit and HC2000 select the 4000 or C000 RAM screen. The CP/M ROM's condensed
character renderer uses 64 columns on that display; the catalogue's general
80-column description is not used to alter the original renderer.

The HC-91 Plus therefore has no 80-column display hardware to add: its CP/M text
is drawn by the BIOS on the 256-pixel bitmap.

**AY sound board** fits an AY-3-8912 to HC-85, HC-90, HC-91 and HC-2000 as the
expansion-connector board for HC-91/HC-2000 does: register select at FFFD, data
at BFFD, the whole low address byte decoded so that the HC's own ports (7E, C5,
C7, E7, EF, F7, FE) stay clear, clocked at half the system clock (1.75 MHz).

HC88 retains its 256/512-pixel serializer and separate video RAM. Exact gate
phases and analog output intensity remain subject to original-machine comparison.
