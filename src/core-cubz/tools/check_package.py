"""Verify ZIP hashes, standardized media, and the usable standalone source export."""
from project_paths import ROOT
import hashlib,json,subprocess,sys,tempfile,zipfile

def main():
 package=ROOT/'dist/CUBZ.zip';digest=hashlib.sha256(package.read_bytes()).hexdigest()
 if digest!=package.with_suffix('.zip.sha256').read_text().split()[0]:raise ValueError('Package checksum mismatch')
 with zipfile.ZipFile(package) as z:
  expected={n:h for h,n in (line.split('  ',1) for line in z.read('SHA256SUMS').decode().splitlines())}
  if set(z.namelist())!=set(expected)|{'SHA256SUMS'}:raise ValueError('Manifest membership mismatch')
  for n,h in expected.items():
   if n.startswith('/') or '..' in __import__('pathlib').PurePosixPath(n).parts or hashlib.sha256(z.read(n)).hexdigest()!=h:raise ValueError('Unsafe or corrupt member: '+n)
  required={'boot.rom','firmware-v13.rom','demo.dsk','bundle.json','support/keyboard.bin','support/sync-h.bin','support/sync-v.bin'}
  if {n[len('games/CUBZ/'):] for n in expected if n.startswith('games/CUBZ/')}!=required:raise ValueError('Incomplete installation media')
  if len(z.read('games/CUBZ/boot.rom'))!=8192 or not z.read('games/CUBZ/demo.dsk').startswith(b'EXTENDED CPC DSK File'):raise ValueError('Wrong native software')
  with tempfile.TemporaryDirectory(prefix='cubz-source-check-') as folder:
   z.extractall(folder);source=__import__('pathlib').Path(folder)/'source'
   # No dependency checkout or network access is needed for the included source.
   subprocess.run([sys.executable,'-B','tools/prepare_assets.py'],cwd=source,check=True)
   subprocess.run([sys.executable,'-B','tools/test_units.py'],cwd=source,check=True)
   subprocess.run([sys.executable,'-B','tools/build.py','lint'],cwd=source,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
 result={'status':'passed','zip_sha256':digest,'files':len(expected),'checks':['all ZIP members hashed','native firmware and EDSK signature','one demo disk and support PROMs','standalone original-asset reproduction','standalone interface units and complete CPU/RTL lint']}
 (ROOT/'build/package-validation.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS: complete package and standalone source export')
if __name__=='__main__':main()
