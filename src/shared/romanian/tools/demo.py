"""Generate a tokenized Sinclair BASIC tape with cached numeric values and XOR checksums."""
from pathlib import Path
import argparse
p=argparse.ArgumentParser(description=__doc__);p.add_argument('title');p.add_argument('output',type=Path);a=p.parse_args();body=bytearray()
for line,text in [(10,bytes([0xf5])+b'"'+a.title.encode('ascii')+b' DEMO"'),(20,bytes([0xf5])+b'42'+bytes([14,0,0,42,0,0])),(30,bytes([0xe2]))]:
 text+=b'\r';body+=line.to_bytes(2,'big')+len(text).to_bytes(2,'little')+text
header=bytes([0])+b'DEMO      '+len(body).to_bytes(2,'little')+(10).to_bytes(2,'little')+len(body).to_bytes(2,'little');out=bytearray()
for flag,data in [(0,header),(255,body)]:
 block=bytes([flag])+data;checksum=0
 for v in block:checksum^=v
 block+=bytes([checksum]);out+=len(block).to_bytes(2,'little')+block
a.output.write_bytes(out)
