"""Verify the firmware and media and retrieve immutable original source archives."""
from pathlib import Path
import hashlib,json,urllib.request,urllib.parse

def docs(root):return root/'docs' if (root/'docs/dependencies.lock.json').exists() else root.parent.parent/'docs'/root.name[5:]
def source(root,name):return docs(root)/name[5:] if name.startswith('docs/') else root/name
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def verify(root):
 lock=json.loads((docs(root)/'sources.lock.json').read_text())
 for name,entry in lock.items():
  p=source(root,name)
  if not p.is_file() or p.stat().st_size!=entry['bytes'] or sha(p)!=entry['sha256']:raise ValueError('Asset missing or changed: '+name)
 for model,bundle in json.loads((docs(root)/'bundles.json').read_text()).items():
  files=bundle['files'];names=set(files)
  if len([n for n in names if n.startswith('demo.')])!=1 or any(n.endswith('.pdf') for n in names):raise ValueError('Incomplete model bundle: '+model)
  for name,src in files.items():
   data=source(root,src).read_bytes()
   if name.endswith(('.tap','.pzx','.tzx')) and (len(data)>262144 or len(data)<10):raise ValueError('Invalid cassette size: '+name)
   if name.endswith('.tap'):
    at=0
    while at<len(data):
     size=int.from_bytes(data[at:at+2],'little');at+=2
     if size<2 or at+size>len(data):raise ValueError('Invalid TAP block: '+name)
     checksum=0
     for value in data[at:at+size]:checksum^=value
     if checksum:raise ValueError('Invalid TAP checksum: '+name)
     at+=size
   if name.endswith('.pzx'):
    if not data.startswith(b'PZXT'):raise ValueError('Invalid PZX signature: '+name)
    at=0
    while at<len(data):
     if at+8>len(data):raise ValueError('Truncated PZX chunk: '+name)
     size=int.from_bytes(data[at+4:at+8],'little');at+=8+size
     if at>len(data):raise ValueError('Invalid PZX chunk: '+name)

 primary=docs(root)/'primary-sources.json'
 if primary.exists():
  for entry in json.loads(primary.read_text()):
   path=source(root,entry['path'])
   if path.exists() and sha(path)!=entry['sha256']:raise ValueError('Original source changed: '+entry['path'])
 print('PASS immutable firmware and media')
def fetch(root):
 primary=docs(root)/'primary-sources.json'
 for entry in json.loads(primary.read_text()):
  path=source(root,entry['path'])
  if path.exists():continue
  request=urllib.request.Request(urllib.parse.quote(entry['url'],safe=':/?=&%'),headers={'User-Agent':'Mozilla/5.0'})
  data=urllib.request.urlopen(request,timeout=90).read()
  if hashlib.sha256(data).hexdigest()!=entry['sha256']:raise ValueError('Remote source changed: '+entry['path'])
  path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 verify(root)
