# CRT emulation preset

The video processing preset that comes with every MiSTerRO core: soft pixel edges, light scanlines and a matching
gamma curve, as far as the MiSTer scaler allows.

## What it does

| Effect | How |
|---|---|
| Nearest-neighbour image with soft 3x3 gaussian edges | Custom horizontal and vertical polyphase filters |
| Light (5%) scanlines | Folded into the vertical filter, locked to source lines |
| Gamma 0.8 | Custom gamma curve |
| Faint 3-column stripe | Its average brightness is folded into the gamma curve (the stripe itself is finer than the shadow mask can reproduce) |
| Curvature, overscan, vignette, rounded corners, monochrome modes | Not possible: the MiSTer video pipeline has no geometry or per-position effects |

Default tuning: 720p HDMI output and 240-line cores (the common 3x case).

Run the build and upload commands from `src/preset-crt/`.

## Install

Every core archive puts the preset on the card, in `Filters/`, `Gamma/` and `Presets/`. From a checkout, copy the
contents of `src/preset-crt/dist/` to the card (`/media/fat`), or upload them over SSH:

```
pip install paramiko
python tools/deploy.py --host <mister-ip>
```

The deployer prompts for the SSH password, or reads `MISTER_PASSWORD` from the environment.

On the MiSTer, open the OSD for a core, go to **Video Processing → Load preset** and pick **CRT_Emulation**.
To apply it to every core by default, add this to `MiSTer.ini`:

```
preset_default=CRT_Emulation
```

## Rebuilding for another output resolution

```
python tools/build.py --output-height 1080 --source-height 240
```

Options: `--output-height` (HDMI output lines), `--source-height` (typical core lines), `--aspect` (game viewport aspect,
default 4:3). The files are regenerated in `dist/`.
