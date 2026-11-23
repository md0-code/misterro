"""Package current FPGA and native-runtime proofs with standalone sources."""
from pathlib import Path,PurePosixPath
import hashlib,json,posixpath,re,subprocess,zipfile
import assets

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main(root,shared,current):
 build=root/'build';doc=assets.docs(root);profile=json.loads((root/'mister/profile.json').read_text());name=profile['name'];assets.verify(root)
 fpga=json.loads((build/'fpga-validation.json').read_text());runtime=json.loads((build/'runtime-validation.json').read_text());rbf=build/f'quartus-{name}/output_files/{name}.rbf'
 native={k:v for k,v in current.items() if not k.startswith('mister/') or k=='mister/profile.json'}
 if fpga['status']!='passed' or fpga['inputs']!=current or runtime['status']!='passed' or runtime['inputs']!=native:raise ValueError('Run current FPGA and native hardware checks before packaging')
 if fpga['rbf_sha256']!=sha(rbf) or fpga['minimum_constrained_slack_ns']<0:raise ValueError('Unverified FPGA output')
 if runtime['assets']!=json.loads((doc/'sources.lock.json').read_text()):raise ValueError('Assets changed after native tests')
 for src,expected in runtime['runtime_sources'].items():
  if sha(assets.source(root,src))!=expected:raise ValueError('Native runtime input changed: '+src)
 for src,expected in runtime['tools'].items():
  if sha(shared/src)!=expected:raise ValueError('Verification tool changed after tests: '+src)
 sim=runtime['simulator']
 if sim['binary_sha256']!=sha(root/sim['binary']):raise ValueError('Simulator changed after tests')
 for src,expected in sim['harness'].items():
  if sha(shared/src)!=expected:raise ValueError('Simulation changed after tests: '+src)
 if name=='TIMS':
  adapter=json.loads((build/'adapter-validation.json').read_text())
  if adapter['status']!='passed' or any(sha(root/src)!=expected for src,expected in adapter['inputs'].items()):raise ValueError('TIMS cassette adapter check is stale')
 unit=json.loads((build/'unit-validation.json').read_text())
 if unit['status']!='passed' or any(sha(shared/src)!=expected for src,expected in unit['sources'].items()):raise ValueError('Shared peripheral validation is stale')
 source_readme=build/'source-readme.md';release_readme=build/'release-readme.md';guide=(doc/'README.md').read_text()
 for target in ['hardware.md','provenance.md','validation.md']:guide=guide.replace(']('+target+')','](docs/'+target+')')
 source_readme.write_text(guide.replace('python src/shared/romanian/tools/','python shared/romanian/tools/'));release_readme.write_text(guide.replace('## Build\n','## Build\n\nThe standalone project is in `source/`. Enter that directory before building.\n').replace('python src/shared/romanian/tools/','python source/shared/romanian/tools/'))
 files={'_Computer/'+name+'.rbf':rbf,'README.md':release_readme,'games/'+name+'/boot.rom':root/'assets/roms/boot.rom'}
 bundles=json.loads((doc/'bundles.json').read_text());lock=json.loads((doc/'sources.lock.json').read_text())
 # One model: its files sit directly in games/<core>/; several: one folder each.
 for model,bundle in bundles.items():
  folder=f'games/{name}/' if len(bundles)==1 else f'games/{name}/{model}/'
  receipt={'model':model,'scope':bundle['scope'],'labels':bundle.get('labels',{}),'files':{}}
  for target,src in bundle['files'].items():
   if PurePosixPath(target).is_absolute() or '..' in PurePosixPath(target).parts:raise ValueError('Unsafe bundle name')
   path=assets.source(root,src);files[folder+target]=path;receipt['files'][target]={'source':src,**lock[src]}
  directory=build/'bundles'/model;directory.mkdir(parents=True,exist_ok=True);manifest=directory/'bundle.json';manifest.write_text(json.dumps(receipt,indent=2)+'\n');files[folder+'bundle.json']=manifest
 for folder in ['rtl','mister','tools','assets','sim','software']:
  if (root/folder).exists():
   for path in sorted((root/folder).rglob('*')):
    if path.is_file() and '__pycache__' not in path.parts:files['source/'+path.relative_to(root).as_posix()]=path
 for path in sorted(shared.rglob('*')):
  if path.is_file() and '__pycache__' not in path.parts:files['source/shared/romanian/'+path.relative_to(shared).as_posix()]=path
 for path in sorted(doc.rglob('*')):
  if path.is_file() and path.name!='PLAN.md' and '__pycache__' not in path.parts and not any(x in path.relative_to(doc).parts for x in ['reference','analysis']):
   rel=path.relative_to(doc).as_posix();files['source/docs/'+rel]=path
   if not rel.startswith(('reference/','bundled/')):files['docs/'+rel]=path
 up=root/'vendor/spectrum'
 if not up.exists():up=root.parent/'core-hc/vendor/spectrum'
 vendor={}
 for folder in ['sys','rtl']:
  for path in sorted((up/folder).rglob('*')):
   if path.is_file():vendor[path.relative_to(up).as_posix()]=path
 for rel in ['ZX-Spectrum.qsf','README.md','releases/boot.rom','releases/dsdd720k.dsk.gz']:
  vendor[rel]=up/rel
 for path in up.iterdir():
  if path.is_file() and any(word in path.name.lower() for word in ['license','copying']):vendor[path.name]=path
 manifest=build/'vendor-export-sha256.json';manifest.write_text(json.dumps({n:sha(p) for n,p in vendor.items()},indent=2)+'\n')
 files.update({'source/vendor/spectrum/'+n:p for n,p in vendor.items()});files['source/vendor/spectrum/export-sha256.json']=manifest;files['source/README.md']=source_readme;files['source/.gitignore']=root/'.gitignore'
 for proof in ['runtime-validation.json','unit-validation.json','tape-validation.json','adapter-validation.json','timer-decoder-validation.json','fdc-validation.json','fpga-validation.json']:
  if (build/proof).exists():files['docs/'+proof]=build/proof
 links=0
 for member,path in files.items():
  if not member.endswith('.md') or member.startswith('source/vendor/'):continue
  for target in re.findall(r'\]\(([^)]+)\)',path.read_text()):
   if '://' in target or target.startswith(('mailto:','#')):continue
   target=target.split('#',1)[0]
   resolved=posixpath.normpath(str(PurePosixPath(member).parent/target))
   if resolved not in files:raise ValueError('Broken package documentation link: '+member+' -> '+target)
   links+=1
 sums={n:sha(p) for n,p in files.items()};output=root/'dist'/(name+'.zip');output.parent.mkdir(exist_ok=True)
 with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for n,p in sorted(files.items()):
   entry=zipfile.ZipInfo(n,(1980,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o644<<16;z.writestr(entry,p.read_bytes())
  z.writestr('SHA256SUMS',''.join(f'{h}  {n}\n' for n,h in sorted(sums.items())))
 archive_sha=sha(output);export=build/'package-check'/archive_sha;export.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(output) as z:
  if z.testzip():raise ValueError('ZIP integrity failure')
  for n,expected in sums.items():
   data=z.read(n)
   if hashlib.sha256(data).hexdigest()!=expected:raise ValueError('Package checksum mismatch: '+n)
   if n.startswith('source/'):
    target=export.joinpath(*PurePosixPath(n).parts)
    if export.resolve() not in target.resolve().parents:raise ValueError('Unsafe source export')
    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
 for action in ['assets','lint']:subprocess.run(['python3','tools/build.py',action],cwd=export/'source',check=True)
 output.with_suffix('.zip.sha256').write_text(archive_sha+'  '+output.name+'\n')
 (build/'package-validation.json').write_text(json.dumps({'status':'passed','zip_sha256':archive_sha,'members':len(sums),'documentation_links':links,'inputs':current,'source_export':str(export/'source'),'offline_checks':['immutable assets','native HDL elaboration'],'rbf_sha256':sha(rbf)},indent=2)+'\n');print('PASS verified package',output,output.stat().st_size,archive_sha)
