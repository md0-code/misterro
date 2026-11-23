"""Verify resident BASIC firmware, copier startup and reset through real Z80/PS2 RTL."""
from project_paths import DOCS,README,PLAN,source_path,export_readme
from pathlib import Path
import hashlib,json,sys
from PIL import Image
from build import ROOT,BUILD,cpu,run,sources
from check_capture import text
from validate_quartus import source_hashes
def main():
    cpu()
    run(['verilator','--cc','--exe','--build','-j','4','--top-module','cip01_sim','-GRESIDENT_ROM=1',
        '-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-CASEINCOMPLETE','-Wno-WIDTH','-Wno-COMBDLY',
        '--Mdir',BUILD/'resident-obj','-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',
        *sources(),ROOT/'sim/cip01_sim.sv',ROOT/'sim/cip01_main.cpp'],log='resident-build.log')
    for model in ['CIP02','CIP03']:
        prefix=model.lower()+'-'
        run([BUILD/'resident-obj/Vcip01_sim','--resident','--test','--seconds','1.5','--prefix',prefix],log=prefix+'runtime.log')
        for name,result in [('basic','4'),('reset-basic','6')]:
            rows=text((BUILD/f'{prefix}{name}.bin').read_bytes())
            if result not in [r.strip() for r in rows]:raise ValueError(f'{model}: wrong {name} result')
            image=Image.open(BUILD/f'{prefix}{name}.ppm');image.save(DOCS/f'images/{prefix}{name}.png')
        report={'status':'passed','project_sources':source_hashes(model),
            'checks':['original 16K BASIC cold boot without cassette','PS2 PRINT 2+2 gives 4','F11 restart','PS2 PRINT 3+3 gives 6 after reset'],
            'firmware_sha256':hashlib.sha256((ROOT/'assets/roms/cip03.rom').read_bytes()).hexdigest(),
            'qualification':'Resident firmware verified; physical CIP-02 ROM switching requires technical evidence' if model=='CIP02' else 'Physical MiSTer confirmation pending'}
        if model=='CIP02':
            run([BUILD/'resident-obj/Vcip01_sim','--resident','--monitor','--test','--seconds','.6','--prefix','cip02-monitor-'],log='cip02-monitor-runtime.log')
            report['checks'].append('original 2K copier cold boot')
        (BUILD/f'{model.lower()}-functional-validation.json').write_text(json.dumps(report,indent=2)+'\n')
        print('PASS:',model,report['checks'])
if __name__=='__main__':main()
