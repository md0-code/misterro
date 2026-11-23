"""Save current single-core HC validation evidence and captures."""
import json,shutil
from project_paths import ROOT,DOCS
from validate_quartus import validate,source_hashes

def main():
    fpga=validate('HC')
    family=json.loads((ROOT/'build/family-validation.json').read_text())
    if family['status']!='passed' or family['project_sources']!=source_hashes():raise ValueError('Stale family evidence')
    images=DOCS/'images';images.mkdir(exist_ok=True)
    for model in ['HC85','HC90','HC91']:
        prefix='' if model=='HC85' else model.lower()+'-'
        for name in ['boot','basic','reset-basic','switch-basic']:
            shutil.copyfile(ROOT/f'build/{prefix}{name}.png',images/f'{prefix}{name}.png')
    text="""# HC-family validation

One HC.rbf boots all three original ROMs in the actual T80/PS2 simulation.
Each displays 4 for PRINT 2+2, restarts through F11 and displays 6 for PRINT 3+3.
Live transitions HC85 to HC90, HC90 to HC91 and HC91 to HC85 retain the combined
firmware, show the correct banner and execute arithmetic in the selected ROM.

Independent units cover static and runtime model bus decoding, ROM protection,
RAM, keyboard/EAR, border/beeper/MIC, HC85 arbitration and the HC90/91 divider.
Video checks cover 835,584 pixels per BRIGHT configuration, including FLASH,
normal/bright ink/paper and blanking. Cassette tests cover autoplay, pulse
cadence, pause/resume, block navigation and overflow. Controller checks reject
individual/oversized firmware and verify reset and retained banks on switching.

Separate fixed-model diagnostics have received each original Serpenti BASIC
bootstrap through EAR. This does not certify completion of the large demo
machine-code recordings. Bundled media boundaries, XORs and locked SHA-256
hashes are checked during packaging.

## Family FPGA build

"""
    text+=f"Minimum constrained slack: {fpga['minimum_constrained_slack_ns']:.3f} ns.\n\nBitstream SHA-256: `{fpga['bitstream_sha256']}`.\n"
    text+="""

Packaging requires current source/runtime/FPGA evidence, checks every archive
checksum and reproduces the single HC Quartus project from the source export.
Detailed logs are under build/. The distribution includes family and FPGA receipts.

The core has been run on a physical MiSTer (DE10-Nano). Original counter
phases, analog intensity and HC90/91 operation still need comparison with the
original machines.
Framework external I/O retains upstream constraints.

## Captures

![HC90 original startup](images/hc90-boot.png)

![HC91 arithmetic after F11](images/hc91-reset-basic.png)

![Arithmetic after changing HC90 to HC91](images/hc90-switch-basic.png)
"""
    (DOCS/'validation.md').write_text(text)
if __name__=='__main__':main()
