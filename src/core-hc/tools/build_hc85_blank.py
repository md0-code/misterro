"""Create a blank 40-track, double-sided HC85 Interface 1 disk container."""
from project_paths import ROOT

def image():
 header=bytearray(256);header[:34]=b'EXTENDED CPC DSK File\r\nDisk-Info\r\n';header[0x22:0x30]=b'MiSTer HC85   ';header[0x30]=40;header[0x31]=2;header[0x34:0x34+80]=bytes([17])*80
 out=bytearray(header)
 for c in range(40):
  for head in range(2):
   track=bytearray(256);track[:12]=b'Track-Info\r\n';track[0x10]=c;track[0x11]=head;track[0x14:0x18]=bytes([1,16,0x36,0xe5])
   for s in range(16):track[0x18+s*8:0x20+s*8]=bytes([c,head,s+1,1,0,0,0,1])
   out+=track+bytes([0xe5])*4096
 return bytes(out)
def main():
 p=ROOT/'assets/disks/hc85/blank.dsk';p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(image())
if __name__=='__main__':main()
