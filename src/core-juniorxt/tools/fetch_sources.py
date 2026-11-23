from project_paths import DOCS
import hashlib,json,urllib.request,urllib.parse
ref=DOCS/'reference';ref.mkdir(parents=True,exist_ok=True)
sources=json.loads((DOCS/'sources.lock.json').read_text())
extra=DOCS/'software-sources.lock.json'
if extra.is_file():sources.update(json.loads(extra.read_text()))
for name,v in sources.items():
 p=ref/name
 if p.exists() and hashlib.sha256(p.read_bytes()).hexdigest()==v['sha256']:continue
 req=urllib.request.Request(urllib.parse.quote(v['url'],safe=':/?=&%'),headers={'User-Agent':'Mozilla/5.0'})
 data=urllib.request.urlopen(req,timeout=120).read()
 if len(data)!=v['bytes'] or hashlib.sha256(data).hexdigest()!=v['sha256']:raise ValueError('Source checksum mismatch: '+name)
 p.write_bytes(data)
print('PASS: original sources fetched and verified')
