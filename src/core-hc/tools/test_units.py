"""Run hardware-level regression checks independently of the BASIC ROM."""
from pathlib import Path
import hashlib,json,subprocess
from validate_quartus import source_hashes
ROOT=Path(__file__).resolve().parents[1]
def run(*args):subprocess.run(list(map(str,args)),cwd=ROOT,check=True)
def main():
    (ROOT/'build').mkdir(exist_ok=True)
    # DI; SP; RAM stores; attempted ROM store; read ROM; port reads/writes; HALT.
    program=bytes.fromhex('f3 31 00 ff 3e 5a 32 00 80 32 00 40 32 00 00 3a 00 00 32 01 80 '
                          '3e 1d d3 fe 3e 04 d3 be 3e fb db fe 32 02 80 3e fb db be 32 03 80 3e fb db 7e 32 04 80 3e 02 d3 7e 76')
    (ROOT/'build/bus.hex').write_text(''.join(f'{b:02x}\n' for b in program.ljust(16384,b'\0')))
    (ROOT/'build/family-bus.hex').write_text(''.join(f'{b:02x}\n' for b in program.ljust(16384,b'\0')*3))
    for model in [85,90,91]:
        for dynamic in [0,1]:
            target=f'build/bus-{model}-{dynamic}.vvp'
            image='build/family-bus.hex' if dynamic else 'build/bus.hex'
            run('iverilog','-g2012','-s','hc85_bus_tb',f'-Phc85_bus_tb.MODEL={model}',f'-Phc85_bus_tb.DYNAMIC={dynamic}',f'-Phc85_bus_tb.ROM_FILE="{image}"','-o',target,
                'rtl/hc85_core.sv','rtl/hc85_video.sv','build/t80.v','sim/hc85_bus_tb.sv')
            run('vvp',target)
    for bright in [0,1]:
        run('iverilog','-g2012','-s','hc85_video_tb',f'-Phc85_video_tb.HAS_BRIGHT={bright}','-o',f'build/video-{bright}.vvp','rtl/hc85_video.sv','sim/hc85_video_tb.sv')
        run('vvp',f'build/video-{bright}.vvp')
    log=ROOT/'build/tape-test-build.log'
    with log.open('w') as out:
        command=['verilator','--binary','--timing','-j','4','-Wno-fatal','-Wno-WIDTH',
                 '--top-module','hc85_tape_tb','--Mdir','build/tape-test',
                 'rtl/hc85_tape.sv','vendor/spectrum/rtl/tape.sv','vendor/spectrum/rtl/pzxplayer.sv',
                 'build/tzxplayer.v','sim/hc85_tape_tb.sv']
        result=subprocess.run(command,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT)
    if result.returncode:
        print('\n'.join(log.read_text().splitlines()[-25:]));raise SystemExit(result.returncode)
    run(ROOT/'build/tape-test/Vhc85_tape_tb')
    (ROOT/'build/unit-validation.json').write_text(json.dumps({'status':'passed','project_sources':source_hashes(),'models':['HC85','HC90','HC91'],'checks':['CPU memory and ROM protection','A6/A7 I/O aliases','model clock behavior','BRIGHT/FLASH and raster','cassette controls and overflow']},indent=2)+'\n')
if __name__=='__main__':main()
