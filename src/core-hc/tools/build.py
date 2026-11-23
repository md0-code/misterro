"""Build and run HC-family checks on Linux/WSL. Outputs stay in build/."""
from project_paths import DOCS,README,PLAN,source_path,export_readme
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys, time, tempfile
ROOT=Path(__file__).resolve().parents[1]
UP=ROOT/'vendor/spectrum'
BUILD=ROOT/'build'
DEPENDENCIES=json.loads((DOCS/'dependencies.lock.json').read_text())
GHDL_IMAGE=DEPENDENCIES['ghdl_image']
QUARTUS_IMAGE=DEPENDENCIES['quartus_image']
def ghdl(args):
    return ['docker','run','--rm','--network','none','--entrypoint','ghdl',
            '-v',f'{ROOT}:/work','-w','/work',GHDL_IMAGE,*map(str,args)]
def run(args, log=None, **kwargs):
    print('+ '+' '.join(map(str,args)),flush=True)
    if log:
        with (BUILD/log).open('w') as out:
            result=subprocess.run(list(map(str,args)),cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,**kwargs)
        if result.returncode:
            print('\n'.join((BUILD/log).read_text(errors='replace').splitlines()[-50:]),flush=True)
            raise subprocess.CalledProcessError(result.returncode,args)
    else:
        subprocess.run(list(map(str,args)),cwd=ROOT,check=True,**kwargs)
def cpu():
    BUILD.mkdir(exist_ok=True)
    files=['T80_Pack','T80_ALU','T80_MCode','T80_Reg','T80','T80pa']
    vhdl=[UP/f'rtl/T80/{f}.vhd' for f in files]+[UP/'rtl/tzxplayer.vhd']
    fingerprint=hashlib.sha256((GHDL_IMAGE+'-v5').encode()+b''.join(p.read_bytes() for p in vhdl)).hexdigest()
    stamp=BUILD/'vhdl.sha256'
    if stamp.exists() and stamp.read_text()==fingerprint and all((BUILD/f).exists() for f in ['t80.v','tzxplayer.v']):
        return
    target=BUILD/'t80.v'
    generated=BUILD/'vhdl'
    generated.mkdir(exist_ok=True)
    # Avoid a GHDL 2 net-name collision: instance alu.Q collides with signal ALU_Q.
    # Only instance labels change. The hardware VHDL dependency stays unmodified.
    for path in vhdl[:-1]:
        text=path.read_text()
        text=re.sub(r'(?im)^(\s*)(\w+)(\s*:\s*T80\w*\s*)$',r'\1\2_component\3',text)
        (generated/path.name).write_text(text)
    command=ghdl(['--synth','--std=08','-fsynopsys','--out=verilog',
             *[f'build/vhdl/{f}.vhd' for f in files],'-e','T80pa'])
    print('Synthesizing simulation CPU',flush=True)
    target.write_bytes(subprocess.run(list(map(str,command)),cwd=ROOT,check=True,stdout=subprocess.PIPE).stdout)
    # GHDL 2 emits unescaped Verilog keywords for two lower-case VHDL port names.
    text=target.read_text()
    text=re.sub(r'\bdo\b','data_out',text)
    text=re.sub(r'(output \[211:0\] )reg\b',r'\1registers_out',text)
    text=re.sub(r'\bassign reg\b','assign registers_out',text)
    text=text.replace('.reg(','.registers_out(')
    target.write_text(text)
    target=BUILD/'tzxplayer.v'
    command=ghdl(['--synth','--std=08','-fsynopsys','--out=verilog',
             '-gTZX_MS=3500','vendor/spectrum/rtl/tzxplayer.vhd','-e','tzxplayer'])
    text=subprocess.run(list(map(str,command)),cwd=ROOT,check=True,stdout=subprocess.PIPE).stdout.decode()
    # Synthesis specializes this generic; the only caller requests that exact value.
    text=text.replace('module tzxplayer\n','module tzxplayer #(parameter TZX_MS = 3500)\n')
    target.write_text(text)
    stamp.write_text(fingerprint)
def sources():
    return [ROOT/'rtl/hc85_core.sv',ROOT/'rtl/hc85_video.sv',ROOT/'rtl/hc85_keyboard.sv',
            ROOT/'rtl/hc85_tape.sv',ROOT/'rtl/hc88_core.sv',ROOT/'rtl/hc88_video.sv',ROOT/'rtl/hc88_u765.sv',ROOT/'rtl/hc_family_core.sv',ROOT/'rtl/hc_ay.sv',UP/'rtl/tape.sv',UP/'rtl/pzxplayer.sv',BUILD/'t80.v',BUILD/'tzxplayer.v']
def family_sim(action,seconds,tape):
    cpu()
    inputs=[*sources(),ROOT/'rtl/hc_family_host.sv',ROOT/'sim/hc_family_sim.sv']
    flags=['-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-CASEINCOMPLETE','-Wno-WIDTH','-Wno-COMBDLY']
    if action=='lint':
        run(['verilator','--lint-only','--top-module','hc_family_sim',*flags,*inputs]);return
    run(['verilator','--cc','--exe','--build','-j','4','--top-module','hc_family_sim','--prefix','Vhc85_sim',
         *flags,'--Mdir',BUILD/'family4-obj','-CFLAGS','-DHC_FAMILY','-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',
         *inputs,ROOT/'sim/main.cpp'],log='family-verilator-build.log')
    command=[BUILD/'family4-obj/Vhc85_sim','--seconds',str(seconds)]
    command+=['--model','85']
    if tape:command+=['--tape',tape]
    run(command)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['sim','test','lint','quartus','package'])
    p.add_argument('--model',choices=['HC','HC85','HC90','HC91'],default='HC')
    p.add_argument('--seconds',type=float,default=3)
    p.add_argument('--tape',type=Path)
    args=p.parse_args()
    model=args.model;number=model[2:];obj=BUILD/('obj' if model=='HC85' else 'obj-'+model)
    if model=='HC' and args.action in ['sim','test','lint']:
        if args.action=='test':
            run([sys.executable,ROOT/'tools/test_family.py'])
            run([sys.executable,ROOT/'tools/test_hc88.py'])
            for test in ['test_expansion_units.py','test_tape_memory.py','test_fdc.py','test_expansion_runtime.py']:
                run([sys.executable,ROOT/'tools'/test])
        else:family_sim(args.action,args.seconds,args.tape)
        return
    if args.action in ['sim','test','lint']:
        cpu()
        if args.action=='lint':
            run(['verilator','--lint-only','--top-module','hc85_sim','-GMODEL='+number,'-Wno-fatal','-Werror-MULTIDRIVEN',*sources(),ROOT/'sim/hc85_sim.sv'])
            return
        if args.action=='test':run([sys.executable,ROOT/'tools/test_units.py'])
        run(['verilator','--cc','--exe','--build','-j','4','--top-module','hc85_sim',
             '-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-CASEINCOMPLETE','-Wno-WIDTH','-Wno-COMBDLY',
             '--Mdir',obj,'-GMODEL='+number,'-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',
             *sources(),ROOT/'sim/hc85_sim.sv',ROOT/'sim/main.cpp'],log=model.lower()+'-verilator-build.log')
        command=[obj/'Vhc85_sim','--model',number,'--seconds',str(args.seconds)]
        if args.action=='test': command+=['--test']
        if args.tape: command+=['--tape',args.tape]
        run(command)
        run([sys.executable,ROOT/'tools/check_capture.py','--model',model]+(['--test'] if args.action=='test' else [])+(['--tape'] if args.tape else []))
        if args.action=='test' and args.tape:
            run([sys.executable,ROOT/'tools/check_tape_capture.py',args.tape,'--model',model])
    elif args.action=='quartus':
        run([sys.executable,ROOT/'tools/prepare_quartus.py','--model',model])
        qdir=BUILD/('quartus' if model=='HC85' else 'quartus-'+model)
        from validate_quartus import source_hashes
        original=source_hashes()
        # Quartus' small-file database is substantially faster on WSL storage.
        with tempfile.TemporaryDirectory(prefix='mister-hc-quartus-') as folder:
            work=Path(folder)
            shutil.copytree(qdir,work,dirs_exist_ok=True,ignore=shutil.ignore_patterns('db','incremental_db','output_files','greybox_tmp'))
            try:
                run(['docker','run','--rm','--network','none','--entrypoint','/opt/intelFPGA/quartus/bin/quartus_sh',
                     '-v',f'{work}:/work','-w','/work',QUARTUS_IMAGE,'--flow','compile',model],log=model.lower()+'-quartus-build.log')
            finally:
                changed=source_hashes()!=original
                if not changed:shutil.copytree(work,qdir,dirs_exist_ok=True)
                run(['docker','run','--rm','--network','none','--entrypoint','/bin/chown','-v',f'{work}:/cleanup',QUARTUS_IMAGE,'-R',f'{os.getuid()}:{os.getgid()}','/cleanup'])
                if changed:raise ValueError('Hardware sources changed during compilation')
        run([sys.executable,ROOT/'tools/validate_quartus.py','--model',model])
    elif args.action=='package':
        run([sys.executable,ROOT/'tools/package.py'])
        run([sys.executable,ROOT/'tools/check_package.py'])
if __name__=='__main__': main()
