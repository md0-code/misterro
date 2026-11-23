"""Fetch CIP-01 references and reconstruct a checksum-verified tape from CipBas.mp3."""
from project_paths import DOCS,README,PLAN,source_path,export_readme
from pathlib import Path
import argparse, functools, hashlib, json, shutil, struct, subprocess, urllib.parse, urllib.request, wave, zipfile
ROOT=Path(__file__).resolve().parents[1]
BASE='https://www.z80-romania.ro'
def get(url):
    request=urllib.request.Request(urllib.parse.quote(url,safe=':/?=&%'),headers={'User-Agent':'Mozilla/5.0'})
    return urllib.request.urlopen(request,timeout=120).read()
def decode(samples,threshold):
    pulses=[];state=False;last=0
    for i,value in enumerate(samples):
        if (not state and value>threshold) or (state and value < -threshold):
            pulses.append(i-last);last=i;state=not state
    blocks=[];i=0
    while i<len(pulses):
        if not 25<=pulses[i]<=30:i+=1;continue
        j=i
        while j<len(pulses) and 25<=pulses[j]<=30:j+=1
        if j-i<100:i=j;continue
        pilot=j-i;i=j
        if max(pulses[i:i+2])>12:raise ValueError('Missing two sync pulses')
        i+=2
        bits=[]
        while i+1<len(pulses) and max(pulses[i:i+2])<40:
            a,b=pulses[i:i+2]
            if (a>16)!=(b>16):raise ValueError(f'Ambiguous pulse pair {i}: {a},{b}')
            bits.append(int(a+b>32));i+=2
        data=bytes(sum(bits[j+k]<<(7-k) for k in range(8)) for j in range(0,len(bits)-7,8))
        if not data or functools.reduce(int.__xor__,data,0):raise ValueError('Tape block checksum failed')
        blocks.append((pilot,data))
    if len(blocks)!=2 or len(blocks[0][1])!=19 or blocks[0][1][:2]!=b'\x00\x03':raise ValueError('Expected CODE header and data')
    size=int.from_bytes(blocks[0][1][12:14],'little');address=int.from_bytes(blocks[0][1][14:16],'little')
    if address!=0 or len(blocks[1][1])!=size+2 or blocks[1][1][0]!=255:raise ValueError('Unexpected BASIC load address/size')
    return blocks
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mp3',type=Path,default=Path(r'C:\emus\zxs\content\temp\CipBas.mp3'))
    args=parser.parse_args()
    urls={
        'assets/roms/cip01.zip':BASE+'/files/34/CIP-01%20%281988%29%28Electronica%29.rom.zip?1682208584',
        'assets/roms/proms.zip':BASE+'/files/34/PROM-uri%20CIP.zip',
        'docs/reference/schematics.pdf':BASE+'/files/34/Schema%20electrica%CC%86%20CIP%20%281989%29%28Electronica%29%5B600dpi-Color%5D.pdf?1688590338',
        'docs/reference/common/manual.pdf':BASE+'/files/157/Manual de utilizare CIP (1989)(Electronica)(RO)[600dpi-Alb-Negru].pdf?1688591153',
        'assets/roms/cip03.zip':BASE+'/files/63/CIP-03%20%281988%29%28Electronica%29.rom.zip?1722424361',
        'assets/roms/cip04.zip':BASE+'/files/96/CIP-04%20%281993%29%28Electronica%29.rom.zip?1770404383',
        'docs/reference/cip03/manual.pdf':BASE+'/files/156/Manual de utilizare CIP-03 (1992)(Electronica)(RO)[600dpi-Alb-Negru].pdf?1688053834',
    }
    lock=DOCS/'sources.lock.json';old=json.loads(lock.read_text()) if lock.exists() else {};manifest=dict(old)
    urls.update({name:entry['url'] for name,entry in old.items() if 'url' in entry})
    for name,url in urls.items():
        path=source_path(name);path.parent.mkdir(parents=True,exist_ok=True)
        if not path.exists():path.write_bytes(get(url))
        manifest[name]={'url':url,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size}
    with zipfile.ZipFile(ROOT/'assets/roms/cip01.zip') as z:
        names=[n for n in z.namelist() if z.getinfo(n).file_size==2048]
        if len(names)!=1:raise ValueError('Expected one 2 KiB bootstrap ROM')
        rom=z.read(names[0])
    (ROOT/'assets/roms/cip01.rom').write_bytes(rom)
    (ROOT/'assets/roms/cip01.hex').write_text(''.join(f'{b:02x}\n' for b in rom))
    with zipfile.ZipFile(ROOT/'assets/roms/cip03.zip') as z:
        names=[n for n in z.namelist() if z.getinfo(n).file_size==16384]
        if len(names)!=1:raise ValueError('Expected one 16K CIP-03 ROM')
        basic=z.read(names[0])
    (ROOT/'assets/roms/cip03.rom').write_bytes(basic)
    bundle=rom+basic
    (ROOT/'assets/roms/resident.rom').write_bytes(bundle)
    (ROOT/'assets/roms/resident.hex').write_text(''.join(f'{b:02x}\n' for b in bundle))
    with zipfile.ZipFile(ROOT/'assets/roms/cip04.zip') as z:
        names=[n for n in z.namelist() if z.getinfo(n).file_size==65536]
        if len(names)!=1:raise ValueError('Expected one combined 64K CIP-04 ROM')
        combined=z.read(names[0])
        banks=[z.read(next(n for n in z.namelist() if n.startswith(f'CIP-04-{i} '))) for i in range(4)]
        if b''.join(banks)!=combined:raise ValueError('CIP-04 combined ROM does not match four separate banks')
    (ROOT/'assets/roms/cip04.rom').write_bytes(combined)
    tape=ROOT/'assets/tapes';tape.mkdir(parents=True,exist_ok=True);mp3=tape/'CipBas.mp3'
    if not mp3.exists():shutil.copyfile(args.mp3,mp3)
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(mp3),'-ac','1','-ar','44100','-c:a','pcm_s16le',str(tape/'CipBas.wav')],check=True)
    with wave.open(str(tape/'CipBas.wav'),'rb') as w:samples=struct.unpack('<'+'h'*w.getnframes(),w.readframes(w.getnframes()))
    blocks=decode(samples,2500)
    for threshold in [1500,3500,4500]:
        if [d for _,d in decode(samples,threshold)]!=[d for _,d in blocks]:raise ValueError('Audio thresholds disagree')
    # The CPU reads every regenerated pulse through EAR. No byte trap or RAM preload.
    tzx=b'ZXTape!\x1a\x01\x14'
    for _,data in blocks:tzx+=b'\x10'+struct.pack('<HH',1000,len(data))+data
    (tape/'basic.tzx').write_bytes(tzx);(ROOT/'build').mkdir(exist_ok=True)
    (ROOT/'build/expected-basic.bin').write_bytes(blocks[1][1][1:-1])
    for name in ['assets/roms/cip01.rom','assets/roms/cip03.rom','assets/roms/resident.rom',
                 'assets/roms/cip04.rom','assets/tapes/CipBas.mp3','assets/tapes/basic.tzx']:
        p=ROOT/name;manifest[name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
    for name,entry in old.items():
        if name in manifest and entry['sha256']!=manifest[name]['sha256']:raise ValueError(f'Changed source: {name}')
    family=(ROOT/'assets/roms/resident.rom').read_bytes()+(ROOT/'assets/roms/cip04.rom').read_bytes()
    (ROOT/'assets/roms/family.rom').write_bytes(family)
    manifest['assets/roms/family.rom']={'parts':['assets/roms/resident.rom','assets/roms/cip04.rom'],'sha256':hashlib.sha256(family).hexdigest(),'bytes':len(family)}
    lock.write_text(json.dumps(manifest,indent=2)+'\n')
    evidence={'source_mp3_sha256':manifest['assets/tapes/CipBas.mp3']['sha256'],'sample_rate':44100,
        'thresholds':[1500,2500,3500,4500],'blocks':[{'pilot_pulses':n,'bytes':len(d),'xor_checksum':0} for n,d in blocks],
        'load_address':0,'payload_bytes':len(blocks[1][1])-2,'payload_sha256':hashlib.sha256(blocks[1][1][1:-1]).hexdigest(),
        'conversion':'Schmitt-trigger pulse decoding; checksum-verified standard TZX blocks; nominal pulse timing'}
    (DOCS/'audio-conversion.json').write_text(json.dumps(evidence,indent=2)+'\n');print(json.dumps(evidence,indent=2))
if __name__=='__main__':main()
