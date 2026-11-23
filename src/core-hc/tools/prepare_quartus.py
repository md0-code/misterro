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
    p=argparse.ArgumentParser();p.add_argument("--model",choices=["HC","HC85","HC90","HC91"],default="HC");model=p.parse_args().model
    OUT=ROOT/("build/quartus" if model=="HC85" else "build/quartus-"+model)
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
    wrapper=(ROOT/'mister/HC.sv').read_text() if model=='HC' else (ROOT/'mister/HC85.sv').read_text().replace('HC_MODEL = 85','HC_MODEL = '+model[2:]).replace('HC85;;',model+';;')
    (OUT/(model+'.sv')).write_text(wrapper)
    shutil.copyfile(ROOT/'mister/HC85.sdc',OUT/'HC85.sdc')
    # Preserve the official pin assignments and framework setup.
    settings=(UP/'ZX-Spectrum.qsf').read_text()
    # Emit the same canonical settings that the pinned Lite CLI writes back.
    settings=settings.replace('17.0.2 Standard Edition','17.0.2 Lite Edition')
    settings=settings.replace('set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL\n','')
    settings += '\nset_global_assignment -name NUM_PARALLEL_PROCESSORS 4\n'
    (OUT/(model+'.qsf')).write_text(settings)
    (OUT/(model+'.qpf')).write_text(f'QUARTUS_VERSION = "17.0"\nPROJECT_REVISION = "{model}"\n')
    lines=['set_global_assignment -name QIP_FILE rtl/T80/T80.qip']
    for file in ['hc_ay.sv','hc85_core.sv','hc85_video.sv','hc85_keyboard.sv','hc85_tape.sv','hc_family_host.sv','hc_family_core.sv','hc88_core.sv','hc88_video.sv','hc88_u765.sv','tape.sv','pzxplayer.sv']:
        lines.append(f'set_global_assignment -name SYSTEMVERILOG_FILE rtl/{file}')
    lines+=['set_global_assignment -name VHDL_FILE rtl/tzxplayer.vhd',
            f'set_global_assignment -name SYSTEMVERILOG_FILE {model}.sv',
            'set_global_assignment -name SDC_FILE HC85.sdc']
    (OUT/'files.qip').write_text('\n'.join(lines)+'\n')
    inputs={'model':model,'project_sources':source_hashes(),
            'upstream_commit':commit,
            'quartus_image':dependencies['quartus_image']}
    (OUT/'inputs.json').write_text(json.dumps(inputs,indent=2)+'\n')
    print(OUT/(model+'.qpf'))
if __name__=='__main__':main()
