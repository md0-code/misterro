"""Synthesize the pinned original T80 VHDL for Linux simulation."""
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
    vhdl=[UP/f'rtl/T80/{f}.vhd' for f in files]
    fingerprint=hashlib.sha256((GHDL_IMAGE+'-v5').encode()+b''.join(p.read_bytes() for p in vhdl)).hexdigest()
    stamp=BUILD/'vhdl.sha256'
    if stamp.exists() and stamp.read_text()==fingerprint and all((BUILD/f).exists() for f in ['t80.v']):
        return
    target=BUILD/'t80.v'
    generated=BUILD/'vhdl'
    generated.mkdir(exist_ok=True)
    # Avoid a GHDL 2 net-name collision: instance alu.Q collides with signal ALU_Q.
    # Only instance labels change. The hardware VHDL dependency stays unmodified.
    for path in vhdl:
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
    stamp.write_text(fingerprint)
