"""Check the fitted bitstream against the unmodified baseline timing constraints."""
from project_paths import ROOT,DOCS
from common import run
from pathlib import Path
import hashlib,json,os,shutil,tempfile
LINE='set_global_assignment -name SDC_FILE implementation-margin.sdc'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def signoff(work,image):
 q=work/'JUNIORXT.qsf';fit=work/'JUNIORXT.fit.qsf';text=q.read_text()
 if text.count(LINE)==1:
  fit.write_text(text);q.write_text(text.replace(LINE,'# Fitter-only extra margin; baseline signoff uses the original SDC files.'))
 elif not fit.exists() or q.read_text()!=fit.read_text().replace(LINE,'# Fitter-only extra margin; baseline signoff uses the original SDC files.'):
  raise ValueError('Cannot identify the original fitting constraints')
 before=sha(work/'output_files/JUNIORXT.rbf')
 run(['docker','run','--rm','--network','none','--entrypoint','/opt/intelFPGA/quartus/bin/quartus_sta','-v',f'{work}:/work','-w','/work',image,'JUNIORXT'],log='signoff-timing.log')
 if sha(work/'output_files/JUNIORXT.rbf')!=before:raise ValueError('Signoff changed the fitted bitstream')
 result={'fit_qsf_sha256':sha(fit),'baseline_qsf_sha256':sha(q),'removed_fitter_only_assignment':LINE,'sta_summary_sha256':sha(work/'output_files/JUNIORXT.sta.summary'),'bitstream_sha256':before}
 (work/'signoff.json').write_text(json.dumps(result,indent=2)+'\n')
def main():
 out=ROOT/'build/quartus-JUNIORXT';image=json.loads((DOCS/'dependencies.lock.json').read_text())['quartus_image']
 with tempfile.TemporaryDirectory(prefix='juniorxt-signoff-') as folder:
  work=Path(folder);shutil.copytree(out,work,dirs_exist_ok=True)
  try:
   signoff(work,image)
   for name in ['JUNIORXT.qsf','JUNIORXT.fit.qsf','signoff.json']:shutil.copy2(work/name,out/name)
   shutil.copytree(work/'output_files',out/'output_files',dirs_exist_ok=True)
  finally:run(['docker','run','--rm','--network','none','--entrypoint','/bin/chown','-v',f'{work}:/cleanup',image,'-R',f'{os.getuid()}:{os.getgid()}','/cleanup'])
 from validate_quartus import validate
 validate()
if __name__=='__main__':main()
