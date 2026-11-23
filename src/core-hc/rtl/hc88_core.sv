// SPDX-License-Identifier: GPL-3.0-or-later
// HC-88 drawing 869.300.350: 2K bootstrap, 64K system + 16K video RAM.
module hc88_core #(parameter ROM_FILE="",parameter FAST_DISK=0)(
 input wire clk,reset,video_reset,input wire [39:0] keys_n,input wire ear,
 input wire rom_wr,input wire [10:0] rom_addr,input wire [7:0] rom_data,
 input wire [1:0] img_mounted,input wire img_wp,input wire [31:0] img_size,
 output wire [31:0] sd_lba,output wire [1:0] sd_rd,sd_wr,input wire sd_ack,
 input wire [8:0] sd_buff_addr,input wire [7:0] sd_buff_dout,output wire [7:0] sd_buff_din,input wire sd_buff_wr,
 input wire serial_rx,serial_ready,network_rx,output wire serial_tx,serial_cts,network_tx,
 output wire ce_pixel,ce_tape,output wire [2:0] rgb,output wire bright,
 output wire hs,vs,hblank,vblank,output reg beeper,mic,
 output wire [9:0] video_x,output wire [8:0] video_y,
 output wire [15:0] debug_pc,debug_addr,output wire [7:0] debug_data,debug_in,
 output wire [7:0] debug_char,output wire debug_fetch,
 output wire debug_mem_wr,debug_io_wr,debug_cpu_p,debug_stall,
 output wire [5:0] debug_command,input wire [15:0] peek_address,
 output wire [7:0] peek_ram,peek_vram
);
 reg [5:0] phase=0;reg [2:0] fdc_phase=0;
 always @(posedge clk)if(video_reset)begin phase<=0;fdc_phase<=0;end
 else begin phase<=phase+1'b1;fdc_phase<=fdc_phase==6?0:fdc_phase+1'b1;end
 assign ce_tape=phase[3:0]==15;
 wire [15:0] a;wire [7:0] d;reg [7:0] di;
 wire mreq_n,iorq_n,rd_n,wr_n,m1_n,rfsh_n;wire [211:0] registers;
 reg [7:0] rom[0:2047],ram[0:65535],vram[0:16383];
 // A small mirrored attribute store gives the serializer its second read port.
 reg [7:0] attributes[0:2047];
 initial if(ROM_FILE!="")$readmemh(ROM_FILE,rom);
 reg [5:0] command=0;reg shadow=0;reg [7:0] floppy=0,serial=8'hff,network=0;
 reg network_wait=0;wire network_active=network_rx || network_tx;
 assign network_tx=!network[0] && !serial[0];
 wire io=!iorq_n && m1_n;
 wire cmd_select=io && a[7] && !a[6] && a[0];
 wire fe_select=io && a[7] && a[6] && !a[0];
 wire fdc_select=io && a[7] && a[6] && a[0] && !a[5];
 wire e7_select=io && a[7] && !a[4] && !a[3];
 wire ef_select=io && a[7] && !a[4] && a[3];
 wire f7_select=io && a[7] && a[4] && !a[3];
 wire q0=a[15:14]==0;
 wire rom_select=q0 && !command[0];
 wire video_select=command[3] || (!command[5] && a[15:14]==1);
 wire [15:0] system_address=shadow && q0?{2'b01,a[13:0]}:a;
 wire lock_write=q0 && command[1] && !shadow;
 reg [7:0] rom_q,ram_q,vram_q,bitmap_q,attribute_q;
 wire [13:0] bitmap_address,attribute_address;
 always @(posedge clk)begin
  if(rom_wr)rom[rom_addr]<=rom_data;
  rom_q<=rom[a[10:0]];ram_q<=ram[system_address];vram_q<=vram[a[13:0]];
  bitmap_q<=vram[bitmap_address];attribute_q<=attributes[{attribute_address[13],attribute_address[9:0]}];
  if(!reset && !mreq_n && !wr_n && rfsh_n)begin
   if(video_select && !rom_select)begin
    vram[a[13:0]]<=d;
    if(a[12:10]==3'b110)attributes[{a[13],a[9:0]}]<=d;
   end else if(!lock_write && !rom_select)ram[system_address]<=d;
  end
 end
 reg old_io_write=0,old_fetch=0;reg [15:0] io_address;reg [7:0] io_data;
 wire iow=io && !wr_n;wire fetch=!mreq_n && !m1_n && !rd_n;
 wire write_done=old_io_write && !iow;
 reg [2:0] border=0;
 reg [26:0] motor_ticks=0;wire motor=motor_ticks!=0;
 always @(posedge clk)begin
  old_io_write<=iow;old_fetch<=fetch;
  if(iow)begin io_address<=a;io_data<=d;end
  if(reset)begin command<=0;shadow<=0;floppy<=0;serial<=8'hff;network<=0;border<=0;beeper<=0;mic<=0;motor_ticks<=0;network_wait<=0;end
  else begin
   if(motor_ticks!=0)motor_ticks<=motor_ticks-1'b1;
   if(!network_active)network_wait<=0;
   if(fetch && !old_fetch && command[0])begin
    if(a[15:3]==13'h001 || a[15:3]==13'h2e1)shadow<=1;
    else if(a[15:3]==13'h0e0)shadow<=0;
   end
   if(write_done)begin
    if(io_address[7] && !io_address[6] && io_address[0])begin command<=io_data[5:0];if(!io_data[0])shadow<=0;end
    if(io_address[7] && io_address[6] && !io_address[0])begin border<=io_data[2:0];mic<=io_data[3];beeper<=io_data[4];end
    if(io_address[7] && !io_address[4] && !io_address[3])begin
     floppy<=io_data;if(io_data[3])motor_ticks<=27'd86800000;
    end
    if(io_address[7] && !io_address[4] && io_address[3])serial<=io_data;
    if(io_address[7] && io_address[4] && !io_address[3])begin network<=io_data;if(!io_data[5] && network_active)network_wait<=1;end
   end
  end
 end
 reg [4:0] keyboard;integer row;
 always @*begin keyboard=31;for(row=0;row<8;row=row+1)if(!a[8+row])keyboard=keyboard & keys_n[row*5+:5];end
 wire video_access=!mreq_n && video_select && !rom_select;
 wire clock_allowed=!video_access || !phase[5];
 wire cpu_p=phase[3:0]==15 && clock_allowed,cpu_n=phase[3:0]==7 && clock_allowed;
 reg [1:0] mounted=0;
 always @(posedge clk)begin
  if(video_reset)mounted<=0;
  else begin if(img_mounted[0])mounted[0]<=img_size!=0;if(img_mounted[1])mounted[1]<=img_size!=0;end
 end
 // Sheet 13: U95 gates each E7 drive-select bit with MOTOR-ON.
 wire [1:0] selected={floppy[2],floppy[1]};
 wire [7:0] disk_data;
 hc88_u765 #(.CYCLES(4000)) disk(.clk_sys(clk),.ce(fdc_phase==6),.reset(reset || !floppy[4]),
 .tc(floppy[0]),.drq(),.irq(),.ready(mounted & selected),.motor({2{motor}} & selected),.available(mounted & selected),.fast(FAST_DISK!=0),
 .a0(a[1]),.nRD(!(fdc_select && !rd_n)),.nWR(!(fdc_select && !wr_n)),.din(d),.dout(disk_data),
 .img_mounted(img_mounted),.img_wp(img_wp),.img_size(img_size),.sd_lba(sd_lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(sd_ack),
 .sd_buff_addr(sd_buff_addr),.sd_buff_dout(sd_buff_dout),.sd_buff_din(sd_buff_din),.sd_buff_wr(sd_buff_wr));
 always @*begin
  di=8'hff;
  if(!mreq_n)di=rom_select?rom_q:video_select?vram_q:ram_q;
  else if(io && !rd_n)begin
   if(fe_select)di={1'b1,ear,1'b1,keyboard};
   if(fdc_select)di=disk_data;
   if(ef_select)di[3]=serial_ready;
   if(f7_select)begin di[7]=!serial_rx;di[0]=network_active;end
   if(e7_select)di[0]=!motor;
  end
 end
 wire interrupt_active=video_y==248 && (command[4]?video_x<128:video_x<64);
 T80pa cpu(.RESET_n(!reset),.CLK(clk),.CEN_p(cpu_p),.CEN_n(cpu_n),.WAIT_n(!network_wait),
 .INT_n(!interrupt_active),.NMI_n(1'b1),.BUSRQ_n(1'b1),
 .M1_n(m1_n),.MREQ_n(mreq_n),.IORQ_n(iorq_n),.RD_n(rd_n),.WR_n(wr_n),.RFSH_n(rfsh_n),.HALT_n(),.BUSAK_n(),
 .OUT0(1'b0),.A(a),.DI(di),.DO(d),.R800_mode(1'b0),.REG(registers),.DIRSet(1'b0),.DIR(212'd0));
 hc88_video video(.clk(clk),.reset(video_reset),.dot(phase[1:0]==3),.hires(command[4]),.border(border),
 .bitmap_address(bitmap_address),.attribute_address(attribute_address),.bitmap(bitmap_q),.attribute(attribute_q),
 .ce_pixel(ce_pixel),.rgb(rgb),.bright(bright),.hs(hs),.vs(vs),.hblank(hblank),.vblank(vblank),.x(video_x),.y(video_y));
 assign serial_tx=network[0]?!serial[0]:1'b1;assign serial_cts=~serial[4];
 assign debug_pc=registers[79:64];assign debug_addr=a;assign debug_data=d;assign debug_in=di;
 assign debug_mem_wr=!mreq_n && !wr_n;assign debug_io_wr=iow;assign debug_cpu_p=cpu_p;assign debug_stall=video_access && !clock_allowed;
 assign debug_command=command;assign debug_char=registers[87:80];assign debug_fetch=fetch;
 `ifdef VERILATOR
 assign peek_ram=ram[peek_address];assign peek_vram=vram[peek_address[13:0]];
 `else
 assign peek_ram=0;assign peek_vram=0;
 `endif
endmodule
