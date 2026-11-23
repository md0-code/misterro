"""Render and inspect the display produced by the original ROM in RTL simulation."""
from pathlib import Path
import argparse,hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def decode(memory,model='HC85'):
    rom=(ROOT/f'assets/roms/{model.lower()}.rom').read_bytes()
    glyphs={bytes(rom[0x3d00+(c-32)*8:0x3d00+(c-31)*8]):chr(c) for c in range(32,127)}
    rows=[]
    for row in range(24):
        text=''
        for column in range(32):
            glyph=bytes(memory[0x4000+((row*8+p)&0xc0)*32+((row*8+p)&7)*256+((row*8+p)&0x38)*4+column] for p in range(8))
            text+=glyphs.get(glyph,'?')
        rows.append(text.rstrip())
    return rows
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--test',action='store_true');p.add_argument('--tape',action='store_true');p.add_argument('--family',action='store_true');p.add_argument('--model',choices=['HC85','HC90','HC91'],default='HC85');args=p.parse_args()
    model=args.model;prefix='' if model=='HC85' else model.lower()+'-'
    reports={}
    for name in ['boot']+(['basic','reset','reset-basic'] if args.test else [])+(['switch','switch-basic'] if args.family else [])+(['tape'] if args.tape else []):
        path=ROOT/f'build/{prefix}{name}.bin'
        if not path.exists():continue
        rows=decode(path.read_bytes(),model)
        reports[name]=rows
        print(name+':\n'+'\n'.join(r for r in rows if r))
        source=ROOT/f'build/{prefix}{name}.ppm'
        if source.exists():
            img=Image.open(source)
            # Reorder the wraparound border into a conventional screen view.
            result=Image.new('RGB',(352,288))
            result.paste(img.crop((400,264,448,312)),(0,0))
            result.paste(img.crop((0,264,304,312)),(48,0))
            result.paste(img.crop((400,0,448,240)),(0,48))
            result.paste(img.crop((0,0,304,240)),(48,48))
            result.resize((704,576),Image.Resampling.NEAREST).save(ROOT/f'build/{prefix}{name}.png')
    (ROOT/f'build/{prefix}screen-text.json').write_text(json.dumps(reports,indent=2)+'\n')
    if args.test:
        boot='\n'.join(reports.get('boot',[])).lower()
        if 'hc' not in boot or 'feli' not in boot:raise SystemExit('Original HC boot banner not found')
        basic=reports.get('basic',[])
        if not any(row.strip()=='4' for row in basic):raise SystemExit('Keyboard-entered PRINT 2+2 did not produce 4')
        if not any(row.strip()=='6' for row in reports.get('reset-basic',[])):
            raise SystemExit('F11 restart and PRINT 3+3 did not produce 6')
        if model[2:] not in boot:raise SystemExit('Wrong model startup banner')
        if args.family:
            switched={'HC85':'90','HC90':'91','HC91':'85'}[model]
            if switched not in '\n'.join(reports.get('switch',[])):raise ValueError('Wrong firmware after model switch')
            if not any(r.strip()=='4' for r in reports.get('switch-basic',[])):raise ValueError('BASIC failed after model switch')
        from validate_quartus import source_hashes
        evidence={'family_selector':args.family,'model':model,'reset_basic_result':6,'status':'passed','project_sources':source_hashes(),
                  'boot_banner':[r for r in reports['boot'] if r.strip()],
                  'basic_result':4,
                  'rom_sha256':hashlib.sha256((ROOT/f'assets/roms/{model.lower()}.rom').read_bytes()).hexdigest()}
        (ROOT/f'build/{prefix}functional-validation.json').write_text(json.dumps(evidence,indent=2)+'\n')
        print('PASS: original ROM boot and keyboard-entered BASIC arithmetic')
if __name__=='__main__':main()
