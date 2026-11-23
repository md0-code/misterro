// SPDX-License-Identifier: GPL-3.0-or-later
// TIM-S and TIM-S Plus: native firmware, shadow RAM, documented 192K paging and external buses.
module machine_core(
 `include "rp_machine_ports.vh"
);
 wire plus=status[6];
 wire [15:0] a;wire [7:0] d;reg [7:0] di;wire mreq_n,iorq_n,rd_n,wr_n,m1_n,rfsh_n;wire [211:0] regs;
 wire iow=!iorq_n&&m1_n&&!wr_n,ior=!iorq_n&&m1_n&&!rd_n;
 reg old_iow=0,old_ior=0;always @(posedge clk)begin old_iow<=iow;old_ior<=ior;end
 wire wp=iow&&!old_iow,rp=ior&&!old_ior;
 wire [7:0] p1a,p1b,p1c,p1aoe,p1boe,p1coe,p2a,p2b,p2c,p2aoe,p2boe,p2coe,ppi1_data,ppi2_data;
 wire [7:0] control=(p1c&p1coe)|(~p1coe&(plus?8'hfe:8'hff)),control2=p2c|~p2coe;
 reg [7:0] page7=0,page1=0;reg boot_rom=1;
 reg [4:0] ula=0;reg [23:0] micronext=0;reg network=1,network_armed=0,network_nmi=0,old_network_rx=1;
 always @(posedge clk)begin
  old_network_rx<=network_rx;
  if(reset)begin page7<=0;page1<=0;boot_rom<=1;ula<=0;micronext<=0;network<=1;network_armed<=0;network_nmi<=0;old_network_rx<=1;end
  else begin
   if(network_armed&&old_network_rx&&!network_rx)begin network_nmi<=1;network_armed<=0;end
   if(network_nmi&&cpu_p&&!m1_n)network_nmi<=0;
   if(wp)begin
   if(!a[0])ula<=d[4:0];
   if(a==16'h7ffd)page7<=d;
   if(a==16'h1ffd)page1<=d;
   if(a[7:0]==8'hf0)boot_rom<=0;
   case(a[7:0])
    8'h0f:micronext[7:0]<=d;8'h1f:micronext[15:8]<=d;8'h2f:micronext[23:16]<=d;
    8'hf7:network<=d[0];8'hf3:network_armed<=1;
    default:;
   endcase
   end
  end
 end
 // Frequency changes alter clock enables; no generated or gated CPU clocks.
 reg [27:0] cpu_acc=0;reg cpu_half=0;
 wire turbo=plus?control[6]:control[3];
 wire [23:0] frequency=!turbo||status[8:7]==0?24'd3500000:status[8:7]==1?24'd6000000:status[8:7]==2?24'd7000000:24'd8000000;
 wire half_ce=cpu_acc+{frequency,1'b0}>=84000000;
 wire cpu_p=half_ce&&!cpu_half,cpu_n=half_ce&&cpu_half;
 always @(posedge clk)if(video_reset)begin cpu_acc<=0;cpu_half<=0;end else begin cpu_acc<=half_ce?cpu_acc+{frequency,1'b0}-84000000:cpu_acc+{frequency,1'b0};if(half_ce)cpu_half<=!cpu_half;end
 reg [2:0] pixel_phase=0;reg [5:0] pit_phase=0;reg [9:0] flash_phase=0;reg [2:0] fdc_phase=0;
 always @(posedge clk)if(video_reset)begin pixel_phase<=0;pit_phase<=0;flash_phase<=0;fdc_phase<=0;end else begin
  pixel_phase<=pixel_phase==5?0:pixel_phase+1'b1;pit_phase<=pit_phase==41?0:pit_phase+1'b1;flash_phase<=flash_phase==767?0:flash_phase+1'b1;
  fdc_phase<=fdc_phase==6?0:fdc_phase+1'b1;
 end
 assign ce_pixel=pixel_phase==5;
 (* ramstyle="M10K, no_rw_check" *) reg [7:0] rom[0:18431];
 reg [7:0] rom_q;wire eprom=plus?!control[0]:boot_rom;
 wire [14:0] rom_index=plus?15'd16384+{4'd0,a[10:0]}:{1'b0,a[13:0]};
 wire rom_selected=a[15:14]==0&&eprom;
 reg [3:0] bank;reg direct_video;reg [15:0] video_cpu_address;
 wire spectrum_mode=!plus||control[4];
 always @*begin
  bank={2'd0,a[15:14]};direct_video=0;video_cpu_address={p1a[6:5],page7[3],a[12:0]};
  if(plus)begin
   if(spectrum_mode)begin
    if(page1[0])begin
     case(page1[2:1])
      0:bank={2'd0,a[15:14]};
      1:bank=4'd4+{2'd0,a[15:14]};
      2:case(a[15:14])0:bank=4;1:bank=5;2:bank=6;3:bank=3;endcase
      3:case(a[15:14])0:bank=4;1:bank=7;2:bank=6;3:bank=3;endcase
     endcase
    end else case(a[15:14])
     0:bank=4'd8+{2'd0,page1[2],page7[4]};
     1:begin bank=5;direct_video=control[2]&&page7[2]&&!a[13];end
     2:bank=2;
     3:begin bank={control[2],page7[2:0]};if(control[2]&&page7[2])begin direct_video=1;video_cpu_address={page7[1:0],a[13:0]};end end
    endcase
   end else begin
    case(a[15:14])0:bank=11;1:bank=9;2:bank=10;3:bank=8;endcase
    if((a[15:14]==1||a[15:14]==2)&&page7[4]==!a[15])begin
     if(control[2]&&control[0]&&!page7[2])bank=4'd8+{2'd0,page7[1:0]};
     else if(!control[2]&&!control[1]&&!control[0])bank={1'b0,page7[2:0]};
     else if(control[2]&&!control[0]&&page7[2])direct_video=!a[13];
    end
   end
  end
 end
 wire protect_rom=plus?(!control[1]&&a[15:14]==0&&bank>=8):(!control[1]&&a[15:14]==0);
 wire ram_available=plus||control[4];
 wire mem_read=!mreq_n&&!rd_n&&rfsh_n,mem_write=!mreq_n&&!wr_n&&rfsh_n&&!reset;
 wire io_micronext=!iorq_n&&m1_n&&a[7:0]==8'h3f&&(!rd_n||!wr_n);
 wire wants_memory=(mem_read&&!rom_selected&&!direct_video&&ram_available)||(mem_write&&!direct_video&&!protect_rom&&ram_available)||io_micronext;
 wire [24:0] requested_address=io_micronext?(25'h1000000|{3'd0,micronext[21:0]}):{7'd0,bank,a[13:0]};
 wire requested_write=io_micronext?!wr_n:mem_write;
 // Firmware cache and RAM restoration share the same acknowledged physical SDRAM bus as the CPU.
 reg req=0,write=0;reg [24:0] memory_address=0;reg [7:0] memory_out=0,cpu_memory=0,restore_byte=0;
 reg [3:0] memory_state=0;reg cpu_done=0,firmware_pending=0,reset_restore=1,ready=0;
 reg [15:0] restore_index=0;reg [24:0] firmware_address=0;reg [7:0] firmware_byte=0;
 assign ext_req=req;assign ext_write=write;assign ext_address=memory_address;assign ext_dout=memory_out;
 assign rom_wait=firmware_pending||memory_state!=0;assign boot_ready=ready;
 always @(posedge clk)begin
  if(rom_wr&&rom_address<18432)rom[rom_address[14:0]]<=rom_byte;
  rom_q<=rom[rom_index];
  if(video_reset)begin memory_state<=0;req<=0;firmware_pending<=0;cpu_done<=0;reset_restore<=1;ready<=0;end
  else begin
   if(!wants_memory)cpu_done<=0;
   if(reset)begin reset_restore<=1;ready<=0;end
   if(rom_wr&&rom_address>=18432&&!rom_wait)begin firmware_pending<=1;firmware_address<=25'h40000+rom_address-18432;firmware_byte<=rom_byte;end
   case(memory_state)
    0:if(firmware_pending)begin req<=1;write<=1;memory_address<=firmware_address;memory_out<=firmware_byte;memory_state<=1;end
    else if(!reset&&reset_restore)begin reset_restore<=0;restore_index<=0;
     if(plus)begin req<=1;write<=0;memory_address<=25'h40000;memory_state<=3;end else ready<=1;
    end else if(ready&&wants_memory&&!cpu_done)begin req<=1;write<=requested_write;memory_address<=requested_address;memory_out<=d;memory_state<=2;end
    1:if(ext_ack)begin req<=0;firmware_pending<=0;memory_state<=7;end
    2:if(ext_ack)begin cpu_memory<=ext_din;req<=0;cpu_done<=1;memory_state<=7;end
    3:if(ext_ack)begin restore_byte<=ext_din;req<=0;memory_state<=4;end
    4:if(!ext_ack)begin req<=1;write<=1;memory_address<=25'h20000+restore_index;memory_out<=restore_byte;memory_state<=5;end
    5:if(ext_ack)begin req<=0;memory_state<=6;end
    6:if(!ext_ack)begin
     if(restore_index==65535)begin ready<=1;memory_state<=0;end
     else begin restore_index<=restore_index+1'b1;req<=1;write<=0;memory_address<=25'h40001+restore_index;memory_state<=3;end
    end
    7:if(!ext_ack)memory_state<=0;
    default:memory_state<=0;
   endcase
  end
 end
 (* ramstyle="M10K, no_rw_check" *) reg [7:0] vram[0:65535];
 reg [7:0] vram_q,video_q;wire [15:0] va;
 wire mirror=mem_write&&a[15:13]==2&&(!plus?!control[2]:control2[2]);
 wire video_write=mem_write&&direct_video||mirror;
 always @(posedge clk)begin
  if(video_write)begin vram[video_cpu_address]<=d;vram_q<=d;end else vram_q<=vram[video_cpu_address];
 end
 always @(posedge clk)video_q<=vram[va];
 wire [39:0] keys;wire [511:0] pressed;
 rp_keys key_events(.clk(clk),.reset(video_reset),.ps2_key(ps2_key),.pressed(pressed));
 wire [8:0] key_scan=ps2_key[8:0];
 reg old_keyboard_mode=1;
 always @(posedge clk)old_keyboard_mode<=spectrum_mode;
 wire keyboard_reset=video_reset||(old_keyboard_mode!=spectrum_mode);
 wire native_only=plus&&!spectrum_mode;
 wire [8:0] matrix_scan=native_only&&(ps2_key[8:0]==9'h014||ps2_key[8:0]==9'h114||ps2_key[8:0]==9'h076||ps2_key[8:0]==9'h066||ps2_key[8:0]==9'h171)?9'h1ff:
  plus&&spectrum_mode&&ps2_key[8:0]==9'h171 ? 9'h066:ps2_key[8:0];
 wire [10:0] matrix_ps2={ps2_key[10:9],matrix_scan};
 rp_spectrum_keyboard keyboard(.clk(clk),.reset(keyboard_reset),.ps2_key(matrix_ps2),.joy0(joy0),.joy1(joy1),.keys_n(keys),.tape_pause(),.tape_prev(),.tape_next(),.warm_reset());
 // Plus's two additional matrix rows appear on D5 and D7 at the normal keyboard port.
 wire [7:0] extra5=~{3'b000,pressed[9'h006],pressed[9'h00a],pressed[9'h058],pressed[9'h00d],pressed[9'h014]||pressed[9'h114]};
 wire [7:0] extra7=~{2'b00,pressed[9'h004],pressed[9'h005],pressed[9'h066],pressed[9'h07e],pressed[9'h171],pressed[9'h076]};
 reg [4:0] key_data;reg k5,k7;integer k;
 always @*begin key_data=31;k5=1;k7=1;for(k=0;k<8;k=k+1)if(!a[k+8])begin key_data=key_data&keys[k*5+:5];k5=k5&extra5[k];k7=k7&extra7[k];end end
 wire std_ppi=a[7:3]==5'b11100&&!a[0];
 wire plus_ppi1=a[15:10]==3&&a[7:0]==8'hfd;
 wire [1:0] ppi1_address=plus?{!a[9],a[8]}:a[2:1];
 wire [7:0] ppi1_in=plus?gpio_in[7:0]:{printer_busy,ear,serial_ready[0],key_data};
 rp_i8255 ppi1(.clk(clk),.reset(reset),.wr(wp&&(plus?plus_ppi1:std_ppi)),.rd(rp&&(plus?plus_ppi1:std_ppi||a[7:0]==8'hfe||a[7:0]==8'hf9)),.address(!plus&&(a[7:0]==8'hfe||a[7:0]==8'hf9)?2'd0:ppi1_address),.din(d),
 .pa_in(ppi1_in),.pb_in({7'b1111111,printer_busy}),.pc_in(8'h00),.dout(ppi1_data),.pa_out(p1a),.pb_out(p1b),.pc_out(p1c),.pa_oe(p1aoe),.pb_oe(p1boe),.pc_oe(p1coe),.irq(),.control());
 wire ppi2_sel=plus&&a[15:10]==6'h17&&a[7:0]==8'hfd;
 rp_i8255 ppi2(.clk(clk),.reset(reset),.wr(wp&&ppi2_sel),.rd(rp&&ppi2_sel),.address(a[9:8]),.din(d),.pa_in(gpio_in[15:8]),.pb_in(gpio_in[7:0]),.pc_in({gpio_in[23],!vs,turbo,!fdc_irq,printer_ack_n,4'b1111}),.dout(ppi2_data),.pa_out(p2a),.pb_out(p2b),.pc_out(p2c),.pa_oe(p2aoe),.pb_oe(p2boe),.pc_oe(p2coe),.irq(),.control());
 wire [7:0] pit_data,mux_pit_data;wire [2:0] pit_out,mux_pit_out;
 wire pit_sel=plus&&a[15:10]==6'h27&&a[7:0]==8'hfd,mux_pit_sel=plus&&a[15:10]==6'h23&&a[7:0]==8'hfd;
 rp_i8253 pit(.clk(clk),.reset(reset),.wr(wp&&pit_sel),.rd(rp&&pit_sel),.address(a[9:8]),.din(d),.clocks({pit_phase==41,flash_phase==767,pit_phase==41}),.gates(3'b111),.dout(pit_data),.out(pit_out));
 rp_i8253 mux_pit(.clk(clk),.reset(reset),.wr(wp&&mux_pit_sel),.rd(rp&&mux_pit_sel),.address(a[9:8]),.din(d),.clocks({3{pit_phase==41}}),.gates(3'b111),.dout(mux_pit_data),.out(mux_pit_out));
 reg [2:0] old_pit=0,old_mux_pit=0;always @(posedge clk)begin old_pit<=pit_out;old_mux_pit<=mux_pit_out;end
 wire [4:0] uart_clocks={pit_out[2]&&!old_pit[2],mux_pit_out&~old_mux_pit,pit_out[0]&&!old_pit[0]};
 reg [3:0] serial_mux=0;always @(posedge clk)if(reset)serial_mux<=0;else if(wp&&a==16'haffd)serial_mux<=d[3:0];
 wire [7:0] serial_data[0:4];wire [4:0] uart_tx,uart_rts,uart_dtr;
 genvar u;generate for(u=0;u<5;u=u+1)begin:usarts
  wire select=u==0?(a==16'hdefd||a==16'hdffd):((a==16'hcffd||a==16'heffd)&&serial_mux[1:0]==u-1);
  rp_i8251 uart(.clk(clk),.reset(reset),.wr(wp&&plus&&select),.rd(rp&&plus&&select),.command_port(u==0?a[8]:a[13]),.din(d),.txc(uart_clocks[u]),.rxc(uart_clocks[u]),.rx(serial_rx[u]),.cts_n(!serial_cts[u]),.dsr_n(!serial_ready[u]),.external_sync(1'b0),.dout(serial_data[u]),.tx(uart_tx[u]),.rts_n(uart_rts[u]),.dtr_n(uart_dtr[u]),.tx_ready(),.rx_ready(),.tx_empty(),.sync_detect());
 end endgenerate
 reg [3:0] mounted=0;always @(posedge clk)if(video_reset)mounted<=0;else for(integer n=0;n<2;n=n+1)if(img_mounted[n])mounted[n]<=img_size!=0;
 wire [7:0] fdc_data;wire fdc_irq,fdc_drq;
 rp_u765 #(.CYCLES(3000)) fdc(.clk_sys(clk),.ce(fdc_phase==6),.tc(1'b0),.drq(fdc_drq),.irq(fdc_irq),.reset(reset),.ready(mounted),.motor({2'd0,{2{!plus||page1[3]}}}),.available(mounted),.drive_8inch(4'd0),.fast(1'b0),.a0(a[12]),.nRD(!(ior&&(a==16'h2ffd||a==16'h3ffd))),.nWR(!(iow&&a==16'h3ffd)),.din(d),.dout(fdc_data),.img_mounted({2'd0,img_mounted[1:0]}),.img_wp(img_wp),.img_size(img_size),.sd_lba(sd_lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(sd_ack),.sd_buff_addr(sd_buff_addr),.sd_buff_dout(sd_buff_dout),.sd_buff_din(sd_buff_din),.sd_buff_wr(sd_buff_wr));
 wire [7:0] ay_data,channel_a,channel_b,channel_c;reg [4:0] ay_phase=0;
 always @(posedge clk)if(video_reset)ay_phase<=0;else ay_phase<=ay_phase==23?0:ay_phase+1'b1;
 rp_ay ay(.CLK(clk),.CE(ay_phase==23),.RESET(reset),.BDIR(wp&&plus&&(a==16'hfffd||a==16'hbffd)),.BC(a[14]),.DI(d),.DO(ay_data),.CHANNEL_A(channel_a),.CHANNEL_B(channel_b),.CHANNEL_C(channel_c),.LEVEL_A(),.LEVEL_B(),.LEVEL_C(),.SEL(1'b1),.MODE(1'b0),.ACTIVE(),.IOA_in(gpio_in[7:0]),.IOA_out(),.IOB_in(8'hff),.IOB_out());
 reg [4:0] frames=0;reg old_vs=1,flash=0,timer_flash=0;
 always @(posedge clk)begin old_vs<=vs;if(video_reset)begin frames<=0;flash<=0;timer_flash<=0;end else begin
  if(old_vs&&!vs)frames<=frames+1'b1;
  if(wp&&pit_sel&&a[9:8]==3&&d[7:6]==1)timer_flash<=1;
  if(pit_out[1]&&!old_pit[1])flash<=!flash;
 end end
 rp_tims_video video(.clk(clk),.reset(video_reset),.ce(ce_pixel),.wide(plus&&!p1a[1]),.hires(plus&&p1a[2]),.inhibit_attributes(plus&&p1a[0]),.border(ula[2:0]),.display_page(plus?{p1a[4:3],page7[3]}:3'd0),.scroll(plus?p2a:8'd0),.flash(plus&&timer_flash?flash:frames[4]),.address(va),.data(video_q),.rgb(rgb),.bright(bright),.hs(hs),.vs(vs),.hblank(hblank),.vblank(vblank),.x(video_x),.y(video_y));
 wire acknowledge=!iorq_n&&!m1_n;
 always @*begin
  di=8'hff;
  if(!mreq_n)di=rom_selected?rom_q:direct_video?vram_q:ram_available?cpu_memory:8'hff;
  else if(ior)begin
   if(!a[0])di=plus?{k7,ear,k5,key_data}:ppi1_data;
   else if(plus_ppi1&&plus||std_ppi&&!plus||!plus&&a[7:0]==8'hf9)di=ppi1_data;
   else if(ppi2_sel)di=ppi2_data;
   else if(pit_sel)di=pit_data;else if(mux_pit_sel)di=mux_pit_data;
   else if(a==16'hdefd||a==16'hdffd)di=serial_data[0];
   else if(a==16'hcffd||a==16'heffd)di=serial_data[{1'b0,serial_mux[1:0]}+1'b1];
   else if(a==16'h2ffd||a==16'h3ffd)di=fdc_data;
   else if(a==16'hfffd&&plus)di=ay_data;
   else if(a[7:0]==8'hf7)di={7'b1111111,network_rx};
   else if(io_micronext)di=cpu_memory;
  end
 end
 T80pa cpu(.RESET_n(!(reset||!ready)),.CLK(clk),.CEN_p(cpu_p),.CEN_n(cpu_n),.WAIT_n(!(wants_memory&&!cpu_done)),.INT_n(!(video_y==248&&video_x<128)),.NMI_n(!(nmi||pressed[9'h009]||network_nmi)),.BUSRQ_n(1'b1),
 .M1_n(m1_n),.MREQ_n(mreq_n),.IORQ_n(iorq_n),.RD_n(rd_n),.WR_n(wr_n),.RFSH_n(rfsh_n),.HALT_n(),.BUSAK_n(),.OUT0(1'b0),.A(a),.DI(di),.DO(d),.R800_mode(1'b0),.REG(regs),.DIRSet(1'b0),.DIR(212'd0));
 assign mic=ula[3];assign audio_l={3'd0,ula[4],ula[3],11'd0}+(plus?({8'd0,channel_a}<<4)+({8'd0,channel_b}<<3)+({8'd0,channel_c}<<2):16'd0);
 assign audio_r={3'd0,ula[4],ula[3],11'd0}+(plus?({8'd0,channel_a}<<2)+({8'd0,channel_b}<<3)+({8'd0,channel_c}<<4):16'd0);
 assign serial_tx=plus?uart_tx:{4'b1111,control[0]};assign serial_rts=plus?uart_rts:5'b11110;assign serial_dtr=plus?uart_dtr:5'b11110;assign network_tx=!network;
 assign gpio_out={p2c,p1b,p2a};assign gpio_oe={p2coe,p1boe,p2aoe};assign printer_data=p1b;
 reg old_strobe=1;wire strobe=plus?page1[4]:p1b[7];always @(posedge clk)old_strobe<=strobe;
 assign printer_write=!reset&&ready&&old_strobe&&!strobe;
 assign debug_control={memory_address[17:0],ready,reset_restore,memory_state,control};
 assign debug_pc=regs[79:64];assign debug_regs=regs;assign debug_addr=a;assign debug_data=d;assign debug_in=di;assign debug_fetch=!mreq_n&&!m1_n&&!rd_n;assign debug_io_wr=wp;assign debug_io_rd=rp;assign debug_mem_wr=mem_write;assign debug_cpu_p=cpu_p;
 assign peek_ram=cpu_memory;
 `ifdef VERILATOR
 assign peek_vram=vram[peek_address];
 `else
 assign peek_vram=0;
 `endif
endmodule
