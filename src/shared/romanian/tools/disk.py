"""Convert a native flat sector image to an allocated CPC DSK without changing sectors."""
from pathlib import Path
import argparse
p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',type=Path);p.add_argument('output',type=Path);p.add_argument('--tracks',type=int,required=True);p.add_argument('--sides',type=int,choices=[1,2],required=True);p.add_argument('--sectors',type=int,required=True);p.add_argument('--sector-bytes',type=int,choices=[128,256,512,1024,2048,4096],default=512);p.add_argument('--first-id',type=int,default=1);p.add_argument('--fm',action='store_true');a=p.parse_args()
if not 1<=a.tracks<=128 or not 1<=a.sectors<=29 or a.first_id<0 or a.first_id+a.sectors>256:raise ValueError('DSK geometry out of range')
data=a.input.read_bytes();payload=a.sectors*a.sector_bytes
if len(data)!=a.tracks*a.sides*payload:raise ValueError('Raw image length disagrees with geometry')
tracksize=(256+payload+255)&~255;out=bytearray(256);out[:34]=b'MV - CPCEMU Disk-File\r\nDisk-Info\r\n';out[0x30:0x34]=bytes([a.tracks,a.sides,tracksize&255,tracksize>>8]);n=a.sector_bytes.bit_length()-8
for track in range(a.tracks*a.sides):
 h=bytearray(256);h[:12]=b'Track-Info\r\n';h[0x10:0x18]=bytes([track//a.sides,track%a.sides,1,1 if a.fm else 2,n,a.sectors,0x2a,0xe5])
 for sector in range(a.sectors):h[0x18+sector*8:0x20+sector*8]=bytes([track//a.sides,track%a.sides,a.first_id+sector,n,0,0,0,0])
 out+=h+data[track*payload:(track+1)*payload]+bytes(tracksize-256-payload)
a.output.write_bytes(out);print(len(out),'bytes; all native sector payloads preserved')
