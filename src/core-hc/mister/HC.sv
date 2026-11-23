// SPDX-License-Identifier: GPL-3.0-or-later
module emu (
    `include "sys/emu_ports.vh"
);
    wire clk_sys, locked;
    pll pll (.refclk(CLK_50M), .rst(1'b0), .outclk_0(), .outclk_1(clk_sys), .locked(locked));
    wire [127:0] status;
    wire [10:0] ps2_key;
    wire [31:0] joy0, joy1;
    wire [1:0] buttons;
    wire forced_scandoubler;
    wire [21:0] gamma_bus;
    wire ioctl_download, ioctl_wr;
    wire [26:0] ioctl_addr;
    wire [15:0] ioctl_index;
    wire [7:0] ioctl_dout;
 localparam CONF_STR={
  "HC;;",
  "S0,DSK,Floppy A:;",
  "S1,DSK,Floppy B:;",
  "F2,TAPCSWTZXPZX,Load tape;",
  "T[3],Tape play/pause;",
  "T[4],Previous tape block;",
  "T[5],Next tape block;",
  "-;",
  "P1,System;",
  "P1O[8:6],Model,HC-85,HC-90,HC-91,HC-88,HC-91 Plus (HC-128),HC-2000;",
  "P1O[11],Startup,BASIC,CP/M;",
  "P1F0,ROM,Load firmware;",
  "P2,Ports & Controllers;",
  "P2O[9],Interface 1,Off,On;",
  "P2O[12],AY sound board,Off,On;",
  "P3,Audio & Video;",
  "P3O[10],HC-128 AY sound,On,Off;",
  "P3O[2],Tape sound,On,Off;",
  "P3O[61:60],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
  "P3O[58:57],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
  "-;",
  "R[0],Reset;",
  "J,Fire;",
  "V,v0.2"};
    wire [1:0] mounted,sd_read,sd_write,ack;
    wire [31:0] image_size,lba;wire image_wp;
    wire [13:0] buffer_address;wire [7:0] buffer_out,buffer_in;wire buffer_write;
    wire serial_tx,serial_cts,network_tx;wire [9:0] psg_audio;
    hps_io #(.CONF_STR(CONF_STR),.VDNUM(2)) hps_io (
        .clk_sys(clk_sys), .HPS_BUS(HPS_BUS), .status(status),
        .buttons(buttons), .forced_scandoubler(forced_scandoubler),
        .ps2_key(ps2_key), .joystick_0(joy0), .joystick_1(joy1),
        .gamma_bus(gamma_bus), .ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr),
        .ioctl_addr(ioctl_addr), .ioctl_index(ioctl_index), .ioctl_dout(ioctl_dout), .ioctl_wait(1'b0),
        .img_mounted(mounted),.img_size(image_size),.img_readonly(image_wp),
        .sd_lba('{lba,lba}),.sd_blk_cnt('{6'd0,6'd0}),.sd_rd(sd_read),.sd_wr(sd_write),.sd_ack(ack),
        .sd_buff_addr(buffer_address),.sd_buff_dout(buffer_out),.sd_buff_din('{buffer_in,buffer_in}),.sd_buff_wr(buffer_write)
    );
    wire rom_download = ioctl_download && ioctl_index[5:0] == 0;
    wire tape_download = ioctl_download && ioctl_index[5:0] == 2;
    wire rom_loaded, rom_overflow, rom_write, family_reset;
    wire [15:0] rom_address;
    wire [2:0] model;
    hc_family_host family_host(.clk(clk_sys),.reset(RESET),.requested_model(status[8:6]),
      .download(rom_download),.wr(ioctl_wr),.address(ioctl_addr),.model(model),
      .hold_reset(family_reset),.rom_wr(rom_write),.rom_address(rom_address),
      .loaded(rom_loaded),.overflow(rom_overflow));
    wire [39:0] keys_n;
    wire key_pause, key_prev, key_next, key_reset;
    hc85_keyboard keyboard (.clk(clk_sys), .reset(RESET), .ps2_key(ps2_key),
        .joy0(joy0), .joy1(joy1), .keys_n(keys_n), .tape_pause(key_pause),
        .tape_prev(key_prev), .tape_next(key_next), .warm_reset(key_reset));
    wire reset = family_reset || !locked || status[0] || buttons[1] || key_reset;
    wire [2:0] rgb;
    wire bright;
    wire [7:0] level = model == 0 || bright ? 8'hff : 8'hc0;
    wire pixel, hs, vs, hb, vb, beeper, mic, ce_tape;
    wire tape_audio, tape_active, tape_available, tape_overflow;
    reg [1:0] serial_rx_sync=2'b11,serial_ready_sync=2'b11,network_sync=0;
    always @(posedge clk_sys)begin
        serial_rx_sync<={serial_rx_sync[0],UART_RXD};
        serial_ready_sync<={serial_ready_sync[0],UART_DSR};
        network_sync<={network_sync[0],!USER_IN[0]};
    end
    wire tape_48k;
    hc_family_core machine (
        .tape_48k(tape_48k),.clk(clk_sys), .reset(reset), .video_reset(RESET || !locked), .model_select(model), .keys_n(keys_n), .ear(tape_audio),.interface_enable(status[9]),.ay_enable((model == 3'd4) ? !status[10] : status[12]),.boot_cpm(status[11]),.joystick({joy0[4],joy0[2],joy0[3],joy0[1],joy0[0]}),.network_rx(network_sync[1]),.network_tx(network_tx),.psg_audio(psg_audio),
        .rom_wr(rom_write),
        .rom_addr(rom_address), .rom_data(ioctl_dout),
        .ce_pixel(pixel), .ce_tape(ce_tape), .rgb(rgb), .bright(bright), .hs(hs), .vs(vs),
        .hblank(hb), .vblank(vb), .beeper(beeper), .mic(mic),
        .video_x(), .video_y(), .debug_pc(), .debug_addr(), .debug_data(),
        .debug_mem_wr(), .debug_io_wr(), .debug_cpu_p(), .debug_stall(),.img_mounted(mounted),.img_wp(image_wp),.img_size(image_size),
        .sd_lba(lba),.sd_rd(sd_read),.sd_wr(sd_write),.sd_ack(|ack),
        .sd_buff_addr(buffer_address[8:0]),.sd_buff_dout(buffer_out),.sd_buff_din(buffer_in),.sd_buff_wr(buffer_write),
        .serial_rx(serial_rx_sync[1]),.serial_ready(serial_ready_sync[1]),.serial_tx(serial_tx),.serial_cts(serial_cts),
        .debug_in(),.debug_char(),.debug_fetch(),.debug_command(),.peek_address(16'd0),.peek_ram(),.peek_vram());
    hc85_tape cassette (.mode48k(tape_48k),.clk(clk_sys), .reset(RESET || family_reset), .ce(ce_tape),
        .download(tape_download), .wr(ioctl_wr), .address(ioctl_addr), .data(ioctl_dout),
        .mode(ioctl_index[7:6]), .pause(key_pause || status[3]),
        .prev(key_prev || status[4]), .next(key_next || status[5]),
        .audio(tape_audio), .active(tape_active), .available(tape_available), .overflow(tape_overflow));
    assign CLK_VIDEO = clk_sys;
 wire [1:0] aspect=status[61:60];wire [1:0] video_fx=status[58:57];wire [1:0] video_sl=video_fx?video_fx-1'd1:2'd0;
    video_mixer #(.LINE_LENGTH(704), .GAMMA(1)) mixer (
        .CLK_VIDEO(clk_sys), .CE_PIXEL(CE_PIXEL), .ce_pix(pixel),
        .scandoubler(video_fx!=0 || forced_scandoubler),.hq2x(video_fx==1), .gamma_bus(gamma_bus),
        .R(rgb[1] ? level : 8'd0), .G(rgb[2] ? level : 8'd0), .B(rgb[0] ? level : 8'd0),
        .HSync(!hs), .VSync(!vs), .HBlank(hb), .VBlank(vb),
        .HDMI_FREEZE(1'b0), .freeze_sync(),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_DE(VGA_DE));
    assign VIDEO_ARX=(!aspect)?13'd4:(aspect-1'd1);assign VIDEO_ARY=(!aspect)?13'd3:13'd0;
    // Preserve the original MIC waveform so SAVE can be recorded from audio out.
    assign AUDIO_L = {2'b00, beeper, mic, (!status[2] && tape_active && tape_audio), 11'd0} + {2'd0,psg_audio,4'd0};
    assign AUDIO_R = AUDIO_L;
    assign AUDIO_S = 0;
    assign AUDIO_MIX = 0;
    assign LED_USER = ioctl_download || tape_active;
    assign LED_POWER = tape_overflow || rom_overflow ? 2'b11 : 2'b00;
    assign LED_DISK = {1'b1,|sd_read || |sd_write};
    assign BUTTONS = 0;
    assign VGA_F1 = 0;
    assign VGA_SL=video_sl;
    assign VGA_SCALER = 0;
    assign VGA_DISABLE = 0;
    assign HDMI_FREEZE = 0;
    assign HDMI_BLACKOUT = 0;
    assign HDMI_BOB_DEINT = 0;
    assign USER_OUT = {6'b111111,!network_tx};
    assign UART_TXD=serial_tx;
    assign UART_RTS=serial_cts;
    assign UART_DTR=1'b1;
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
