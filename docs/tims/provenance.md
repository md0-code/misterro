# TIMS provenance

Primary archive: https://www.z80-romania.ro/TIM_S-68

Plus archive: https://www.z80-romania.ro/TIM_S_Plus-97

The native Plus bootstrap EPROM is unavailable. `plus-loader.asm` is a replacement; `plus3-system.rom` is the unmodified English +3 v4.1 image extracted from the pinned MiSTer Spectrum firmware. The combined firmware includes the original TIM-S ROM, the replacement 2 KiB bootstrap and this 64 KiB system.

`sources.lock.json` records asset sizes, SHA-256 values and origins; `bundles.json` maps them to the installed model folders. `dependencies.lock.json` pins the shared MiSTer framework and build containers. Own demonstration software and replacement loaders carry their source beside the firmware. Original ROMs and recordings retain their original rights; new core and shared sources use GPL-3.0-or-later ([licence](../LICENSE)). Upstream files keep their original notices.
