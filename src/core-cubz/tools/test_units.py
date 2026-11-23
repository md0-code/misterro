"""Exercise the hardware interfaces independently of boot software."""
from cpu import ROOT,BUILD,run
run(['iverilog','-g2012','-s','units','-o',BUILD/'units',ROOT/'rtl/cubz_keyboard.sv',ROOT/'rtl/cubz_dma.sv',ROOT/'sim/units.sv'])
run(['vvp',BUILD/'units'])
run(['iverilog','-g2012','-s','timing','-o',BUILD/'timing',ROOT/'rtl/cubz_ctc.sv',ROOT/'rtl/cubz_video.sv',ROOT/'sim/timing.sv'])
run(['vvp',BUILD/'timing'])
run(['iverilog','-g2012','-s','serial','-o',BUILD/'serial',ROOT/'rtl/cubz_ctc.sv',ROOT/'rtl/cubz_sio.sv',ROOT/'rtl/cubz_pio.sv',ROOT/'sim/serial.sv'])
run(['vvp',BUILD/'serial'])
