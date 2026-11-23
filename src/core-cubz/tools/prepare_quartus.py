"""Prepare the pinned MiSTer framework and native CUB Z machine."""
from project_paths import ROOT,DOCS
from validate_quartus import source_hashes
import shutil,json,subprocess
UP=ROOT/'vendor/spectrum';OUT=ROOT/'build/quartus-CUBZ'
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 dep=json.loads((DOCS/'dependencies.lock.json').read_text())
 if (UP/'.git').exists() and subprocess.check_output(['git','rev-parse','HEAD'],cwd=UP,text=True).strip()!=dep['spectrum']['commit']:raise ValueError('Dependency revision changed')
 shutil.copytree(UP/'sys',OUT/'sys',dirs_exist_ok=True);shutil.copytree(UP/'rtl/T80',OUT/'rtl/T80',dirs_exist_ok=True)
 (OUT/'rtl/pll.qip').write_text('# Machine clock uses cubz_pll.sv; framework HDMI/audio PLLs remain unchanged.\n')
 for p in (ROOT/'rtl').glob('*.sv'):shutil.copyfile(p,OUT/'rtl'/p.name)
 for p in (ROOT/'mister').iterdir():shutil.copyfile(p,OUT/p.name)
 settings=(UP/'ZX-Spectrum.qsf').read_text().replace('17.0.2 Standard Edition','17.0.2 Lite Edition')
 settings=settings.replace('set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL\n','')+'\nset_global_assignment -name NUM_PARALLEL_PROCESSORS 4\n'
 (OUT/'CUBZ.qsf').write_text(settings);(OUT/'CUBZ.qpf').write_text('QUARTUS_VERSION = "17.0"\nPROJECT_REVISION = "CUBZ"\n')
 lines=['set_global_assignment -name QIP_FILE rtl/T80/T80.qip']
 lines += ['set_global_assignment -name SYSTEMVERILOG_FILE rtl/'+p.name for p in sorted((ROOT/'rtl').glob('*.sv'))]
 lines += ['set_global_assignment -name SYSTEMVERILOG_FILE CUBZ.sv','set_global_assignment -name SYSTEMVERILOG_FILE cubz_pll.sv','set_global_assignment -name SDC_FILE CUBZ.sdc']
 (OUT/'files.qip').write_text('\n'.join(lines)+'\n')
 (OUT/'inputs.json').write_text(json.dumps({'model':'CUBZ','project_sources':source_hashes(),'upstream_commit':dep['spectrum']['commit'],'quartus_image':dep['quartus_image']},indent=2)+'\n')
if __name__=='__main__':main()
