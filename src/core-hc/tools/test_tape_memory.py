"""Verify dense tape RAM independently at every supported byte address."""
from build import *
from validate_quartus import source_hashes
def main():
 original=source_hashes()
 cpu()
 run(['verilator','--binary','--timing','-j','4','-Wno-fatal','-Wno-WIDTH','-Wno-CASEINCOMPLETE','-Wno-COMBDLY','--top-module','hc_tape_memory_tb','--Mdir',BUILD/'tape-memory-obj',ROOT/'rtl/hc85_tape.sv',UP/'rtl/tape.sv',UP/'rtl/pzxplayer.sv',BUILD/'tzxplayer.v',ROOT/'sim/hc_tape_memory_tb.sv'],log='tape-memory-build.log')
 run([BUILD/'tape-memory-obj/Vhc_tape_memory_tb'])
 for mode in [0,1]:
  run(['verilator','--binary','--timing','-j','4','-Wno-fatal','-Wno-WIDTH','-Wno-CASEINCOMPLETE','-Wno-COMBDLY','--top-module','hc_tape_48k_tb',f'-GMODE48={mode}','--Mdir',BUILD/f'tape-48k-{mode}',ROOT/'rtl/hc85_tape.sv',UP/'rtl/tape.sv',UP/'rtl/pzxplayer.sv',BUILD/'tzxplayer.v',ROOT/'sim/hc_tape_48k_tb.sv'],log=f'tape-48k-{mode}.log')
  run([BUILD/f'tape-48k-{mode}/Vhc_tape_48k_tb'])
 if source_hashes()!=original:raise ValueError('Sources changed during tape RAM test')
 (BUILD/'tape-memory-validation.json').write_text(json.dumps({'status':'passed','project_sources':original,'bytes_tested':262144,'checks':['every supported byte address','upload gaps','partial word flush','overflow rejection','TZX stop48 in both 48K and 128K modes']},indent=2)+'\n')
if __name__=='__main__':main()
