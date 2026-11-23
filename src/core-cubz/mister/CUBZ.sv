// SPDX-License-Identifier: GPL-3.0-or-later
module emu (
 `include "sys/emu_ports.vh"
);
 wire clk_sys,locked;
 cubz_pll pll(.refclk(CLK_50M),.rst(1'b0),.clk(clk_sys),.locked(locked));
 wire [127:0] status;wire [10:0] ps2_key;wire [1:0] buttons;wire forced_scandoubler;wire [21:0] gamma_bus;
 wire download,wr;wire [26:0] address;wire [15:0] index;wire [7:0] data;
 wire [1:0] mounted,sd_read,sd_write,ack;wire [31:0] image_size;wire image_wp;
 wire [31:0] lba;wire [13:0] buffer_address;wire [7:0] buffer_out,buffer_in;wire buffer_write;
 localparam CONF_STR={
  "CUBZ;;",
  "S0,DSK,Floppy A:;",
  "S1,DSK,Floppy B:;",
  "-;",
  "P1,System;",
  "P1F0,ROM,Load firmware;",
  "P2,Ports & Controllers;",
  "P2O[3],User port,Serial B,PIO port A;",
  "P3,Audio & Video;",
  "P3O[2],Monitor,White,Green;",
  "P3O[61:60],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
  "P3O[58:57],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
  "-;",
  "R[0],Reset;",
  "V,v0.2"};
 hps_io #(.CONF_STR(CONF_STR),.VDNUM(2)) hps_io(
 .clk_sys(clk_sys),.HPS_BUS(HPS_BUS),.status(status),.ps2_key(ps2_key),.buttons(buttons),
 .forced_scandoubler(forced_scandoubler),.gamma_bus(gamma_bus),
 .ioctl_download(download),.ioctl_wr(wr),.ioctl_addr(address),.ioctl_index(index),.ioctl_dout(data),.ioctl_wait(1'b0),
 .img_mounted(mounted),.img_size(image_size),.img_readonly(image_wp),
 .sd_lba('{lba,lba}),.sd_blk_cnt('{6'd0,6'd0}),.sd_rd(sd_read),.sd_wr(sd_write),.sd_ack(ack),
 .sd_buff_addr(buffer_address),.sd_buff_dout(buffer_out),.sd_buff_din('{buffer_in,buffer_in}),.sd_buff_wr(buffer_write));
 wire firmware_download=download && index[5:0]==0;
 reg old_download,loaded=0,invalid=0;reg [13:0] bytes_written=0;
 always @(posedge clk_sys)begin
  old_download<=firmware_download;
  if(RESET)begin loaded<=0;invalid<=0;bytes_written<=0;end
  else begin
   if(firmware_download && !old_download)begin loaded<=0;invalid<=0;bytes_written<=0;end
   if(firmware_download && wr)begin
    if(address>=8192 || address!={13'd0,bytes_written})invalid<=1;
    else bytes_written<=bytes_written+1'b1;
   end
   if(old_download && !firmware_download)loaded<=bytes_written==8192 && !invalid;
  end
 end
 reg key_event,reset_key;
 always @(posedge clk_sys)begin
  key_event<=ps2_key[10];reset_key<=0;
  if(key_event!=ps2_key[10] && ps2_key[9] && ps2_key[7:0]==8'h78)reset_key<=1;
 end
 reg [15:0] reset_count=16'hffff;
 wire hold=RESET || !locked || !loaded || firmware_download || status[0] || buttons[1] || reset_key;
 always @(posedge clk_sys)if(hold)reset_count<=16'hffff;else if(reset_count!=0)reset_count<=reset_count-1'b1;
 wire pixel,hs,vs,hb,vb,ce,beeper;
 // SIO channel A: MiSTer's UART pins. User port: SIO channel B (RX 0, TX 1, RTS 2, CTS 3, DTR 4, DCD 6)
 // or bits 0-6 of the GPZ board's PIO port A, driven low or released.
 wire user_serial=!status[3];wire [1:0] serial_tx,serial_rts_n,serial_dtr_n;wire [7:0] gpio_out,gpio_drive;
 cubz_core machine(.clk(clk_sys),.reset(hold || reset_count!=0),.video_reset(RESET || !locked),.ps2_key(ps2_key),
 .rom_wr(firmware_download && wr && address<8192),.rom_addr(address[12:0]),.rom_data(data),
 .img_mounted(mounted),.img_wp(image_wp),.img_size(image_size),
 .sd_lba(lba),.sd_rd(sd_read),.sd_wr(sd_write),.sd_ack(|ack),
 .sd_buff_addr(buffer_address[8:0]),.sd_buff_dout(buffer_out),.sd_buff_din(buffer_in),.sd_buff_wr(buffer_write),
 .serial_rx({user_serial?USER_IN[0]:1'b1,UART_RXD}),.serial_cts_n({user_serial?USER_IN[3]:1'b1,UART_CTS}),.serial_dcd_n({user_serial?USER_IN[6]:1'b1,UART_DSR}),
 .serial_tx(serial_tx),.serial_rts_n(serial_rts_n),.serial_dtr_n(serial_dtr_n),
 .gpio_a_in(user_serial?8'hff:{1'b1,USER_IN[6:0]}),.gpio_a_out(gpio_out),.gpio_a_drive(gpio_drive),
 .ce_pixel(ce),.pixel(pixel),.hs(hs),.vs(vs),.hblank(hb),.vblank(vb),.beeper(beeper),.peek_addr(16'd0));
 assign CLK_VIDEO=clk_sys;
 wire [1:0] aspect=status[61:60];wire [1:0] video_fx=status[58:57];wire [1:0] video_sl=video_fx?video_fx-1'd1:2'd0;
 video_mixer #(.LINE_LENGTH(640),.GAMMA(1)) mixer(.CLK_VIDEO(clk_sys),.CE_PIXEL(CE_PIXEL),.ce_pix(ce),
 .scandoubler(video_fx!=0 || forced_scandoubler),.hq2x(video_fx==1),.gamma_bus(gamma_bus),
 .R(pixel?(status[2]?8'h30:8'hff):8'd0),.G(pixel?8'hff:8'd0),.B(pixel?(status[2]?8'h30:8'hff):8'd0),
 .HSync(!hs),.VSync(!vs),.HBlank(hb),.VBlank(vb),.HDMI_FREEZE(1'b0),.freeze_sync(),
 .VGA_R(VGA_R),.VGA_G(VGA_G),.VGA_B(VGA_B),.VGA_HS(VGA_HS),.VGA_VS(VGA_VS),.VGA_DE(VGA_DE));
 assign VIDEO_ARX=(!aspect)?13'd4:(aspect-1'd1);assign VIDEO_ARY=(!aspect)?13'd3:13'd0;
 assign AUDIO_L={2'd0,beeper,13'd0};assign AUDIO_R=AUDIO_L;assign AUDIO_S=0;assign AUDIO_MIX=0;
 assign LED_USER=download;assign LED_POWER=invalid?2'b11:0;assign LED_DISK={1'b1,|sd_read || |sd_write};
    assign BUTTONS = 0;
    assign VGA_F1 = 0;
    assign VGA_SL=video_sl;
    assign VGA_SCALER = 0;
    assign VGA_DISABLE = 0;
    assign HDMI_FREEZE = 0;
    assign HDMI_BLACKOUT = 0;
    assign HDMI_BOB_DEINT = 0;
    assign USER_OUT = user_serial ? {2'b11,serial_dtr_n[1],1'b1,serial_rts_n[1],serial_tx[1],1'b1} : (gpio_out[6:0] | ~gpio_drive[6:0]);
    assign {UART_RTS, UART_TXD, UART_DTR} = {serial_rts_n[0],serial_tx[0],serial_dtr_n[0]};
    assign ADC_BUS = 'z;
    assign {SD_SCK, SD_MOSI, SD_CS} = 'z;
    assign DDRAM_CLK = clk_sys;
    assign DDRAM_BURSTCNT = 0;
    assign DDRAM_ADDR = 0;
    assign DDRAM_RD = 0;
    assign DDRAM_DIN = 0;
    assign DDRAM_BE = 0;
    assign DDRAM_WE = 0;
    assign SDRAM_CLK = 0;
    assign SDRAM_CKE = 0;
    assign SDRAM_A = 0;
    assign SDRAM_BA = 0;
    assign SDRAM_DQ = 'z;
    assign {SDRAM_DQML, SDRAM_DQMH, SDRAM_nCS, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nWE} = '1;
endmodule
