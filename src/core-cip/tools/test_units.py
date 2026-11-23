"""Run hardware-level regression checks independently of the BASIC ROM."""
from pathlib import Path
import subprocess,json
from validate_quartus import source_hashes
ROOT=Path(__file__).resolve().parents[1]
def run(*args):subprocess.run(list(map(str,args)),cwd=ROOT,check=True)
def main():
    helper=bytes.fromhex('3e 01 d3 ee 3a 00 00 32 04 80 3a 00 08 32 05 80 3e 00 d3 ee 3a 00 08 32 06 80 3e 01 d3 ee 76')
    program=bytearray(bytes.fromhex('f3 31 00 ff 3e 5a 32 00 80 32 00 40 32 00 00 3e a6 32 00 08 3a 00 00 32 01 80 3e 1d d3 fe 3e 04 d3 be 3e fb db fe 32 02 80 db be 32 03 80'))
    source=len(program)+14
    program+=bytes([0x21,source&255,source>>8,0x11,0,0x81,0x01,len(helper),0,0xed,0xb0,0xc3,0,0x81])+helper
    (ROOT/'build/bus.hex').write_text(''.join(f'{b:02x}\n' for b in program.ljust(2048,b'\0')))
    run('iverilog','-g2012','-s','cip01_bus_tb','-o','build/bus.vvp',
        'rtl/cip01_core.sv','rtl/cip01_video.sv','build/t80.v','sim/cip01_bus_tb.sv')
    run('vvp','build/bus.vvp')
    run('iverilog','-g2012','-s','cip01_video_tb','-o','build/video.vvp','rtl/cip01_video.sv','sim/cip01_video_tb.sv')
    run('vvp','build/video.vvp')
    log=ROOT/'build/tape-test-build.log'
    with log.open('w') as out:
        command=['verilator','--binary','--timing','-j','4','-Wno-fatal','-Wno-WIDTH',
                 '--top-module','cip01_tape_tb','--Mdir','build/tape-test',
                 'rtl/cip01_tape.sv','vendor/spectrum/rtl/tape.sv','vendor/spectrum/rtl/pzxplayer.sv',
                 'build/tzxplayer.v','sim/cip01_tape_tb.sv']
        result=subprocess.run(command,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT)
    if result.returncode:
        print('\n'.join(log.read_text().splitlines()[-25:]));raise SystemExit(result.returncode)
    run(ROOT/'build/tape-test/Vcip01_tape_tb')
    with (ROOT/'build/family-tape-test-build.log').open('w') as out:
        command=['verilator','--binary','--timing','-j','4','-Wno-fatal','-Wno-WIDTH',
                 '--top-module','cip_family_tape_tb','--Mdir','build/family-tape-test',
                 'rtl/cip_family_tape.sv','vendor/spectrum/rtl/tape.sv','vendor/spectrum/rtl/pzxplayer.sv',
                 'build/tzxplayer.v','sim/cip_family_tape_tb.sv']
        result=subprocess.run(command,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT)
    if result.returncode:raise SystemExit('Dual-clock cassette test build failed; see build/family-tape-test-build.log')
    run(ROOT/'build/family-tape-test/Vcip_family_tape_tb')
    run('iverilog','-g2012','-s','cip04_ports_tb','-o','build/cip04-ports.vvp','rtl/cip04_ports.sv','sim/cip04_ports_tb.sv')
    run('vvp','build/cip04-ports.vvp')
    (ROOT/'build/unit-validation.json').write_text(json.dumps({'status':'passed','project_sources':source_hashes(),
        'checks':['RAM under ROM, 2K mirroring, EE latch, FE keyboard/EAR/audio, warm/cold reset, both clock configurations',
                  '835584 raster pixels, colours, BRIGHT, FLASH, border',
                  'cassette autoplay, pulses, pause/resume, previous/next, overflow rejection','CIP-04 printer and serial ports']},indent=2)+'\n')
if __name__=='__main__':main()
