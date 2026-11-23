"""Create a virtual printer image or extract its persistent raw output."""
from pathlib import Path
import argparse
p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['create','extract']);p.add_argument('image',type=Path);p.add_argument('--output',type=Path);p.add_argument('--megabytes',type=int,default=1);a=p.parse_args()
if a.action=='create':
 if not 1<=a.megabytes<=1024:raise ValueError('Image size must be 1..1024 MiB')
 with a.image.open('wb') as f:f.write(b'MiSTer-PRN-v1\n');f.seek(a.megabytes*1048576-1);f.write(b'\0')
else:
 data=a.image.read_bytes()
 if data[:13]!=b'MiSTer-PRN-v1\n':raise ValueError('Not a MiSTer printer image')
 size=int.from_bytes(data[32:36],'little')
 if size>len(data)-512:raise ValueError('Corrupt printer length')
 if data[36]:raise ValueError('Printer image overflowed; output is incomplete')
 if not a.output:raise ValueError('--output is required')
 a.output.write_bytes(data[512:512+size]);print(size,'bytes extracted')
