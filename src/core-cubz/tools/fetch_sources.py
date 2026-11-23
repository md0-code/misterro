"""Download and verify the original CUB Z firmware, CP/M disk and reference documents."""
from pathlib import Path
import concurrent.futures,hashlib,json,urllib.parse,urllib.request,zipfile
from project_paths import ROOT,DOCS,source_path

def fetch(item):
    name,entry=item;path=source_path(name);path.parent.mkdir(parents=True,exist_ok=True)
    if not path.exists():
        request=urllib.request.Request(urllib.parse.quote(entry['url'],safe=':/?=&%'),headers={'User-Agent':'Mozilla/5.0'})
        with urllib.request.urlopen(request,timeout=90) as response:path.write_bytes(response.read())
    data=path.read_bytes();digest=hashlib.sha256(data).hexdigest()
    if 'sha256' in entry and (digest!=entry['sha256'] or len(data)!=entry['bytes']):raise ValueError('Source checksum changed: '+name)
    if name.endswith('.pdf') and not data.startswith(b'%PDF-'):raise ValueError('Not a PDF: '+name)
    return name,dict(entry,sha256=digest,bytes=len(data))

def main():
    lock=DOCS/'sources.lock.json';entries=json.loads(lock.read_text())
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:result=dict(pool.map(fetch,((n,e) for n,e in entries.items() if "url" in e)))
    entries.update(result);lock.write_text(json.dumps(entries,indent=2)+'\n')
    for name,entry in result.items():print(name,entry['bytes'],entry['sha256'])
    for path in sorted((ROOT/'assets/roms').glob('*.zip')):
        with zipfile.ZipFile(path) as z:print(path.name,[(n,z.getinfo(n).file_size) for n in z.namelist()])
if __name__=='__main__':main()
