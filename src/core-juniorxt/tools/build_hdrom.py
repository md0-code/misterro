"""Assemble the Winchester ROM (software/hdrom.asm) into assets/hdd.rom: 8 KiB, checksum byte last."""
from project_paths import ROOT
from asm86 import assemble
SIZE=8192
def main():
 code=bytearray(assemble((ROOT/'software/hdrom.asm').read_text(encoding='utf-8')))
 if len(code)>SIZE-1 or code[:3]!=bytes([0x55,0xAA,SIZE//512]):raise ValueError('Winchester ROM does not fit its header')
 code+=bytes([255])*(SIZE-len(code));code[-1]=0;code[-1]=-sum(code)&255
 (ROOT/'assets').mkdir(exist_ok=True);(ROOT/'assets/hdd.rom').write_bytes(code)
 print('PASS: Winchester ROM,',len(code),'bytes')
if __name__=='__main__':main()
