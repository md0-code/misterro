// SPDX-License-Identifier: GPL-3.0-or-later
module hc88_shared_bus_tb;
 reg [7:0] firmware[0:65535];integer i;reg rom_wr=0;reg [15:0] rom_addr=0;reg [7:0] rom_data=0;
 reg clk=0,reset=1,video_reset=1;
 integer irq_ticks=0;reg irq_seen=0;
 always #5 clk=~clk;
 always @(negedge clk)begin
  if(!reset && dut.interrupt_active)irq_ticks=irq_ticks+1;
  else if(irq_ticks!=0)begin
   if(irq_ticks!=512)$fatal(1,"HC88 hires changed interrupt duration: %0d",irq_ticks);
   irq_seen=1;irq_ticks=0;
  end
 end
 hc_family_core dut(.model_select(3'd3),.interface_enable(1'b0),.ay_enable(1'b0),.boot_cpm(1'b0),.joystick(5'd0),.clk(clk),.reset(reset),.video_reset(video_reset),
 .keys_n(40'hfffffffbff),.ear(1'b1),.rom_wr(rom_wr),.rom_addr(rom_addr),.rom_data(rom_data),
 .img_mounted(2'd0),.img_wp(1'b1),.img_size(32'd0),.sd_ack(1'b0),.sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_wr(1'b0),
 .network_rx(1'b0),.serial_rx(1'b0),.serial_ready(1'b0),.peek_address(16'd0));
 initial begin
 $readmemh("build/hc88-shared-firmware.hex",firmware);
 repeat(128)@(negedge clk);
 for(i=0;i<65536;i=i+1)begin rom_wr=1;rom_addr=i;rom_data=firmware[i];@(negedge clk);end
 rom_wr=0;reset=0;video_reset=0;
 repeat(2000000)@(negedge clk);
 if(dut.rom[{dut.page_table[192],8'd0}]!=8'hf3)$fatal(1,"Original ROM was writable");
 if(dut.ram[16'h9000]!=8'h55 || dut.ram[16'h9001]!=8'hbb || dut.ram[16'h9002]!=8'haa)$fatal(1,"Independent video/system memory failed PC=%h results=%h,%h,%h",dut.debug_pc,dut.ram[16'h9000],dut.ram[16'h9001],dut.ram[16'h9002]);
 if(dut.ram[16'h9003]!=8'haa || dut.ram[16'h9004]!=8'hbb || dut.ram[16'h9005]!=8'haa || dut.ram[16'h4000]!=8'h66)$fatal(1,"LOCK or automatic shadow paging failed");
 if(dut.ram[16'h9006]!=8'h5a)$fatal(1,"MOD1 did not overlay video RAM in all quadrants");
 if(dut.ram[16'h9007]!=8'hfe || dut.ram[16'h9008]!=8'hff || dut.ram[16'h9009]!=8'hff)$fatal(1,"HC88 keyboard/EAR aliases failed");
 if(dut.ram[16'h900b]!=8'hf7 || dut.ram[16'h900c]!=8'hfe || !dut.serial_tx || dut.serial_cts)$fatal(1,"Native serial bit-bang ports failed");
 if(dut.selected!=1 || !dut.motor || dut.ram[16'h900d][0])$fatal(1,"Drive select/motor feedback failed");
 if(!irq_seen)$fatal(1,"HC88 video interrupt was absent");
 if(dut.border!=5 || !dut.beeper || !dut.mic || dut.ram[16'h900a]!=8'h77)$fatal(1,"Port write or test execution failed PC=%h",dut.debug_pc);
 $display("PASS: HC88 native 80K mapping, LOCK, automatic shadow, MOD1, original ROM protection and I/O aliases");$finish;
 end
endmodule
