"""Standardized CUB Z installation media and provenance."""
from project_paths import ROOT,DOCS
import hashlib,json

def collect():
 files={'boot.rom':ROOT/'assets/roms/cubz-v14.rom','firmware-v13.rom':ROOT/'assets/roms/cubz-v13.rom',
 'demo.dsk':ROOT/'assets/disks/cpm.dsk'}
 for name in ['keyboard.bin','sync-h.bin','sync-v.bin']:files['support/'+name]=ROOT/'assets/roms'/name
 entries=json.loads((DOCS/'sources.lock.json').read_text());manifest={'machine':'CUB Z','firmware':'Original v1.4; original v1.3 selectable by loading firmware-v13.rom','demo':'Original CP/M floppy disk; CUB Z has no cassette interface','files':{}}
 for name,p in files.items():
  key='docs/'+p.relative_to(DOCS).as_posix() if DOCS in p.parents else p.relative_to(ROOT).as_posix();e=entries[key]
  manifest['files'][name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size,'source':e}
  if manifest['files'][name]['sha256']!=e['sha256']:raise ValueError('Bundle source changed: '+name)
 out=ROOT/'build/bundle.json';out.write_text(json.dumps(manifest,indent=2)+'\n');files['bundle.json']=out
 return {'games/CUBZ/'+n:p for n,p in files.items()}
