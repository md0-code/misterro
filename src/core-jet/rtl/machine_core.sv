// SPDX-License-Identifier: GPL-3.0-or-later
module machine_core(
 `include "rp_machine_ports.vh"
);
 reg [3:0] phase=0;always @(posedge clk)if(video_reset)phase<=0;else phase<=phase+1'b1;
 wire cpu_p=phase==15,cpu_n=phase==7;assign ce_pixel=phase[2:0]==7;
 wire [15:0] a;wire [7:0] d;reg [7:0] di;wire mreq_n,iorq_n,rd_n,wr_n,m1_n,rfsh_n;wire [211:0] regs;
 (* ramstyle="M10K, no_rw_check" *) reg [7:0] ram[0:65535];
 (* ramstyle="M10K, no_rw_check" *) reg [7:0] rom[0:16383];
 reg [7:0] ram_q,rom_q,video_q;wire [13:0] va;
 wire mw=!reset&&!mreq_n&&!wr_n&&rfsh_n&&a[15:14]!=0;
 always @(posedge clk)begin
  if(rom_wr)rom[rom_address[13:0]]<=rom_byte;
  rom_q<=rom[a[13:0]];
  if(mw)begin ram[a]<=d;ram_q<=d;end else ram_q<=ram[a];
 end
 always @(posedge clk)video_q<=ram[{2'b01,va}];
 wire iow=!iorq_n&&m1_n&&!wr_n,ior=!iorq_n&&m1_n&&!rd_n;
 reg old_iow=0,old_ior=0;always @(posedge clk)begin old_iow<=iow;old_ior<=ior;end
 wire wp=iow&&!old_iow,rp=ior&&!old_ior;
 reg [4:0] ula=0;always @(posedge clk)if(reset)ula<=0;else if(wp&&!a[0])ula<=d[4:0];
 wire [39:0] keys_n;rp_spectrum_keyboard keyboard(.clk(clk),.reset(video_reset),.ps2_key(ps2_key),.joy0(32'd0),.joy1(32'd0),.keys_n(keys_n),.tape_pause(),.tape_prev(),.tape_next(),.warm_reset());
 reg [4:0] key_data;integer row;
 always @*begin key_data=5'b11111;for(row=0;row<8;row=row+1)if(!a[row+8])key_data=key_data&keys_n[row*5+:5];end
 always @*begin
  di=8'hff;
  if(!mreq_n)di=a[15:14]==0?rom_q:ram_q;
  else if(ior)begin if(!a[0])di={1'b1,ear,1'b1,key_data};else if(a[7:0]==8'h1f)di={3'd0,joy0[4:0]};end
 end
 T80pa cpu(.RESET_n(!reset),.CLK(clk),.CEN_p(cpu_p),.CEN_n(cpu_n),.WAIT_n(1'b1),.INT_n(!(video_y==248&&video_x<64)),.NMI_n(!nmi),.BUSRQ_n(1'b1),
 .M1_n(m1_n),.MREQ_n(mreq_n),.IORQ_n(iorq_n),.RD_n(rd_n),.WR_n(wr_n),.RFSH_n(rfsh_n),.HALT_n(),.BUSAK_n(),.OUT0(1'b0),.A(a),.DI(di),.DO(d),.R800_mode(1'b0),.REG(regs),.DIRSet(1'b0),.DIR(212'd0));
 wire [8:0] x;rp_spectrum_video #(.HAS_BRIGHT(1)) video(.clk(clk),.reset(video_reset),.ce_pixel(ce_pixel),.bright_enable(1'b1),.border(ula[2:0]),.ram_addr(va),.ram_data(video_q),.rgb(rgb),.bright(bright),.hs(hs),.vs(vs),.hblank(hblank),.vblank(vblank),.x(x),.y(video_y),.flash_count());
 assign video_x={1'b0,x};assign mic=ula[3];assign audio_l={3'd0,ula[4],ula[3],11'd0};assign audio_r=audio_l;
 assign serial_tx=5'b11111;assign serial_rts=5'b11111;assign serial_dtr=5'b11111;assign gpio_out=24'hffffff;assign gpio_oe=0;assign network_tx=1;assign printer_data=8'hff;assign printer_write=0;
 assign sd_lba=0;assign sd_rd=0;assign sd_wr=0;assign sd_buff_din=0;assign ext_req=0;assign ext_write=0;assign ext_address=0;assign ext_dout=0;assign rom_wait=0;assign boot_ready=1;
 assign debug_control={27'd0,ula};
 assign debug_pc=regs[79:64];assign debug_regs=regs;assign debug_addr=a;assign debug_data=d;assign debug_in=di;assign debug_fetch=!mreq_n&&!m1_n&&!rd_n;assign debug_io_wr=wp;assign debug_io_rd=rp;assign debug_mem_wr=mw;assign debug_cpu_p=cpu_p;
 `ifdef VERILATOR
 assign peek_ram=ram[peek_address];assign peek_vram=ram[{2'b01,peek_address[13:0]}];
 `else
 assign peek_ram=0;assign peek_vram=0;
 `endif
endmodule
