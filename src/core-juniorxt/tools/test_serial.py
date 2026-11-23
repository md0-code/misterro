from project_paths import ROOT
from common import run
p=ROOT/'vendor/pcxt/rtl/KFPC-XT/HDL/KF8253/HDL';out=ROOT/'build/serial.vvp'
run(['iverilog','-g2012','-I'+str(p),'-s','serial_tb','-o',out,ROOT/'rtl/junior_serial.sv',*sorted(p.glob('*.sv')),ROOT/'sim/serial_tb.sv'],log='serial-build.log')
run(['vvp',out],log='serial-test.log')
print((ROOT/'build/serial-test.log').read_text())
