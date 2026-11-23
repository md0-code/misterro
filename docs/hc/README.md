# HC for MiSTer

ICE Felix HC-85, HC-88, HC-90, HC-91, HC-91 Plus/HC-128 and HC-2000 in one core.
No SDRAM module is required.

All models provide the original keyboard matrix, Sinclair joystick inputs, cassette
EAR input, MIC output and beeper. HC-90 and later models provide BRIGHT. HC-91 Plus
adds 128K RAM paging, its original BASIC menu and selectable AY-3-8912 sound.
HC-85 and HC-90/91 have optional **Interface 1** disk, serial and local-network
hardware. HC-2000 has its built-in disk interface, with Floppy A representing the
internal drive and Floppy B the external drive. HC-88 retains its separate system
and video memory, 512-pixel display and original disk bootstrap.

## Start

1. Extract `MiSTerRO-<version>-HC.zip` onto the MiSTer card, preserving paths.
2. Select **HC** under Computers. The root `boot.rom` loads automatically and holds
   all model firmware; model changes reset the CPU and cassette without another upload.
3. Choose the **Model**. HC-85/90/91 and HC-2000 start their resident BASIC; HC-91 Plus
   starts its original menu: choose **128 BASIC** or **48 BASIC**.
4. Enter `LOAD ""`, then choose the model's `demo.tzx` with **Load tape**.

## Options

| Menu | Option | Choices |
| --- | --- | --- |
| System | Model | HC-85, HC-90, HC-91, HC-88, HC-91 Plus (HC-128), HC-2000 |
| System | Startup | BASIC, CP/M |
| System | Load firmware | reloads the combined `boot.rom`; incomplete or oversized files are rejected |
| Ports & Controllers | Interface 1 | Off, On |
| Ports & Controllers | AY sound board | Off, On: the expansion-connector AY board for the models without AY |
| Audio & Video | HC-128 AY sound | On, Off: the optional sound chip of the HC-91 Plus |
| Audio & Video | Tape sound | On, Off |
| Audio & Video | Aspect ratio | Original, Full Screen, ARC1, ARC2 |
| Audio & Video | Scandoubler Fx | None, HQ2x, CRT 25%, CRT 50% |

## Tapes and disks

Playback runs at cassette speed. TAP, CSW v1, TZX and PZX files up to 256 KiB are
supported. MIC is mixed into audio so SAVE output can be recorded.

For HC-85/90/91 or HC-91 Plus, enable **Interface 1**, mount a DSK/EDSK image in
**Floppy A** or **Floppy B**, then press **F11**. HC-2000 and HC-88 have their disk
controllers built in. Images describe the drive geometry, including 5.25-inch
35/40-track and 3.5-inch 80-track media. Writes persist in the mounted image.

For HC-85, copy the supplied 40-track, double-sided 320K `support/blank.dsk`
before use. Initialize the copy with
`FORMAT "d";1`, then use `CAT 1`, `SAVE *"d";1;"name"` and
`LOAD *"d";1;"name"`.
Formatting rewrites sector IDs and data inside the container's allocated tracks;
use a supplied image as the template for a new disk.

HC-90/91/128 include the original HC-91 CP/M disk set. HC-2000 includes its original
720K CP/M and demonstration disks. Mount `support/system.dsk`, choose
**Startup -> CP/M**, and press **F11**. With HC-91/2000 resident BASIC, the original
`PRINT USR 14446` launcher is also available. HC-91 Plus additionally accepts
BREAK held during reset: hold Escape, press and release F11, then release Escape.

HC-90/91/128 use a labelled compatibility entry and the unchanged original
HC-2000 Rev-E CP/M BIOS for these disks. HC-2000 uses its verified v1 ROM. Their original BASIC ROMs
remain unchanged. Choose **Startup -> BASIC** and reset to return.

At the CP/M prompt, `DIR` lists files and `B:` selects the second drive.
For HC2000, use `support/system.dsk` (720K) in A and `support/external.dsk`
(360K) in B; the bundled v1 BIOS uses different directory layouts for these drives.
Use copies of system images for experiments. The HC-2000 `support/demo.dsk`
contains the original disk demonstration for the BASIC disk commands.

For HC-88, mount `support/system.dsk` in **Floppy A** and press **F11**.
The unchanged 2K bootstrap starts the bundled replacement CP/M 2.2 system.
Try `DIR`, `TYPE README.TXT`, `TRACK`, `WRITE` or `DEMO`. The demo exercises
512-pixel video and speaker output; press a key to return.
Enter `BASIC` to load the unchanged HC-85 interpreter into RAM from disk.
Use `LOAD ""` and the labelled family demonstration cassette. F11 returns to disk
boot. The system disk and BIOS are replacements; the bootstrap and schematics
are original. See [HC-88](hc88.md).

## Ports and controllers

- F11 resets; F12 opens the MiSTer menu.
- Ctrl or Alt is SYMBOL SHIFT; either Shift is CAPS SHIFT.
- Arrow keys, Backspace and Escape produce the corresponding matrix combinations.
- F1 pauses/resumes tape; F2/F3 select the previous/next block.
- Joysticks provide Sinclair matrix controls and Kempston port `1F` input.
- **AY sound board** adds an AY-3-8912 at `FFFD`/`BFFD` to HC-85, HC-90, HC-91 and
  HC-2000, as the expansion-connector sound board for HC-91 and HC-2000 does. It
  decodes the whole low address byte, clear of the HC's own ports.
- Interface 1 serial channels use MiSTer's UART signals, including readiness handshaking.
- Interface 1 local networking uses USER port bit 0 as an open-drain link.
  Connect matching bits and ground between MiSTers using 3.3V-compatible wiring;
  original HC analog network/RS-232 wiring requires a suitable level adapter.

Serial baud rates and network station numbers are selected by the original
Interface 1 software. Serial printers use its serial channels. Connection details
and the board-specific registers are in [interfaces](interfaces.md).

## Included files

`games/HC/` contains the combined `boot.rom` and one folder for each model
(`HC85`, `HC88`, `HC90`, `HC91`, `HC128`, `HC2000`) with `boot.rom`, `demo.tzx` and a
checksum manifest (`bundle.json`). Its `support/` folder holds disk images and
additional firmware.
Family-reference material is labelled in `bundle.json`. Individual model ROMs
are archival copies.

## Build

From `src/core-hc/`:

```powershell
./tools/build.ps1 test
./tools/build.ps1 quartus
./tools/build.ps1 package
```

See [building](build.md), [models](models.md), [hardware](hardware.md),
[validation](validation.md) and [licensing](licenses/README.md).
