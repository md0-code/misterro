"""Verify that the ROM loaded an original TZX BASIC bootstrap into RAM."""
from pathlib import Path
import argparse,hashlib,json,struct
ROOT=Path(__file__).resolve().parents[1]
def standard_blocks(data):
    if not data.startswith(b'ZXTape!\x1a'):raise ValueError('Bootstrap check requires TZX')
    pos=10
    while pos<len(data):
        kind=data[pos];pos+=1
        if kind==0x10:
            _,length=struct.unpack_from('<HH',data,pos);pos+=4
            yield data[pos:pos+length];pos+=length
        elif kind==0x20:pos+=2
        elif kind==0x30:pos+=1+data[pos]
        elif kind==0x32:pos+=2+int.from_bytes(data[pos:pos+2],'little')
        elif kind==0x33:pos+=1+3*data[pos]
        elif kind==0x35:pos+=20+int.from_bytes(data[pos+16:pos+20],'little')
        else:raise ValueError(f'Unsupported bootstrap-check block {kind:02x}')
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('tape',type=Path);parser.add_argument('--captures',type=Path);parser.add_argument('--model',choices=['HC85','HC90','HC91'],default='HC85');args=parser.parse_args()
    prefix='' if args.model=='HC85' else args.model.lower()+'-'
    tape=args.tape.read_bytes();blocks=iter(standard_blocks(tape))
    header=next(blocks);data=next(blocks)
    if len(header)!=19 or header[:2]!=b'\x00\x00' or not data or data[0]!=255:
        raise ValueError('First recording is not a standard BASIC program')
    for block in [header,data]:
        checksum=0
        for byte in block:checksum^=byte
        if checksum:raise ValueError('Original tape block checksum failed')
    payload=data[1:-1]
    length=int.from_bytes(header[12:14],'little')
    if length!=len(payload):raise ValueError('Original header/data lengths differ')
    memory=((args.captures or ROOT/'build')/f'{prefix}tape.bin').read_bytes()
    if len(memory)!=65536:raise ValueError('Invalid simulated memory capture')
    prog=int.from_bytes(memory[0x5c53:0x5c55],'little')
    if memory[prog:prog+length]!=payload:
        raise ValueError(f'Original BASIC bootstrap was not loaded at PROG={prog:04x}; allow more tape time')
    name=header[2:12].decode('ascii').rstrip()
    bundled=ROOT/f'assets/tapes/{args.model.lower()}/demo.tzx'
    complete=list(standard_blocks(bundled.read_bytes()))
    if header not in complete or data not in complete:raise ValueError('Test loader is not in the bundled original demo')
    from validate_quartus import source_hashes
    result={'bundled_demo_sha256':hashlib.sha256(bundled.read_bytes()).hexdigest(),'model':args.model,'project_sources':source_hashes(),'status':'passed','program':name,'loaded_bytes':length,'prog_address':prog,
            'payload_sha256':hashlib.sha256(payload).hexdigest(),'tape_sha256':hashlib.sha256(tape).hexdigest(),
            'scope':'Initial BASIC bootstrap loaded through ROM EAR decoding; remaining machine-code block not validated.'}
    (ROOT/f'build/{prefix}tape-validation.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS: original {name} BASIC bootstrap loaded through EAR ({length} bytes, exact payload match)')
if __name__=='__main__':main()
