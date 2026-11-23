// SPDX-License-Identifier: GPL-3.0-or-later
// Native aMIC/PRAE buses. Machine-specific selection changes documented wiring only.
module rp_native_machine #(parameter PRAE=0)(
 `include "rp_machine_ports.vh"
);
 reg [3:0] phase=0;always @(posedge clk)if(video_reset)phase<=0;else phase<=phase+1'b1;
 wire cpu_p=phase==15,cpu_n=phase==7;
 assign ce_pixel=phase[2:0]==7;
 wire [15:0] a;wire [7:0] d;reg [7:0] di;
 wire mreq_n,iorq_n,rd_n,wr_n,m1_n,rfsh_n;wire [211:0] regs;
 wire iow=!iorq_n&&m1_n&&!wr_n,ior=!iorq_n&&m1_n&&!rd_n;
 reg old_iow=0,old_ior=0;always @(posedge clk)begin old_iow<=iow;old_ior<=ior;end
 wire wp=iow&&!old_iow,rp=ior&&!old_ior;
 (* ramstyle="M10K, no_rw_check" *) reg [7:0] ram[0:65535];
 (* ramstyle="M10K, no_rw_check" *) reg [7:0] rom[0:(PRAE?32767:16383)];
 reg [7:0] rom_q,ram_q,video_q;
 wire [14:0] ri={PRAE&&status[6],a[13:0]};wire [12:0] va;
 wire [15:0] vphysical={PRAE?3'b111:3'b010,va};
 wire populated=PRAE || (status[10:9]==2 ? 1'b1 : status[10:9]==1 ? a<16'h8000 : a<16'hc000);
 wire mw=populated&&!reset&&!mreq_n&&!wr_n&&rfsh_n&&a>=16'h4000;
 always @(posedge clk)begin
  if(rom_wr)rom[rom_address[(PRAE?14:13):0]]<=rom_byte;
  rom_q<=rom[ri];
  if(mw)begin ram[a]<=d;ram_q<=d;end else ram_q<=ram[a];
 end
 always @(posedge clk)video_q<=ram[vphysical];
 wire [511:0] pressed;wire [63:0] matrix;wire [2:0] modifiers_raw;wire [2:0] modifiers={~caps_lock,modifiers_raw[1:0]};reg caps_lock=0,old_caps=0;
 always @(posedge clk)begin old_caps<=pressed[9'h058];if(video_reset)begin caps_lock<=0;old_caps<=0;end else if(pressed[9'h058]&&!old_caps)caps_lock<=!caps_lock;end
 rp_keys keys(.clk(clk),.reset(video_reset),.ps2_key(ps2_key),.pressed(pressed));
 rp_native_keyboard #(.PRAE(PRAE)) keyboard(.pressed(pressed),.matrix_n(matrix),.modifiers_n(modifiers_raw));
 wire [7:0] p1a,p1b,p1c,p2a,p2b,p2c,pa_oe,pb_oe,pc_oe;
 wire [7:0] p1out,p2out;wire [7:0] control1,control2;
 wire [7:0] c1oe,c1=p1c|~c1oe;
 wire [7:0] keyboard_row=matrix[c1[2:0]*8+:8];
 wire [7:0] keyboard_flags={modifiers,4'b1111,ear};
 rp_i8255 ppi1(.clk(clk),.reset(reset),.wr(wp&&a[7:2]==8),.rd(rp&&a[7:2]==8),.address(a[1:0]),.din(d),
 .pa_in(keyboard_row),.pb_in(keyboard_flags),.pc_in(8'hff),.dout(p1out),.pa_out(p1a),.pb_out(p1b),.pc_out(p1c),.pa_oe(),.pb_oe(),.pc_oe(c1oe),.irq(),.control(control1));
 wire [23:0] expansion_input=gpio_in&~{19'd0,joy0[4:0]};
 rp_i8255 ppi2(.clk(clk),.reset(reset),.wr(wp&&a[7:2]==16),.rd(rp&&a[7:2]==16),.address(a[1:0]),.din(d),
 .pa_in(expansion_input[7:0]),.pb_in(expansion_input[15:8]),.pc_in(expansion_input[23:16]),.dout(p2out),.pa_out(p2a),.pb_out(p2b),.pc_out(p2c),.pa_oe(pa_oe),.pb_oe(pb_oe),.pc_oe(pc_oe),.irq(),.control(control2));
 // 8251 clock is 16 times the selected physical baud switch setting.
 reg [25:0] baud_phase=0;wire [15:0] baud=status[8:7]==1?16'd9600:status[8:7]==2?16'd4800:16'd19200;
 wire baud_ce=baud_phase+baud>=40000000;
 always @(posedge clk)if(video_reset)baud_phase<=0;else baud_phase<=baud_ce?baud_phase+baud-40000000:baud_phase+baud;
 wire [7:0] uart;wire tx,rts,dtr;
 rp_i8251 serial(.clk(clk),.reset(reset),.wr(wp&&a[7:1]==0),.rd(rp&&a[7:1]==0),.command_port(a[0]),.din(d),
 .external_sync(1'b0),.txc(baud_ce),.rxc(baud_ce),.rx(serial_rx[0]),.cts_n(!serial_cts[0]),.dsr_n(!serial_ready[0]),.dout(uart),.tx(tx),.rts_n(rts),.dtr_n(dtr),.tx_ready(),.rx_ready(),.tx_empty(),.sync_detect());
 reg [7:0] latch=8'h40;always @(posedge clk)if(reset)latch<=8'h40;else if(wp&&a[7:0]==8'h80)latch<=d;
 reg [4:0] prae_keys;integer k;
 always @*begin prae_keys=5'b11111;for(k=0;k<8;k=k+1)if(!a[k+8])prae_keys=prae_keys&matrix[k*8+:5];end
 always @*begin
  di=8'hff;
  if(!mreq_n)di=a<16'h4000 ?rom_q:populated?ram_q:8'hff;
  else if(ior)begin
   if(PRAE)begin if(a[7:0]==8'h80)di={ear,serial_rx[0],1'b1,prae_keys};end
   else if(a[7:1]==0)di=uart;
   else if(a[7:2]==8)di=p1out;
   else if(a[7:2]==16)di=p2out;
  end
 end
 // PRAE's 50 Hz maskable interrupt provides its documented CLOCK tick.
 wire int_n=!(PRAE&&video_y==256&&video_x<16);
 T80pa cpu(.RESET_n(!reset),.CLK(clk),.CEN_p(cpu_p),.CEN_n(cpu_n),.WAIT_n(1'b1),.INT_n(int_n),.NMI_n(!(nmi||pressed[9'h009])),.BUSRQ_n(1'b1),
 .M1_n(m1_n),.MREQ_n(mreq_n),.IORQ_n(iorq_n),.RD_n(rd_n),.WR_n(wr_n),.RFSH_n(rfsh_n),.HALT_n(),.BUSAK_n(),.OUT0(1'b0),.A(a),.DI(di),.DO(d),.R800_mode(1'b0),.REG(regs),.DIRSet(1'b0),.DIR(212'd0));
 rp_mono_video video(.clk(clk),.reset(video_reset),.ce(ce_pixel),.invert(!PRAE&&c1[5]),.data(video_q),.address(va),.rgb(rgb),.hs(hs),.vs(vs),.hblank(hblank),.vblank(vblank),.x(video_x),.y(video_y));
 assign bright=1;assign mic=PRAE?latch[7]:c1[7];
 assign audio_l={3'b000,PRAE?latch[7]:c1[3],mic,11'd0};assign audio_r=audio_l;
 assign serial_tx={4'b1111,PRAE?latch[6]:tx};assign serial_rts={4'b1111,PRAE?1'b0:rts};assign serial_dtr={4'b1111,PRAE?1'b0:dtr};
 assign gpio_out=PRAE?24'hffffff:{p2c,p2b,p2a};assign gpio_oe=PRAE?24'd0:{pc_oe,pb_oe,pa_oe};
 assign printer_data=8'hff;assign printer_write=0;assign network_tx=1;
 assign sd_lba=0;assign sd_rd=0;assign sd_wr=0;assign sd_buff_din=0;
 assign ext_req=0;assign ext_write=0;assign ext_address=0;assign ext_dout=0;
 assign rom_wait=0;assign boot_ready=1;
 assign debug_control={p1c,control1,control2,8'd0};
 assign debug_pc=regs[79:64];assign debug_regs=regs;assign debug_addr=a;assign debug_data=d;assign debug_in=di;
 assign debug_fetch=!mreq_n&&!m1_n&&!rd_n;assign debug_io_wr=wp;assign debug_io_rd=rp;assign debug_mem_wr=mw;assign debug_cpu_p=cpu_p;
 `ifdef VERILATOR
 assign peek_ram=ram[peek_address];assign peek_vram=ram[{PRAE?3'b111:3'b010,peek_address[12:0]}];
 `else
 assign peek_ram=0;assign peek_vram=0;
 `endif
endmodule
