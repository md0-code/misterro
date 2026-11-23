"""Load each original demo's Serpenti bootstrap through the model's ROM/EAR path."""
from pathlib import Path
import concurrent.futures,json,shutil,subprocess,sys
from build import ROOT,BUILD,cpu,sources,run

MODELS=['HC85','HC90','HC91']

def check(model):
    prefix='' if model=='HC85' else model.lower()+'-'
    scratch=BUILD/('tape-'+model)
    (scratch/'assets/roms').mkdir(parents=True,exist_ok=True)
    (scratch/'build').mkdir(exist_ok=True)
    for ext in ['rom','hex']:
        name=model.lower()+'.'+ext
        shutil.copyfile(ROOT/'assets/roms'/name,scratch/'assets/roms'/name)
    obj=BUILD/('obj' if model=='HC85' else 'obj-'+model)
    tape=ROOT/('assets/tapes/serpenti.tzx' if model=='HC85' else f'assets/tapes/{model.lower()}/serpenti.tzx')
    with (BUILD/(model.lower()+'-tape-runtime.log')).open('w') as log:
        subprocess.run([obj/'Vhc85_sim','--model',model[2:],'--tape',tape,'--seconds','12'],cwd=scratch,stdout=log,stderr=subprocess.STDOUT,check=True)
    subprocess.run([sys.executable,ROOT/'tools/check_tape_capture.py',tape,'--model',model,'--captures',scratch/'build'],cwd=ROOT,check=True)
    return model

def main():
    cpu()
    for model in MODELS:
        obj=BUILD/('obj' if model=='HC85' else 'obj-'+model)
        run(['verilator','--cc','--exe','--build','-j','4','--top-module','hc85_sim',
             '-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-CASEINCOMPLETE','-Wno-WIDTH','-Wno-COMBDLY',
             '--Mdir',obj,'-GMODEL='+model[2:],'-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',
             *sources(),ROOT/'sim/hc85_sim.sv',ROOT/'sim/main.cpp'],log=model.lower()+'-tape-build.log')
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for model in pool.map(check,MODELS):print('PASS:',model,'original cassette bootstrap',flush=True)
if __name__=='__main__':main()
