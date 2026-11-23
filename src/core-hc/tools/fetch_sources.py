"""Restore checksum-locked HC manuals, schematics, firmware and cassette media."""
from pathlib import Path
import argparse,hashlib,json,shutil,urllib.parse,urllib.request,zipfile,subprocess,sys
from project_paths import ROOT,DOCS,source_path

def get(url):
    request=urllib.request.Request(urllib.parse.quote(url,safe=':/?=&%'),headers={'User-Agent':'Mozilla/5.0'})
    with urllib.request.urlopen(request,timeout=120) as response:return response.read()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--local-schematics',type=Path,help='Optional original HC85 schematic scan')
    args=p.parse_args()
    lock=json.loads((DOCS/'sources.lock.json').read_text())
    for name,entry in lock.items():
        target=source_path(name);target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists() and 'url' in entry:
            if name=='docs/reference/hc85/schematic.pdf' and args.local_schematics:
                shutil.copyfile(args.local_schematics,target)
            else:target.write_bytes(get(entry['url']))
        if not target.exists() and 'from_binary' in entry:
            offset=entry.get('offset',0);target.write_bytes(source_path(entry['from_binary']).read_bytes()[offset:offset+entry['bytes']])
        if not target.exists() and 'parts' in entry:
            target.write_bytes(b''.join(source_path(part).read_bytes() for part in entry['parts']))
        if not target.exists() and 'generated_by' in entry:
            subprocess.run([sys.executable,ROOT/entry['generated_by']],cwd=ROOT,check=True)
        if not target.exists() and 'from' in entry:
            with zipfile.ZipFile(source_path(entry['from'])) as z:
                entries=[n for n in z.namelist() if z.getinfo(n).file_size==entry['bytes']]
                if 'member' not in entry and len(entries)!=1:raise ValueError(f'Ambiguous firmware archive: {name}')
                target.write_bytes(z.read(entry.get('member',entries[0])))
        data=target.read_bytes()
        if len(data)!=entry['bytes'] or hashlib.sha256(data).hexdigest()!=entry['sha256']:
            raise ValueError(f'Source checksum mismatch: {name}')
        if 'sha1' in entry and hashlib.sha1(data).hexdigest()!=entry['sha1']:
            raise ValueError(f'Firmware identity mismatch: {name}')
        if name.endswith('.pdf') and not data.startswith(b'%PDF-'):raise ValueError(f'Not a PDF: {name}')
        if name.endswith('.tzx') and not data.startswith(b'ZXTape!\x1a'):raise ValueError(f'Not a TZX: {name}')
        if name.endswith('.rom'):
            target.with_suffix('.hex').write_text(''.join(f'{b:02x}\n' for b in data),encoding='ascii')
        print(name,len(data),entry['sha256'])
if __name__=='__main__':main()
