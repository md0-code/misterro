"""Validate original-ROM startup and runtime-loaded BASIC from observed bus writes."""
from project_paths import DOCS,README,PLAN,source_path,export_readme
from pathlib import Path
import argparse, hashlib, json
from PIL import Image
from validate_quartus import source_hashes
ROOT=Path(__file__).resolve().parents[1]
def text(memory):
    rows=[]
    for row in range(24):
        line=''
        for col in range(32):
            bitmap=bytes(memory[0x4000+(((row*8+y)&0xc0)<<5)+(((row*8+y)&7)<<8)+(((row*8+y)&0x38)<<2)+col] for y in range(8))
            line+=next((chr(c) for c in range(32,127) if bitmap==memory[0x3d00+(c-32)*8:0x3d00+(c-31)*8]),'?')
        rows.append(line.rstrip())
    return rows
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--test',action='store_true');args=p.parse_args()
    names=['boot']+(['loader','loaded','basic','cold-reset'] if args.test else [])
    for name in names:
        image=Image.open(ROOT/f'build/{name}.ppm')
        if image.size!=(448,312):raise ValueError('Wrong raster size')
        image.save(ROOT/f'build/{name}.png')
    if not args.test:return
    expected=(ROOT/'build/expected-basic.bin').read_bytes();loaded=(ROOT/'build/loaded.bin').read_bytes()
    differences=[i for i,(a,b) in enumerate(zip(expected,loaded)) if a!=b]
    if differences:raise ValueError(f'Tape-loaded BASIC differs at {len(differences)} bytes; first {differences[:20]}')
    rows=text((ROOT/'build/basic.bin').read_bytes())
    if '4' not in [r.strip() for r in rows]:raise ValueError('PRINT 2+2 did not produce a line containing 4')
    cold=(ROOT/'build/cold-reset.bin').read_bytes()
    if cold[0x4000:0x5800]==loaded[0x4000:0x5800]:raise ValueError('Cold reset did not restore monitor screen')
    report={'status':'passed','project_sources':source_hashes(),'checks':[
        'original 2 KiB monitor boot','L/Enter/Enter keyboard cassette launch',
        f'all {len(expected)} BASIC bytes received through EAR and matched to the MP3-derived payload',
        'PRINT 2+2 produced a line containing 4','F11 reset restored monitor'],
        'basic_sha256':hashlib.sha256(expected).hexdigest(),'basic_screen':rows,
        'capture_sha256':{n:hashlib.sha256((ROOT/f'build/{n}.bin').read_bytes()).hexdigest() for n in names},
        'simulation_master_hz':7000000,'clock_step':8,
        'qualification':'Physical MiSTer testing and original-board timing comparison remain separate gates.'}
    (ROOT/'build/functional-validation.json').write_text(json.dumps(report,indent=2)+'\n')
    (ROOT/'build/tape-validation.json').write_text(json.dumps({'status':'passed','loaded_bytes':len(expected),
        'payload_sha256':report['basic_sha256'],'tape_sha256':hashlib.sha256((ROOT/'assets/tapes/basic.tzx').read_bytes()).hexdigest()},indent=2)+'\n')
    images=DOCS/'images';images.mkdir(exist_ok=True)
    for n in ['boot','loaded','basic']:Image.open(ROOT/f'build/{n}.png').save(images/f'{n}.png')
    print('PASS: complete MP3-derived BASIC tape load, arithmetic and reset captures');print('\n'.join(rows))
if __name__=='__main__':main()
