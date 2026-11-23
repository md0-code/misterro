"""Losslessly encode original HC ROMs as a byte page table and dictionary."""
from pathlib import Path
from project_paths import ROOT
PARTS=['hc85.rom','hc90.rom','hc91.rom','hc88.rom','hc128.rom','hc2000-0.rom','hc2000-1.rom','if85.rom','if90.rom','hc-family-cpm.rom']
def pack(raw):
 if len(raw)%256:raise ValueError('Unaligned firmware')
 pages=[];table=bytearray()
 for offset in range(0,len(raw),256):
  page=raw[offset:offset+256]
  if page not in pages:pages.append(page)
  table.append(pages.index(page))
 if len(pages)>252 or len(table)>1024:raise ValueError('Firmware dictionary capacity exceeded')
 return bytes(table).ljust(1024,b'\0')+b''.join(pages)
def unpack(data,length):
 return b''.join(data[1024+index*256:1280+index*256] for index in data[:length//256])
def main():
 raw=b''.join((ROOT/'assets/roms'/name).read_bytes() for name in PARTS)
 data=pack(raw).ljust(65536,b'\xff')
 if unpack(data,len(raw))!=raw:raise ValueError('Firmware reconstruction mismatch')
 if len(raw)!=159744 or len(data)!=65536:raise ValueError('Unexpected hardware firmware layout')
 (ROOT/'assets/roms/family.rom').write_bytes(data)
 print('Firmware bank bytes:',len(raw),'bytes; lossless family upload:',len(data),'bytes')
if __name__=='__main__':main()
