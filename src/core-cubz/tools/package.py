"""Package current verified hardware, native software and reproducible sources."""
from project_paths import ROOT,DOCS,export_readme
from validate_quartus import validate,source_hashes
from bundles import collect
import hashlib,json,zipfile

def main():
 validate();proof=json.loads((ROOT/'build/runtime-validation.json').read_text())
 if proof['status']!='passed' or proof['project_sources']!=source_hashes():raise ValueError('Run current native runtime tests')
 for name,digest in proof['harness_sha256'].items():
  if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest:raise ValueError('Validation harness changed: '+name)
 files={'_Computer/CUBZ.rbf':ROOT/'build/quartus-CUBZ/output_files/CUBZ.rbf','README.md':export_readme()};files.update(collect())
 for directory in ['rtl','mister','tools','sim','assets']:
  for p in sorted((ROOT/directory).rglob('*')):
   if p.is_file() and '__pycache__' not in p.parts:files['source/'+p.relative_to(ROOT).as_posix()]=p
 for p in sorted(DOCS.rglob('*')):
  if p.is_file() and p.name!='PLAN.md' and not any(x in ['analysis','reference'] for x in p.relative_to(DOCS).parts):
   files['docs/'+p.relative_to(DOCS).as_posix()]=p;files['source/docs/'+p.relative_to(DOCS).as_posix()]=p
 for name,p in collect().items():
  if name.endswith('.pdf'):files['source/docs/reference/'+name.split('/')[-1]]=p
 # All original reference sources are needed to reproduce and verify the lock.
 for p in (DOCS/'reference').iterdir():
  if p.is_file():files['source/docs/reference/'+p.name]=p
 for folder in ['sys','rtl']:
  for p in sorted((ROOT/'vendor/spectrum'/folder).rglob('*')):
   if p.is_file():files['source/vendor/spectrum/'+p.relative_to(ROOT/'vendor/spectrum').as_posix()]=p
 for name in ['ZX-Spectrum.qsf','README.md']:files['source/vendor/spectrum/'+name]=ROOT/'vendor/spectrum'/name
 files['source/README.md']=export_readme()
 for name in ['runtime-validation.json','fpga-validation.json']:files['docs/'+name]=ROOT/'build'/name
 sums={name:hashlib.sha256(p.read_bytes()).hexdigest() for name,p in files.items()}
 output=ROOT/'dist/CUBZ.zip';output.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
  for name,p in files.items():z.write(p,name)
  z.writestr('SHA256SUMS',''.join(f'{h}  {n}\n' for n,h in sorted(sums.items())))
 with zipfile.ZipFile(output) as z:
  if z.testzip():raise ValueError('Corrupt ZIP')
  for n,h in sums.items():
   if hashlib.sha256(z.read(n)).hexdigest()!=h:raise ValueError('ZIP checksum failure: '+n)
 output.with_suffix('.zip.sha256').write_text(hashlib.sha256(output.read_bytes()).hexdigest()+'  '+output.name+'\n')
 print('PASS:',len(files),'packaged files',output)
if __name__=='__main__':main()
