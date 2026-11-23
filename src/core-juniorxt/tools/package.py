"""Package verified hardware, native firmware/media and complete standalone source."""
from project_paths import ROOT,DOCS,export_readme
from validate_quartus import validate,source_hashes
from test_runtime import harness_hashes
from bundles import collect
import hashlib,json,zipfile

def main():
 validate();proof=json.loads((ROOT/'build/runtime-validation.json').read_text())
 if proof['status']!='passed' or proof['project_sources']!=source_hashes() or proof['harness_sha256']!=harness_hashes():raise ValueError('Run current native runtime acceptance')
 if proof['media_sha256']!=hashlib.sha256((ROOT/'assets/demo.img').read_bytes()).hexdigest():raise ValueError('Demo disk changed after validation')
 files={'_Computer/JUNIORXT.mgl':ROOT/'mister/JUNIORXT.mgl','_Computer/.JUNIORXT/JUNIORXT.rbf':ROOT/'build/quartus-JUNIORXT/output_files/JUNIORXT.rbf','README.md':export_readme()};files.update(collect())
 for directory in ['rtl','mister','tools','sim','software','assets']:
  for p in sorted((ROOT/directory).rglob('*')):
   if p.is_file() and '__pycache__' not in p.parts:files['source/'+p.relative_to(ROOT).as_posix()]=p
 for p in sorted(DOCS.rglob('*')):
  if p.is_file() and p.name not in ['PLAN.md','deployment.md'] and not any(x in ['analysis','reference'] for x in p.relative_to(DOCS).parts):
   files['docs/'+p.relative_to(DOCS).as_posix()]=p;files['source/docs/'+p.relative_to(DOCS).as_posix()]=p
 for p in (DOCS/'reference').iterdir():
  if p.is_file():files['source/docs/reference/'+p.name]=p
 for folder in ['sys','rtl','platform','profiles','scripts','vendor']:
  for p in sorted((ROOT/'vendor/pcxt'/folder).rglob('*')):
   if p.is_file() and '.git' not in p.parts:files['source/vendor/pcxt/'+p.relative_to(ROOT/'vendor/pcxt').as_posix()]=p
 for name in ['PCXT.sv','PCXT.qsf','files.qip','SYSTEM.sdc','README.md','LICENSE']:files['source/vendor/pcxt/'+name]=ROOT/'vendor/pcxt'/name
 files['source/README.md']=export_readme()
 for name in ['runtime-validation.json','fpga-validation.json','hardware-validation.json','serial-test.log']:files['docs/'+name]=ROOT/'build'/name
 for name in ['first','persist']:files['docs/native-'+name+'.log']=ROOT/'build'/('acceptance-'+name+'.log')
 for src,name in [('JUNIORXT.fit.qsf','fpga-fitting.qsf'),('JUNIORXT.qsf','fpga-signoff.qsf'),('implementation-margin.sdc','fitter-margin.sdc'),('signoff.json','fpga-signoff.json'),('output_files/JUNIORXT.sta.summary','fpga-timing.summary')]:files['docs/'+name]=ROOT/'build/quartus-JUNIORXT'/src
 sums={n:hashlib.sha256(p.read_bytes()).hexdigest() for n,p in files.items()}
 out=ROOT/'dist/JUNIORXT.zip';out.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
  for n,p in sorted(files.items()):z.write(p,n)
  z.writestr('SHA256SUMS',''.join(f'{h}  {n}\n' for n,h in sorted(sums.items())))
 with zipfile.ZipFile(out) as z:
  if z.testzip():raise ValueError('Corrupt ZIP')
  for n,h in sums.items():
   if hashlib.sha256(z.read(n)).hexdigest()!=h:raise ValueError('ZIP checksum failure: '+n)
 out.with_suffix('.zip.sha256').write_text(hashlib.sha256(out.read_bytes()).hexdigest()+'  '+out.name+'\n');print('PASS:',len(files),'packaged files',out)
if __name__=='__main__':main()
