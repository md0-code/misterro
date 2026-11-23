"""Build and run CIP-01 checks on Linux/WSL. Outputs stay in build/."""
from project_paths import DOCS,README,PLAN,source_path,export_readme
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys, time
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
    return [ROOT/'rtl/cip01_core.sv',ROOT/'rtl/cip01_video.sv',ROOT/'rtl/cip01_keyboard.sv',
            ROOT/'rtl/cip01_tape.sv',ROOT/'rtl/cip_family_tape.sv',UP/'rtl/tape.sv',UP/'rtl/pzxplayer.sv',BUILD/'t80.v',BUILD/'tzxplayer.v']
def family_sim(action,seconds,tape):
    cpu()
    inputs=[*sources(),ROOT/'rtl/cip_family_host.sv',ROOT/'sim/cip_family_sim.sv']
    flags=['-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-CASEINCOMPLETE','-Wno-WIDTH','-Wno-COMBDLY']
    if action=='lint':
        run(['verilator','--lint-only','--top-module','cip_family_sim',*flags,*inputs]);return
    run(['verilator','--cc','--exe','--build','-j','4','--top-module','cip_family_sim','--prefix','Vcip01_sim',
         *flags,'--Mdir',BUILD/'family-obj','-CFLAGS','-DCIP_FAMILY','-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',
         *inputs,ROOT/'sim/cip01_main.cpp'],log='family-verilator-build.log')
    command=[BUILD/'family-obj/Vcip01_sim','--seconds',str(seconds)]
    command+=['--family-model','0','--prefix','family-sim-']
    if tape:command+=['--tape',tape]
    run(command)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['sim','test','lint','reference','quartus','package'])
    p.add_argument('--seconds',type=float,default=3)
    p.add_argument('--tape',type=Path)
    p.add_argument('--model',default='CIP',choices=['CIP','CIP01','CIP02','CIP03','CIP04'],help='Target for test/quartus; other actions use the CIP-01 base or complete family')
    args=p.parse_args()
    if args.model not in ['CIP','CIP01'] and args.action not in ['test','quartus']:
        p.error('--model applies to test and quartus; package always exports the complete family')
    if args.model=='CIP' and args.action in ['sim','lint']:
        family_sim(args.action,args.seconds,args.tape);return
    if args.action=='test' and args.model=='CIP':
        run([sys.executable,ROOT/'tools/test_family.py']);return
    if args.action=='test' and args.model in ['CIP02','CIP03']:
        run([sys.executable,ROOT/'tools/test_models.py']);return
    if args.action=='test' and args.model=='CIP04':
        run([sys.executable,ROOT/'tools/test_cip04.py']);return
    if args.action=='test' and not args.tape:args.tape=ROOT/'assets/tapes/basic.tzx'
    if args.action in ['sim','test','lint']:
        cpu()
        if args.action=='lint':
            run(['verilator','--lint-only','--top-module','cip01_sim','-Wno-fatal','-Werror-MULTIDRIVEN',*sources(),ROOT/'sim/cip01_sim.sv'])
            return
        if args.action=='test':run([sys.executable,ROOT/'tools/test_units.py'])
        run(['verilator','--cc','--exe','--build','-j','4','--top-module','cip01_sim',
             '-Wno-fatal','-Werror-MULTIDRIVEN','-Wno-CASEINCOMPLETE','-Wno-WIDTH','-Wno-COMBDLY',
             '--Mdir',BUILD/'obj','-MAKEFLAGS','OPT_FAST=-O3 OPT_GLOBAL=-O3',
             *sources(),ROOT/'sim/cip01_sim.sv',ROOT/'sim/cip01_main.cpp'],log='verilator-build.log')
        command=[BUILD/'obj/Vcip01_sim','--seconds',str(args.seconds)]
        if args.action=='test': command+=['--test']
        if args.tape: command+=['--tape',args.tape]
        run(command)
        run([sys.executable,ROOT/'tools/check_capture.py']+(['--test'] if args.action=='test' else []))
    elif args.action=='reference':
        run([sys.executable,ROOT/'tools/test_reference.py'])
    elif args.action=='quartus':
        if args.model=='CIP':run([sys.executable,ROOT/'tools/prepare_family.py'])
        elif args.model=='CIP04':run([sys.executable,ROOT/'tools/prepare_cip04.py'])
        else:run([sys.executable,ROOT/'tools/prepare_quartus.py','--model',args.model])
        out='/work/build/quartus' if args.model=='CIP01' else '/work/build/quartus-'+args.model
        run(['docker','run','--rm','--network','none','--entrypoint','/opt/intelFPGA/quartus/bin/quartus_sh',
             '-v',f'{ROOT}:/work','-w',out,QUARTUS_IMAGE,
             '--flow','compile',args.model],log='quartus-build.log' if args.model=='CIP01' else args.model.lower()+'-quartus-build.log')
        qdir=BUILD/('quartus' if args.model=='CIP01' else 'quartus-'+args.model)
        rbf=qdir/f'output_files/{args.model}.rbf'
        if rbf.exists() and rbf.stat().st_mtime_ns < (qdir/'inputs.json').stat().st_mtime_ns:
            run(['docker','run','--rm','--network','none','--entrypoint','/opt/intelFPGA/quartus/bin/quartus_asm',
                 '-v',f'{ROOT}:/work','-w',out,QUARTUS_IMAGE,
                 '--read_settings_files=on','--write_settings_files=off',args.model],log=args.model.lower()+'-assembly.log')
        run([sys.executable,ROOT/'tools/validate_quartus.py','--model',args.model])
    elif args.action=='package':
        run([sys.executable,ROOT/'tools/package.py'])
        run([sys.executable,ROOT/'tools/check_package.py'])
if __name__=='__main__': main()
