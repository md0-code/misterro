// SPDX-License-Identifier: GPL-3.0-or-later
// CoBra 64K original and documented 80K upgrade, with original unmodified firmware.
module machine_core(
 `include "rp_machine_ports.vh"
);
 reg [3:0] phase=0;reg [2:0] fphase=0;
 always @(posedge clk)if(video_reset)begin phase<=0;fphase<=0;end else begin phase<=phase+1'b1;fphase<=fphase==6?0:fphase+1'b1;end
 wire cpu_p=phase==15,cpu_n=phase==7;assign ce_pixel=phase[2:0]==7;
 wire [15:0] a;wire [7:0] d;reg [7:0] di;wire mreq_n,iorq_n,rd_n,wr_n,m1_n,rfsh_n;wire [211:0] regs;
 wire iow=!iorq_n&&m1_n&&!wr_n,ior=!iorq_n&&m1_n&&!rd_n;
 reg old_iow=0,old_ior=0;always @(posedge clk)begin old_iow<=iow;old_ior<=ior;end
 wire wp=iow&&!old_iow,rp=ior&&!old_ior;
 wire [7:0] pc,pc_oe,ppi;wire [7:0] pc_pins=(pc&pc_oe)|~pc_oe;
 wire model80=!status[6];
 reg po=1,cpm=1,basic_lock=0;reg [11:0] power_count=4095;
 always @(posedge clk)begin
  if(reset)begin po<=1;cpm<=1;basic_lock<=0;power_count<=4095;end
  else if(power_count!=0)power_count<=power_count-1'b1;
  else if(!rfsh_n&&cpu_p&&!basic_lock)begin
   po<=a[7];
   if(po&&!a[7])begin cpm<=pc_pins[6];if(!pc_pins[6])basic_lock<=1;end
  end
 end
 (* ramstyle="M10K, no_rw_check" *) reg [7:0] rom[0:81919];
 (* ramstyle="M10K, no_rw_check" *) reg [7:0] ram[0:65535];
 (* ramstyle="M10K, no_rw_check" *) reg [7:0] vram[0:16383];
 reg [16:0] physical;wire rom_sel=po&&!a[15];wire basic=!po&&!cpm;
 // The original 64K board has a fixed 16K BASIC EPROM; the 80K firmware board banks 64K.
 wire [1:0] system_page=model80?{pc_pins[3],pc_pins[7]}:2'd1;
 wire [16:0] ri=a[14]?17'd16384+{1'b0,system_page,a[13:0]}:((model80?17'h03800:17'h03000)+{6'd0,a[10:0]});
 always @*begin
  physical={1'b0,a};
  if(po)begin
   if(model80)physical=a[14]?(pc_pins[6]?17'h10000:17'h04000)+{3'd0,a[13:0]}:{3'd0,a[13:0]};
   else case(a[15:13])
    4:physical={4'd0,a[12:0]};
    5:physical={4'd3,a[12:0]};
    6:physical={4'd2,a[12:0]};
    7:physical={4'd1,a[12:0]};
    default:physical={1'b0,a};
   endcase
  end else if(cpm)begin
   if(model80)begin if(a[15:14]==1&&pc_pins[6])physical={3'b100,a[13:0]};end
   else case(a[15:13])
    0,1:physical={3'b010,a[13:0]};
    2,3:physical={3'b011,a[13:0]};
    4:physical={1'b0,3'b000,a[12:0]};
    5:physical={1'b0,3'b011,a[12:0]};
    6:physical={1'b0,3'b010,a[12:0]};
    7:physical={1'b0,3'b001,a[12:0]};
   endcase
  end
 end
 // Physical 64K DRAM banks use natural Spectrum order; 80K adds independent VRAM.
 wire mw=!reset&&!mreq_n&&!wr_n&&rfsh_n&&!rom_sel&&!(basic&&a[15:14]==0);
 reg [7:0] ram_q,vram_cpu_q,rom_q,main_video_q,vram_video_q;wire [7:0] video_q=model80?vram_video_q:main_video_q;wire [13:0] va;
 always @(posedge clk)begin
  if(rom_wr)rom[rom_address[16:0]]<=rom_byte;
  rom_q<=rom[ri];
  if(mw&&!physical[16])begin ram[physical[15:0]]<=d;ram_q<=d;end else ram_q<=ram[physical[15:0]];
  if(mw&&(physical[16]||mirror))begin vram[physical[13:0]]<=d;vram_cpu_q<=d;end else vram_cpu_q<=vram[physical[13:0]];
 end
 wire mirror=model80&&basic&&mw&&a[15:14]==1;
 // Mirrored BASIC display writes use the independent VRAM port between fetches.
 always @(posedge clk)begin
  vram_video_q<=vram[va];main_video_q<=ram[{2'b01,va}];
 end
 wire [39:0] raw_keys;reg [39:0] keys;wire [511:0] pressed;
 // TAB is the original EXTEND sequence followed by P (CTRL+I in CP/M).
 reg old_tab=0;reg [23:0] tab_count=0;
 always @(posedge clk)begin
  old_tab<=pressed[9'h00d];
  if(video_reset)tab_count<=0;
  else if(pressed[9'h00d]&&!old_tab)tab_count<=24'd6720000;
  else if(tab_count!=0)tab_count<=tab_count-1'b1;
 end
 always @*begin
  keys=raw_keys;
  if(tab_count>4480000)begin keys[0]=0;keys[36]=0;end
  else if(tab_count!=0&&tab_count<2240000)keys[25]=0;
 end
 rp_keys key_events(.clk(clk),.reset(video_reset),.ps2_key(ps2_key),.pressed(pressed));
 wire [10:0] matrix_ps2={ps2_key[10:9],(ps2_key[8:0]==9'h014||ps2_key[8:0]==9'h114||ps2_key[8:0]==9'h076)?9'h1ff:ps2_key[8:0]};
 rp_spectrum_keyboard keyboard(.clk(clk),.reset(video_reset),.ps2_key(matrix_ps2),.joy0(32'd0),.joy1(32'd0),.keys_n(raw_keys),.tape_pause(),.tape_prev(),.tape_next(),.warm_reset());
 reg [5:0] key_data;integer k;
 wire [7:0] extra=~{pressed[9'h00c],pressed[9'h004],pressed[9'h006],pressed[9'h005],pressed[9'h076],pressed[9'h07e],pressed[9'h17c],pressed[9'h014]||pressed[9'h114]};
 always @*begin key_data=6'b111111;for(k=0;k<8;k=k+1)if(!a[k+8])key_data=key_data&{extra[k],keys[k*5+:5]};if(status[11])key_data[5]=gpio_in[8];end
 wire [7:0] pb=((status[11]?gpio_in[7:0]:8'd0)|{model80&&vint,7'd0}|{3'd0,joy0[4:0]});
 wire [1:0] ppi_address=a[7:0]==8'hdf ?2'd3:a[7:0]==8'h1f ?2'd1:ior?2'd0:2'd2;
 rp_i8255 ppi_device(.clk(clk),.reset(reset),.wr(wp&&(a[7:0]==8'hfe||a[7:0]==8'hdf)),.rd(rp&&(a[7:0]==8'hfe||a[7:0]==8'h1f)),.address(ppi_address),.din(d),
 .pa_in({serial_rx[0],ear,key_data}),.pb_in(pb),.pc_in(8'hff),.dout(ppi),.pa_out(),.pb_out(),.pc_out(pc),.pa_oe(),.pb_oe(),.pc_oe(pc_oe),.irq(),.control());
 reg [3:0] mounted=0;always @(posedge clk)if(video_reset)mounted<=0;else for(integer n=0;n<4;n=n+1)if(img_mounted[n])mounted[n]<=img_size!=0;
 wire [7:0] fdc_data;wire fdc_drq,fdc_irq;wire [3:0] zc;
 rp_u765 #(.CYCLES(2000)) fdc(.clk_sys(clk),.ce(fphase==6),.tc(zc[2]),.drq(fdc_drq),.irq(fdc_irq),.reset(reset),.ready(mounted),.motor(4'b1111),.available(mounted),.drive_8inch(status[15:12]),.fast(1'b0),
 .a0(a[3]),.nRD(!(ior&&(a[7:0]==8'hf5||a[7:0]==8'hfd))),.nWR(!(iow&&a[7:0]==8'hfd)),.din(d),.dout(fdc_data),.img_mounted(img_mounted),.img_wp(img_wp),.img_size(img_size),.sd_lba(sd_lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(sd_ack),.sd_buff_addr(sd_buff_addr),.sd_buff_dout(sd_buff_dout),.sd_buff_din(sd_buff_din),.sd_buff_wr(sd_buff_wr));
 wire [7:0] ctc_data,ctc_vector;wire ctc_irq;reg old_ack=0,old_fetch=0,last_ed=0,reti=0;
 wire acknowledge=!iorq_n&&!m1_n,fetch=!mreq_n&&!m1_n&&!rd_n;
 always @(posedge clk)begin
  old_ack<=acknowledge;old_fetch<=fetch;reti<=0;
  if(reset)begin last_ed<=0;old_ack<=0;old_fetch<=0;end
  else if(fetch&&!old_fetch)begin reti<=last_ed&&di==8'h4d;last_ed<=di==8'hed;end
 end
 rp_z80ctc ctc(.clk(clk),.reset(reset),.ce(cpu_p),.wr(wp&&a[7:5]==7&&a[2:0]==3),.channel(a[4:3]),.din(d),.dout(ctc_data),.acknowledge(acknowledge&&!old_ack),.reti(reti),.triggers({vint,zc[1],zc[0],fdc_irq||fdc_drq}),.zero(zc),.irq(ctc_irq),.vector(ctc_vector));
 always @*begin
  di=8'hff;
  if(!mreq_n)di=rom_sel?rom_q:physical[16]?vram_cpu_q:ram_q;
  else if(acknowledge)di=ctc_vector;
  else if(ior)begin
   if(a[7:0]==8'hfe||a[7:0]==8'h1f)di=ppi;
   else if(a[7:0]==8'hf5||a[7:0]==8'hfd)di=fdc_data;
   else if(a[7:5]==7&&a[2:0]==3)di=ctc_data;
  end
 end
 wire vint=video_y==248&&video_x<64;
 T80pa cpu(.RESET_n(!reset),.CLK(clk),.CEN_p(cpu_p),.CEN_n(cpu_n),.WAIT_n(1'b1),.INT_n(!(ctc_irq||basic&&vint)),.NMI_n(!(nmi||pressed[9'h009])),.BUSRQ_n(1'b1),
 .M1_n(m1_n),.MREQ_n(mreq_n),.IORQ_n(iorq_n),.RD_n(rd_n),.WR_n(wr_n),.RFSH_n(rfsh_n),.HALT_n(),.BUSAK_n(),.OUT0(1'b0),.A(a),.DI(di),.DO(d),.R800_mode(1'b0),.REG(regs),.DIRSet(1'b0),.DIR(212'd0));
 wire [8:0] x;rp_cobra_video #(.HAS_BRIGHT(1)) video(.clk(clk),.reset(video_reset),.ce_pixel(ce_pixel),.bright_enable(1'b1),.extended(!po&&cpm&&pc_pins[5]&&!status[9]),.upper_page(!po&&cpm),.border(pc_pins[2:0]),.ram_addr(va),.ram_data(video_q),.rgb(rgb),.bright(bright),.hs(hs),.vs(vs),.hblank(hblank),.vblank(vblank),.x(x),.y(video_y),.flash_count());
 assign video_x={1'b0,x};assign mic=pc_pins[3];assign audio_l={3'd0,pc_pins[4],mic,11'd0};assign audio_r=audio_l;
 assign serial_tx={4'b1111,pc_pins[7]};assign serial_dtr=5'b11110;assign serial_rts=5'b11111;assign gpio_out={18'h3ffff,pc_pins[5],5'b11111};assign gpio_oe={18'd0,pc_oe[5],5'd0};assign network_tx=1;assign printer_data=8'hff;assign printer_write=0;
 assign ext_req=0;assign ext_write=0;assign ext_address=0;assign ext_dout=0;assign rom_wait=0;assign boot_ready=1;
 assign debug_control={physical,pc_pins,3'd0,basic_lock,cpm,po,model80};
 assign debug_pc=regs[79:64];assign debug_regs=regs;assign debug_addr=a;assign debug_data=d;assign debug_in=di;assign debug_fetch=fetch;assign debug_io_wr=wp;assign debug_io_rd=rp;assign debug_mem_wr=mw;assign debug_cpu_p=cpu_p;
 `ifdef VERILATOR
 assign peek_ram=ram[peek_address];assign peek_vram=model80?vram[peek_address[13:0]]:ram[{2'b01,peek_address[13:0]}];
 `else
 assign peek_ram=0;assign peek_vram=0;
 `endif
endmodule
