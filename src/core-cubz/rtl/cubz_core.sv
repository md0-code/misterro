// SPDX-License-Identifier: GPL-3.0-or-later
module cubz_core #(parameter ROM_FILE="",parameter FAST_DISK=0)(
 input wire clk,reset,video_reset,input wire [10:0] ps2_key,
 input wire [1:0] serial_rx,serial_cts_n,serial_dcd_n,output wire [1:0] serial_tx,serial_rts_n,serial_dtr_n,
 input wire [7:0] gpio_a_in,output wire [7:0] gpio_a_out,gpio_a_drive,
 input wire rom_wr,input wire [12:0] rom_addr,input wire [7:0] rom_data,
 input wire [1:0] img_mounted,input wire img_wp,input wire [31:0] img_size,
 output wire [31:0] sd_lba,output wire [1:0] sd_rd,sd_wr,input wire sd_ack,
 input wire [8:0] sd_buff_addr,input wire [7:0] sd_buff_dout,output wire [7:0] sd_buff_din,input wire sd_buff_wr,
 output wire ce_pixel,pixel,hs,vs,hblank,vblank,beeper,
 output wire [9:0] video_x,output wire [8:0] video_y,
 output wire [15:0] debug_pc,debug_addr,output wire [7:0] debug_data,debug_in,
 output wire debug_io_wr,debug_io_rd,debug_mem_wr,debug_cpu_p,
 output wire [31:0] debug_dma,output wire [15:0] debug_dma_addr,
 input wire [15:0] peek_addr,output wire [7:0] peek_data,output wire [7:0] peek_video,
 output wire keyboard_overflow,output wire [7:0] debug_char);
 reg [3:0] phase;reg [2:0] fdc_phase;
 always @(posedge clk)begin
  if(video_reset)begin phase<=0;fdc_phase<=0;end
  else begin phase<=phase+1'b1;fdc_phase<=fdc_phase==4?0:fdc_phase+1'b1;end
 end
 assign ce_pixel=phase[1:0]==3;
 wire cpu_p=phase==15,cpu_n=phase==7;
 wire [15:0] a;wire [7:0] d;reg [7:0] di;
 wire mreq_n,iorq_n,rd_n,wr_n,m1_n,busack_n,rfsh_n;
 wire [211:0] regs;
 // Mixed-port collisions are excluded by bus ownership; their read values are unused.
 (* ramstyle = "M10K, no_rw_check" *) reg [7:0] ram[0:65535];
 reg [7:0] vram[0:16383],rom[0:8191];
 initial if(ROM_FILE!="")$readmemh(ROM_FILE,rom);
 reg boot_alias;reg [7:0] pio_b,pio_mask,pio_a,scroll,floppy;
 reg mask_next;reg [7:0] ram_q,rom_q,vram_q,video_q,dma_ram;
 wire video_sel=a[15:14]==2 && pio_b[2];
 wire rom_sel=boot_alias || (pio_b[3] && a>=16'he800);
 wire [12:0] rom_index=boot_alias?{2'b11,a[10:0]}:a[12:0];
 wire [13:0] video_addr;
 wire [15:0] dma_addr;wire dma_ram_write;wire [7:0] dma_to_ram;
 always @(posedge clk)begin
  if(rom_wr)rom[rom_addr]<=rom_data;
  vram_q<=vram[a[13:0]];rom_q<=rom[rom_index];video_q<=vram[video_addr];
  if(!reset && !mreq_n && !wr_n && rfsh_n && busack_n)begin
   if(video_sel)begin if(!video_x[2])vram[a[13:0]]<=d;end

  end
 end
 // Explicit independent ports infer Cyclone V true dual-port block RAM.
 // CPU and DMA write ownership is mutually exclusive through BUSACK.
 wire cpu_ram_write=!reset && !mreq_n && !wr_n && rfsh_n && busack_n && !video_sel && !rom_sel;
 always @(posedge clk)begin
  if(cpu_ram_write)begin ram[a]<=d;ram_q<=d;end
  else ram_q<=ram[a];
 end
 always @(posedge clk)begin
  if(dma_ram_write)begin ram[dma_addr]<=dma_to_ram;dma_ram<=dma_to_ram;end
  else dma_ram<=ram[dma_addr];
 end
 `ifdef VERILATOR
 assign peek_data=ram[peek_addr];
 assign peek_video=vram[peek_addr[13:0]];
 `else
 assign peek_data=8'd0;
 assign peek_video=8'd0;
 `endif
 wire io=!iorq_n && m1_n;
 reg old_iow,old_ior;
 wire iow=io && !wr_n,ior=io && !rd_n;
 wire write_pulse=iow && !old_iow,read_pulse=ior && !old_ior;
 wire kb_data,kb_clock;
 cubz_keyboard keyboard(.clk(clk),.reset(reset),.ps2_key(ps2_key),.interrogate(pio_b[7]),
 .data_in(kb_data),.clock_in(kb_clock),.overflow(keyboard_overflow));
 wire [7:0] pio_input={1'b1,kb_data,kb_clock,5'b11111};
 wire [7:0] pio_read=(pio_b & ~pio_mask)|(pio_input & pio_mask);
 // Unconnected PIO-A lines are pulled high. PIO-B mode 3 direction follows firmware.
 always @(posedge clk)begin
  old_iow<=iow;old_ior<=ior;
  if(reset)begin boot_alias<=1;pio_b<=8'hff;pio_mask<=8'hff;mask_next<=0;pio_a<=8'hff;scroll<=0;floppy<=8'hff;end
  else if(write_pulse)begin
   case(a[7:4])
    4'hb:boot_alias<=0;
    4'hc:case(a[1:0])
     0:pio_a<=d;
     2:pio_b<=d;
     3:if(mask_next)begin pio_mask<=d;mask_next<=0;end else if(d[3:0]==15 && d[7:6]==3)mask_next<=1;
     default:;
    endcase
    4'hf:if(a[1:0]==2)scroll<=d;else if(a[1:0]==3)floppy<=d;
    default:;
   endcase
  end
 end
 wire [7:0] dma_out,fdc_out;
 wire fdc_drq,fdc_irq,dma_tc,dma_rd,dma_wr,busrq_n;
 cubz_dma dma(.clk(clk),.reset(reset),.io_wr(write_pulse && a[7:4]==8),.io_rd(read_pulse && a[7:4]==8),
 .regsel(a[3:0]),.din(d),.dout(dma_out),.drq(fdc_drq),.busack_n(busack_n),.fdc_data(fdc_out),.ram_data(dma_ram),
 .busrq_n(busrq_n),.fdc_read(dma_rd),.fdc_write(dma_wr),.ram_write(dma_ram_write),.address(dma_addr),
 .to_fdc(),.to_ram(dma_to_ram),.tc(dma_tc),.transfers(debug_dma));
 reg [1:0] mounted;
 always @(posedge clk)begin
  if(video_reset)mounted<=0;
  else begin if(img_mounted[0])mounted[0]<=img_size!=0;if(img_mounted[1])mounted[1]<=img_size!=0;end
 end
 // Original K1/K2 NMI jumper is open: the shipped monitor/BIOS polls the FDC.
 // The engine alternates drives at each 8 MHz enable: 4000 ticks/ms/drive.
 cubz_u765 #(.CYCLES(4000)) fdc(.clk_sys(clk),.ce(fdc_phase==4),.reset(reset),.tc(dma_tc),.drq(fdc_drq),.irq(fdc_irq),
 .ready(mounted),.motor(2'b11),.available(mounted),.fast(FAST_DISK!=0),
 .a0((!busack_n && !busrq_n) || a[0]),.nRD(!(dma_rd || (busack_n && ior && a[7:4]==9))),.nWR(!(dma_wr || (busack_n && iow && a[7:4]==9))),
 .din(dma_wr?dma_ram:d),.dout(fdc_out),.img_mounted(img_mounted),.img_wp(img_wp),.img_size(img_size),
 .sd_lba(sd_lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(sd_ack),.sd_buff_addr(sd_buff_addr),.sd_buff_dout(sd_buff_dout),
 .sd_buff_din(sd_buff_din),.sd_buff_wr(sd_buff_wr));
 wire [7:0] ctc_out,ctc_vector,sio_out,sio_vector,gpio_out;
 wire ctc_irq,ctc_busy,sio_irq,sio_busy;wire [3:0] ctc_zero;
 reg sio_reading,sio_acknowledged;reg [1:0] sio_address;
 wire sio_read=ior && a[7:4]==14;
 reg old_ack,old_fetch,was_ed;
 wire acknowledge=!iorq_n && !m1_n;
 wire fetch=!mreq_n && !m1_n && !rd_n;
 reg ctc_reti;
 always @(posedge clk)begin
  old_ack<=acknowledge;old_fetch<=fetch;ctc_reti<=0;
  sio_reading<=sio_read;if(sio_read)sio_address<=a[1:0];
  if(acknowledge && !old_ack)sio_acknowledged<=!ctc_irq;
  if(reset)begin old_ack<=0;old_fetch<=0;was_ed<=0;sio_reading<=0;sio_acknowledged<=0;end
  else if(fetch && !old_fetch)begin
   ctc_reti<=was_ed && di==8'h4d;was_ed<=di==8'hed;
  end
 end
 cubz_ctc ctc(.clk(clk),.reset(reset),.ce(cpu_p),.wr(write_pulse && a[7:4]==13),.channel(a[1:0]),.din(d),.dout(ctc_out),.acknowledge(acknowledge && !old_ack),.reti(ctc_reti),.trigger3(kb_clock),.irq(ctc_irq),.vector(ctc_vector),.zero(ctc_zero),.busy(ctc_busy));
 // Daisy chain: CTC, then the SIO. CTC channel 0 clocks SIO A, channel 1 SIO B.
 cubz_sio sio(.clk(clk),.reset(reset),.wr(write_pulse && a[7:4]==14),.rd_end(sio_reading && !sio_read),.wr_address(a[1:0]),.rd_address(sio_read?a[1:0]:sio_address),
 .din(d),.dout(sio_out),.baud_ce(ctc_zero[1:0]),.acknowledge(acknowledge && !old_ack && !ctc_irq),.reti(ctc_reti && !ctc_busy),.irq(sio_irq),.busy(sio_busy),.vector(sio_vector),
 .rx(serial_rx),.cts_n(serial_cts_n),.dcd_n(serial_dcd_n),.tx(serial_tx),.rts_n(serial_rts_n),.dtr_n(serial_dtr_n));
 cubz_pio gpio(.clk(clk),.reset(reset),.wr(write_pulse && a[7:4]==10),.address(a[1:0]),.din(d),.dout(gpio_out),
 .a_in(gpio_a_in),.b_in(8'hff),.a_out(gpio_a_out),.a_drive(gpio_a_drive),.b_out(),.b_drive());
 always @*begin
  di=8'hff;
  if(!mreq_n)di=video_sel && !boot_alias?vram_q:rom_sel?rom_q:ram_q;
  else if(acknowledge)di=sio_acknowledged?sio_vector:ctc_vector;
  else if(ior)case(a[7:4])
   8:di=dma_out;9:di=fdc_out;
   12:di=a[1:0]==2?pio_read:8'hff;
   13:di=ctc_out;
   10:di=gpio_out;
   14:di=sio_out;
   default:;
  endcase
 end
 T80pa cpu(.RESET_n(!reset),.CLK(clk),.CEN_p(cpu_p),.CEN_n(cpu_n),
 .WAIT_n(!(!mreq_n && video_sel && video_x[2])),.INT_n(!(ctc_irq || (sio_irq && !ctc_busy))),.NMI_n(1'b1),.BUSRQ_n(busrq_n),
 .M1_n(m1_n),.MREQ_n(mreq_n),.IORQ_n(iorq_n),.RD_n(rd_n),.WR_n(wr_n),.RFSH_n(rfsh_n),.HALT_n(),.BUSAK_n(busack_n),
 .OUT0(1'b0),.A(a),.DI(di),.DO(d),.R800_mode(1'b0),.REG(regs),.DIRSet(1'b0),.DIR(212'd0));
 cubz_video video(.clk(clk),.reset(video_reset),.ce(ce_pixel),.enable(pio_b[0]),.scroll(scroll),.data(video_q),.address(video_addr),
 .pixel(pixel),.hs(hs),.vs(vs),.hblank(hblank),.vblank(vblank),.x(video_x),.y(video_y));
 assign beeper=pio_b[1];
 assign debug_char=regs[87:80];
 assign debug_pc=regs[79:64];assign debug_addr=a;assign debug_data=d;assign debug_in=di;
 assign debug_io_wr=write_pulse;assign debug_io_rd=read_pulse;assign debug_mem_wr=!mreq_n && !wr_n && busack_n;
 assign debug_cpu_p=cpu_p;assign debug_dma_addr=dma_addr;
endmodule
