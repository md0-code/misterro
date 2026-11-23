"""Prepare an isolated Quartus 17 project with the pinned MiSTer framework."""
from project_paths import DOCS,README,PLAN,source_path,export_readme
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess
from validate_quartus import source_hashes
ROOT=Path(__file__).resolve().parents[1]
UP=ROOT/'vendor/spectrum'
OUT=ROOT/'build/quartus'
def main():
    global OUT
    p=argparse.ArgumentParser();p.add_argument('--model',default='CIP01',choices=['CIP01','CIP02','CIP03']);model=p.parse_args().model
    OUT=ROOT/('build/quartus' if model=='CIP01' else f'build/quartus-{model}')
    OUT.mkdir(parents=True,exist_ok=True)
    dependencies=json.loads((DOCS/'dependencies.lock.json').read_text())
    commit=dependencies['spectrum']['commit']
    if (UP/'.git').exists():
        actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=UP,text=True).strip()
        if actual!=commit:raise ValueError('MiSTer dependency does not match the locked revision')
    shutil.copytree(UP/'sys',OUT/'sys',dirs_exist_ok=True)
    shutil.copytree(UP/'rtl/pll',OUT/'rtl/pll',dirs_exist_ok=True)
    shutil.copytree(UP/'rtl/T80',OUT/'rtl/T80',dirs_exist_ok=True)
    for file in ['pll.v','pll.qip','tape.sv','pzxplayer.sv','tzxplayer.vhd']:
        shutil.copyfile(UP/'rtl'/file,OUT/'rtl'/file)
    for file in (ROOT/'rtl').glob('*.sv'):
        shutil.copyfile(file,OUT/'rtl'/file.name)
    for file in [model+'.sv','CIP01.sdc']:
        shutil.copyfile(ROOT/'mister'/file,OUT/file)
    # Preserve the official pin assignments and framework setup.
    settings=(UP/'ZX-Spectrum.qsf').read_text()
    # Emit the same canonical settings that the pinned Lite CLI writes back.
    settings=settings.replace('17.0.2 Standard Edition','17.0.2 Lite Edition')
    settings=settings.replace('set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL\n','')
    settings += '\nset_global_assignment -name NUM_PARALLEL_PROCESSORS 4\n'
    (OUT/f'{model}.qsf').write_text(settings)
    (OUT/f'{model}.qpf').write_text(f'QUARTUS_VERSION = "17.0"\nPROJECT_REVISION = "{model}"\n')
    lines=['set_global_assignment -name QIP_FILE rtl/T80/T80.qip']
    for file in ['cip01_core.sv','cip01_video.sv','cip01_keyboard.sv','cip01_tape.sv','tape.sv','pzxplayer.sv']:
        lines.append(f'set_global_assignment -name SYSTEMVERILOG_FILE rtl/{file}')
    lines+=['set_global_assignment -name VHDL_FILE rtl/tzxplayer.vhd',
            f'set_global_assignment -name SYSTEMVERILOG_FILE {model}.sv',
            'set_global_assignment -name SDC_FILE CIP01.sdc']
    (OUT/'files.qip').write_text('\n'.join(lines)+'\n')
    inputs={'project_sources':source_hashes(model),
            'upstream_commit':commit,
            'quartus_image':dependencies['quartus_image']}
    (OUT/'inputs.json').write_text(json.dumps(inputs,indent=2)+'\n')
    print(OUT/f'{model}.qpf')
if __name__=='__main__':main()
