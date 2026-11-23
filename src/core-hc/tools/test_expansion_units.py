"""Check HC expansion hardware through native Z80 bus transactions."""
from build import *
from pack_firmware import pack
from validate_quartus import source_hashes

def main():
 original=source_hashes()
 cpu()
 for model in [4,5,0,1,2]:
  name='hc_expansion_bus' if model==4 else 'hc2000_bus' if model==5 else 'hc_if1_bus'
  run(['pasmo','--bin',f'sim/{name}.asm','build/expansion-bus.bin'])
  raw=bytearray(b'\xff'*143360);code=(BUILD/'expansion-bus.bin').read_bytes()
  base={0:0,1:16384,2:32768,4:51200,5:83968}[model];raw[base:base+len(code)]=code
  if model==5:raw[83968+16384]=0xbb;raw[83968+16384+8192]=0xcc
  if model<3:
   raw[base+0x700]=0xf3
   interface=116736 if model==0 else 126976
   raw[interface+8:interface+11]=bytes.fromhex('c3 10 00')
   raw[interface+0x1708:interface+0x170b]=bytes.fromhex('c3 10 00')
   raw[interface+0x10:interface+0x19]=bytes.fromhex('32 00 28 3a 00 2c c3 00 07')
   raw[interface+0x700]=0xc9
  firmware=pack(raw).ljust(65536,b'\xff');assert len(firmware)==65536
  (BUILD/'expansion-bus-firmware.hex').write_text(''.join(f'{v:02x}\n' for v in firmware))
  run(['verilator','--binary','--timing','-j','4','-Wno-fatal','-Wno-WIDTH','-Wno-PINMISSING','-Wno-CASEINCOMPLETE','-Wno-COMBDLY','--top-module','hc_expansion_bus_tb',f'-GMODEL={model}','--Mdir',BUILD/f'expansion-bus-{model}',*sources(),ROOT/'sim/hc_expansion_bus_tb.sv'],log=f'expansion-bus-{model}.log')
  run([BUILD/f'expansion-bus-{model}/Vhc_expansion_bus_tb'])
 if source_hashes()!=original:raise ValueError('Sources changed during expansion tests')
 (BUILD/'expansion-unit-validation.json').write_text(json.dumps({'status':'passed','project_sources':original,'models':['HC85','HC90','HC91','HC128','HC2000'],'checks':['native bank retention and lock','AY registers and generated tone waveform','HC2000 ROM/RAM relocation','IF1 automatic paging and local RAM','UART polarity and handshakes','network assert, release and peer WAIT','motor sense','two drive selection','8272 status','Kempston joystick']},indent=2)+'\n')
if __name__=='__main__':main()
