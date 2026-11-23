"""Validate and collect the files installed alongside each computer core."""
from pathlib import Path,PurePosixPath
import hashlib,json
from project_paths import ROOT,DOCS,source_path

def validate_tzx(data):
    if len(data)<10 or data[:8]!=b'ZXTape!\x1a':raise ValueError('Invalid TZX header')
    pos=10;blocks=0
    while pos<len(data):
        kind=data[pos];pos+=1
        def take(n):
            nonlocal pos
            if n<0 or pos+n>len(data):raise ValueError('Truncated TZX block')
            part=data[pos:pos+n];pos+=n;return part
        if kind==0x10:
            header=take(4);block=take(int.from_bytes(header[2:4],'little'))
            if len(block)<2:raise ValueError('Empty tape recording')
            checksum=0
            for byte in block:checksum^=byte
            if checksum:raise ValueError('Tape recording checksum failed')
            blocks+=1
        elif kind==0x20:take(2)
        elif kind==0x30:take(take(1)[0])
        elif kind==0x32:take(int.from_bytes(take(2),'little'))
        elif kind==0x33:take(3*take(1)[0])
        elif kind==0x35:take(int.from_bytes(take(20)[16:20],'little'))
        else:raise ValueError(f'Unsupported bundled tape block: {kind:02x}')
    if not blocks:raise ValueError('Tape contains no recordings')
    return blocks

FAMILY='HC'

def collect(models=None):
    bundles=json.loads((DOCS/'bundles.json').read_text())
    lock=json.loads((DOCS/'sources.lock.json').read_text())
    files={}
    for model,bundle in bundles.items():
        if models is not None and model not in models:continue
        names=bundle['files']
        if not {'boot.rom','demo.tzx'}<=names.keys():
            raise ValueError(f'Incomplete bundle: {model}')
        if any(n.endswith('.pdf') for n in names):
            raise ValueError(f'Scans are not bundled: {model}')
        receipt={'model':model,'scope':bundle['scope'],'files':{}}
        for name,source in names.items():
            if PurePosixPath(name).is_absolute() or '..' in PurePosixPath(name).parts or '\\' in name:raise ValueError(f'Invalid bundle filename: {name}')
            entry=lock[source];path=source_path(source);data=path.read_bytes()
            if len(data)!=entry['bytes'] or hashlib.sha256(data).hexdigest()!=entry['sha256']:
                raise ValueError(f'Bundle checksum mismatch: {source}')
            if name.endswith('.tzx') and (not data.startswith(b'ZXTape!\x1a') or len(data)>262144):
                raise ValueError(f'Invalid or oversized tape: {source}')
            files[f'games/{FAMILY}/{model}/{name}']=path
            origin=entry.get('url') or lock.get(entry.get('from'),{}).get('url')
            receipt['files'][name]={'sha256':entry['sha256'],'bytes':len(data),'source':source}
            if name.endswith('.tzx'):receipt['files'][name]['recording_blocks']=validate_tzx(data)
            if origin:receipt['files'][name]['url']=origin
            if name in bundle.get('labels',{}):receipt['files'][name]['label']=bundle['labels'][name]
        out=ROOT/'build/bundles'/model;out.mkdir(parents=True,exist_ok=True)
        manifest=out/'bundle.json';manifest.write_text(json.dumps(receipt,indent=2)+'\n')
        files[f'games/{FAMILY}/{model}/bundle.json']=manifest
    boot=source_path('assets/roms/family.rom')
    entry=lock['assets/roms/family.rom']
    if hashlib.sha256(boot.read_bytes()).hexdigest()!=entry['sha256']:raise ValueError('Wrong combined family firmware')
    files[f'games/{FAMILY}/boot.rom']=boot
    manifest=ROOT/'build/bundles'/f'{FAMILY}.json'
    manifest.write_text(json.dumps({'family':FAMILY,'models':list(bundles),'firmware':entry,'scope':'One core with runtime model selection; the firmware, tapes and disks of each model are in its named subfolder.'},indent=2)+'\n')
    files[f'games/{FAMILY}/bundle.json']=manifest
    return files

def source_files():
    bundles=json.loads((DOCS/'bundles.json').read_text())
    lock=json.loads((DOCS/'sources.lock.json').read_text())
    names={'assets/roms/family.rom'}|{source for b in bundles.values() for source in b['files'].values()}|{name for name in lock if name.startswith('assets/roms/') and not name.endswith('.zip')}
    return {'source/'+source:source_path(source) for source in names}

if __name__=='__main__':
    for name,path in collect().items():print(name,path.stat().st_size)
