"""Independent native HC88 memory, port and serializer regressions."""
from build import ROOT,BUILD,cpu,run,sources
from pack_firmware import pack

def main():
 cpu()
 run(['pasmo','--bin','sim/hc88_bus.asm','build/hc88-bus-all.bin'])
 image=(BUILD/'hc88-bus-all.bin').read_bytes();image=image[:32]+image[0x8000:]
 assert len(image)==2048
 (BUILD/'hc88-bus.hex').write_text(''.join(f'{b:02x}\n' for b in image))
 raw=bytearray(b'\xff'*159744);raw[49152:51200]=image
 (BUILD/'hc88-shared-firmware.hex').write_text(''.join(f'{v:02x}\n' for v in pack(raw).ljust(65536,b'\xff')))
 common=['verilator','--binary','--timing','-j','4','-Wno-fatal','-Wno-WIDTH','-Wno-PINMISSING','-Wno-CASEINCOMPLETE','-Wno-COMBDLY']
 run([*common,'--top-module','hc88_bus_tb','--Mdir',BUILD/'hc88-bus-obj','rtl/hc88_core.sv','rtl/hc88_video.sv','rtl/hc88_u765.sv','build/t80.v','sim/hc88_bus_tb.sv'],log='hc88-bus-build.log')
 run([BUILD/'hc88-bus-obj/Vhc88_bus_tb'])
 run([*common,'--top-module','hc88_shared_bus_tb','--Mdir',BUILD/'hc88-shared-bus-obj',*sources(),ROOT/'sim/hc88_shared_bus_tb.sv'],log='hc88-shared-bus-build.log')
 run([BUILD/'hc88-shared-bus-obj/Vhc88_shared_bus_tb'])
 for hires in [0,1]:
  folder=BUILD/f'hc88-video-{hires}'
  run([*common,'--top-module','hc88_video_tb',f'-GHIRES={hires}','--Mdir',folder,'rtl/hc88_video.sv','sim/hc88_video_tb.sv'],log=f'hc88-video-{hires}.log')
  run([folder/'Vhc88_video_tb'])
if __name__=='__main__':main()
