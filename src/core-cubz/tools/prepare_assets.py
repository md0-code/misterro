"""Reproduce derived firmware bytes from the locked original EPROM archives."""
from project_paths import ROOT,DOCS,source_path
import hashlib,json,zipfile

def main():
 entries=json.loads((DOCS/'sources.lock.json').read_text())
 for name,e in entries.items():
  path=source_path(name)
  if 'from' in e:
   with zipfile.ZipFile(source_path(e['from'])) as z:data=z.read(e['member'])
   path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
  elif 'generated' in e:
   data=b'\xc3\x3f\xf8'+b'\xff'*2045+b''.join(source_path(n).read_bytes() for n in e['inputs']);path.write_bytes(data)
  else:data=path.read_bytes()
  if len(data)!=e['bytes'] or hashlib.sha256(data).hexdigest()!=e['sha256']:raise ValueError('Checksum mismatch: '+name)
 (ROOT/'build').mkdir(exist_ok=True)
 for rev in ['v13','v14']:
  b=(ROOT/f'assets/roms/cubz-{rev}.rom').read_bytes();(ROOT/f'build/{rev}.hex').write_text(''.join(f'{x:02x}\n' for x in b))
 print('PASS: all original and derived CUB Z assets')
if __name__=='__main__':main()
