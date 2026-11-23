// SPDX-License-Identifier: GPL-3.0-or-later
module emu(
 `include "sys/emu_ports.vh"
);
 wire clk_sys,locked;rp_pll pll(.refclk(CLK_50M),.rst(1'b0),.clk(clk_sys),.locked(locked));
 wire [127:0] status;wire [10:0] ps2_key;wire [31:0] joy0,joy1;wire [1:0] buttons;
 wire forced_scandoubler;wire [21:0] gamma_bus;
 wire download,wr;wire [26:0] address;wire [15:0] index;wire [7:0] data;
 localparam CONF_STR={
  "AMIC;;",
  "F2,TAPCSWTZXPZX,Load tape;",
  "T[3],Tape play/pause;",
  "T[4],Previous tape block;",
  "T[5],Next tape block;",
  "-;",
  "P1,System;",
  "P1O[10:9],Memory,32 KiB,16 KiB,48 KiB;",
  "P1F0,ROM,Load firmware;",
  "P2,Ports & Controllers;",
  "P2O[8:7],Serial baud,1200,600,300;",
  "P2O[22:20],User port,GPIO 0-5,GPIO 6-11,GPIO 12-17,GPIO 18-23;",
  "P3,Audio & Video;",
  "P3O[2],Tape sound,On,Off;",
  "P3O[61:60],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
  "P3O[58:57],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
  "-;",
  "R[0],Reset;",
  "J,Fire;",
  "V,v0.2"};
 wire [3:0] mounted,sd_read,sd_write,ack;wire [31:0] image_size,lba;wire image_wp;
 wire [13:0] buffer_address;wire [7:0] buffer_out,buffer_in;wire buffer_write,rom_wait;
 hps_io #(.CONF_STR(CONF_STR),.VDNUM(4)) hps_io(.clk_sys(clk_sys),.HPS_BUS(HPS_BUS),.status(status),.buttons(buttons),.forced_scandoubler(forced_scandoubler),.ps2_key(ps2_key),.joystick_0(joy0),.joystick_1(joy1),.gamma_bus(gamma_bus),
 .ioctl_download(download),.ioctl_wr(wr),.ioctl_addr(address),.ioctl_index(index),.ioctl_dout(data),.ioctl_wait(rom_wait),
 .img_mounted(mounted),.img_size(image_size),.img_readonly(image_wp),.sd_lba('{lba,lba,lba,lba}),.sd_blk_cnt('{6'd0,6'd0,6'd0,6'd0}),.sd_rd(sd_read),.sd_wr(sd_write),.sd_ack(ack),.sd_buff_addr(buffer_address),.sd_buff_dout(buffer_out),.sd_buff_din('{buffer_in,buffer_in,buffer_in,buffer_in}),.sd_buff_wr(buffer_write));
 wire firmware_download=download&&index[5:0]==0,tape_download=download&&index[5:0]==2;
 reg old_download=0,loaded=0,invalid=0;reg [19:0] count=0;
 always @(posedge clk_sys)begin
  old_download<=firmware_download;
  if(RESET)begin loaded<=0;invalid<=0;count<=0;end
  else begin
   if(firmware_download&&!old_download)begin loaded<=0;invalid<=0;count<=0;end
   if(firmware_download&&wr)begin if(address>=16384||address!=count)invalid<=1;else count<=count+1'b1;end
   if(old_download&&!firmware_download)loaded<=count==16384&&!invalid;
  end
 end
 wire [511:0] pressed;rp_keys controls(.clk(clk_sys),.reset(RESET),.ps2_key(ps2_key),.pressed(pressed));
 reg [4:0] old_model=0;reg [15:0] reset_count=16'hffff;
 wire hold=RESET||!locked||!loaded||firmware_download||status[0]||buttons[1]||pressed[9'h078]||old_model!=status[10:6];
 always @(posedge clk_sys)begin old_model<=status[10:6];if(hold)reset_count<=16'hffff;else if(reset_count!=0)reset_count<=reset_count-1'b1;end
 wire reset=hold||reset_count!=0;
 wire ce,hs,vs,hb,vb,bright,mic,boot_ready;wire [2:0] rgb;wire [15:0] left,right;
 wire tape_audio,tape_active,tape_available,tape_overflow;
 reg [26:0] tape_phase=0;wire ce_tape=tape_phase+3500000>=40000000;
 always @(posedge clk_sys)if(RESET||!locked)tape_phase<=0;else tape_phase<=ce_tape?tape_phase+3500000-40000000:tape_phase+3500000;
 rp_tape cassette(.clk(clk_sys),.reset(RESET),.ce(ce_tape),.mode48k(1'b1),.download(tape_download),.wr(wr),.address(address),.data(data),.mode(index[7:6]),.pause(pressed[9'h003]||status[3]),.prev(pressed[9'h00b]||status[4]),.next(pressed[9'h083]||status[5]),.audio(tape_audio),.active(tape_active),.available(tape_available),.overflow(tape_overflow));
 wire [4:0] serial_tx,serial_rts,serial_dtr;reg [1:0] rx_sync=3,ready_sync=3,cts_sync=3;reg [6:0] user_meta=127,user_sync=127;
 always @(posedge clk_sys)begin rx_sync<={rx_sync[0],UART_RXD};ready_sync<={ready_sync[0],UART_DSR};cts_sync<={cts_sync[0],UART_CTS};user_meta<=USER_IN;user_sync<=user_meta;end
 wire [2:0] uart_channel=status[18:16]<5?status[18:16]:3'd0;
 reg [4:0] serial_rx,serial_ready,serial_cts;reg [23:0] gpio_in;wire [23:0] gpio_out,gpio_oe;wire network_tx;
 always @*begin
  serial_rx=31;serial_ready=0;serial_cts=0;serial_rx[uart_channel]=rx_sync[1];serial_ready[uart_channel]=!ready_sync[1];serial_cts[uart_channel]=!cts_sync[1];
  gpio_in=24'hffffff;
  case(status[22:20])
   0:gpio_in[5:0]=user_sync[5:0];1:gpio_in[11:6]=user_sync[5:0];2:gpio_in[17:12]=user_sync[5:0];3:gpio_in[23:18]=user_sync[5:0];default:;
  endcase
 end
 wire ext_req,ext_write,ext_ack;wire [24:0] ext_address;wire [7:0] ext_dout,ext_din;
 wire [7:0] printer_data;wire printer_write;
 machine_core machine(.clk(clk_sys),.reset(reset),.video_reset(RESET||!locked),.nmi(pressed[9'h009]),.status(status),.ps2_key(ps2_key),.joy0(joy0),.joy1(joy1),
 .rom_wr(firmware_download&&wr&&address<16384),.rom_address(address[18:0]),.rom_byte(data),.ear(tape_active?tape_audio:1'b1),.serial_rx(serial_rx),.serial_ready(serial_ready),.serial_cts(serial_cts),.gpio_in(gpio_in),.network_rx(!user_sync[0]),
 .serial_tx(serial_tx),.serial_rts(serial_rts),.serial_dtr(serial_dtr),.gpio_out(gpio_out),.gpio_oe(gpio_oe),.network_tx(network_tx),.printer_data(printer_data),.printer_write(printer_write),.printer_busy(user_sync[6]),.printer_ack_n(user_sync[5]),
 .img_mounted(mounted),.img_wp(image_wp),.img_size(image_size),.sd_lba(lba),.sd_rd(sd_read),.sd_wr(sd_write),.sd_ack(|ack),.sd_buff_addr(buffer_address[8:0]),.sd_buff_dout(buffer_out),.sd_buff_din(buffer_in),.sd_buff_wr(buffer_write),
 .ext_req(ext_req),.ext_write(ext_write),.ext_address(ext_address),.ext_dout(ext_dout),.ext_ack(ext_ack),.ext_din(ext_din),.rom_wait(rom_wait),.boot_ready(boot_ready),
 .ce_pixel(ce),.hs(hs),.vs(vs),.hblank(hb),.vblank(vb),.rgb(rgb),.bright(bright),.video_x(),.video_y(),.audio_l(left),.audio_r(right),.mic(mic),.peek_address(16'd0));
 wire [7:0] level=bright?8'hff:8'hc0;
 assign CLK_VIDEO=clk_sys;
 wire [1:0] aspect=status[61:60];wire [1:0] video_fx=status[58:57];wire [1:0] video_sl=video_fx?video_fx-1'd1:2'd0;
 video_mixer #(.LINE_LENGTH(704),.GAMMA(1)) mixer(.CLK_VIDEO(clk_sys),.CE_PIXEL(CE_PIXEL),.ce_pix(ce),.scandoubler(video_fx!=0 || forced_scandoubler),.hq2x(video_fx==1),.gamma_bus(gamma_bus),
 .R(rgb[1]?level:8'd0),.G(rgb[2]?level:8'd0),.B(rgb[0]?level:8'd0),.HSync(!hs),.VSync(!vs),.HBlank(hb),.VBlank(vb),.HDMI_FREEZE(1'b0),.freeze_sync(),.VGA_R(VGA_R),.VGA_G(VGA_G),.VGA_B(VGA_B),.VGA_HS(VGA_HS),.VGA_VS(VGA_VS),.VGA_DE(VGA_DE));
 assign VIDEO_ARX=(!aspect)?13'd4:(aspect-1'd1);assign VIDEO_ARY=(!aspect)?13'd3:13'd0;
 assign AUDIO_L=left+{4'd0,(!status[2]&&tape_active&&tape_audio),11'd0};assign AUDIO_R=right+{4'd0,(!status[2]&&tape_active&&tape_audio),11'd0};assign AUDIO_S=0;assign AUDIO_MIX=0;
 reg [5:0] user_out;
 always @*case(status[22:20])
  0:user_out=gpio_out[5:0]|~gpio_oe[5:0];1:user_out=gpio_out[11:6]|~gpio_oe[11:6];2:user_out=gpio_out[17:12]|~gpio_oe[17:12];3:user_out=gpio_out[23:18]|~gpio_oe[23:18];default:user_out={5'b11111,!network_tx};
 endcase
 assign USER_OUT={1'b1,user_out};assign UART_TXD=serial_tx[uart_channel];assign UART_RTS=serial_rts[uart_channel];assign UART_DTR=serial_dtr[uart_channel];
 assign LED_USER=download||tape_active;assign LED_POWER=invalid||tape_overflow?2'b11:0;assign LED_DISK={1'b1,|sd_read|| |sd_write};
 assign BUTTONS=0;assign VGA_F1=0;assign VGA_SL=video_sl;assign VGA_SCALER=0;assign VGA_DISABLE=0;assign HDMI_FREEZE=0;assign HDMI_BLACKOUT=0;assign HDMI_BOB_DEINT=0;
 assign ADC_BUS='z;assign {SD_SCK,SD_MOSI,SD_CS}='z;
 assign DDRAM_CLK=clk_sys;assign DDRAM_BURSTCNT=0;assign DDRAM_ADDR=0;assign DDRAM_RD=0;assign DDRAM_DIN=0;assign DDRAM_BE=0;assign DDRAM_WE=0;
 assign ext_ack=0;assign ext_din=0;assign SDRAM_CLK=0;assign SDRAM_CKE=0;assign SDRAM_A=0;assign SDRAM_BA=0;assign SDRAM_DQ='z;assign {SDRAM_DQML,SDRAM_DQMH,SDRAM_nCS,SDRAM_nCAS,SDRAM_nRAS,SDRAM_nWE}='1;
endmodule
