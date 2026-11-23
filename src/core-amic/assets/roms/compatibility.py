"""Reproduce the documented aMIC archived-ROM compatibility repairs."""
from pathlib import Path
import hashlib
p=Path(__file__).resolve().parent;b=bytearray((p/'original.rom').read_bytes())
assert hashlib.sha256(b).hexdigest()=='f968800950af4699a1131cad56ded283834333075a6c9056b0e1b7dd2d344052'
b[0x3fdb:0x3feb]=bytes.fromhex('42 4b 11 29 08 c3 ae 3b')+bytes(8)
b[0x3c8d:0x3c94]=bytes.fromhex('af c3 1d 3c 00 00 00');b[0x3da1]=0x7f
b[0x3dac:0x3db0]=bytes.fromhex('c3 b0 3d 00');b[0x3db0:0x3db9]=bytes.fromhex('7c b5 20 01 2b 22 0e 60 c9')
(p/'boot.rom').write_bytes(b)
