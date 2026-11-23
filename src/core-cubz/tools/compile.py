"""Compile on WSL storage, then return and validate the complete result."""
from project_paths import ROOT,DOCS
from prepare_quartus import main,OUT
from validate_quartus import validate,source_hashes
from cpu import run
import json,os,shutil,tempfile
main();image=json.loads((DOCS/'dependencies.lock.json').read_text())['quartus_image'];original=source_hashes()
with tempfile.TemporaryDirectory(prefix='mister-cubz-quartus-') as folder:
 work=__import__('pathlib').Path(folder)
 shutil.copytree(OUT,work,dirs_exist_ok=True,ignore=shutil.ignore_patterns('db','incremental_db','output_files','greybox_tmp'))
 try:
  run(['docker','run','--rm','--network','none','--entrypoint','/opt/intelFPGA/quartus/bin/quartus_sh','-v',f'{work}:/work','-w','/work',image,'--flow','compile','CUBZ'],log='quartus-build.log')
 finally:
  changed=source_hashes()!=original
  if not changed:shutil.copytree(work,OUT,dirs_exist_ok=True)
  run(['docker','run','--rm','--network','none','--entrypoint','/bin/chown','-v',f'{work}:/cleanup',image,'-R',f'{os.getuid()}:{os.getgid()}','/cleanup'])
  if changed:raise ValueError('Hardware sources changed during compilation')
validate()
