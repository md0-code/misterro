# COBRA provenance

Primary archive: https://www.z80-romania.ro/CoBra-64

Original bootstrap ROMs, system ROM and the CP/M disk are from the CoBra Project: https://cobrasov.com/CoBra%20Project/. The CP/M disk is its all-drives-DD 80-column system, wrapped losslessly from raw sectors into DSK. The hardware was checked against the circuit reconstruction https://github.com/ceteras/CoBra at 92d213818dce8ff19f104557df051921c73be242 (MIT) and the original 80K and display upgrade drawings.

`sources.lock.json` records asset sizes, SHA-256 values and origins; `bundles.json` maps them to the installed model folders. `dependencies.lock.json` pins the shared MiSTer framework and build containers. Own demonstration software and replacement loaders carry their source beside the firmware. Original ROMs and recordings retain their original rights; new core and shared sources use GPL-3.0-or-later ([licence](../LICENSE)). Upstream files keep their original notices.

The reconstruction's [MIT notice](licenses/CoBra-hardware.txt) is kept with the documentation.
