// Runtime CIP01/02/03 path and the immutable CIP04 firmware banks.
wire [1:0] family_model;
wire family_copier,family_hold,family_loaded,family_overflow;
wire family_native_wr,family_plus3_wr;
wire [14:0] family_native_address;
wire [15:0] family_plus3_address;
wire family_rom_download=ioctl_download && ioctl_index[4:0]==0;
cip_family_host family_host(.clk(clk_sys),.reset(RESET),.requested_model(status_hps[16:15]),
 .requested_copier(status_hps[7]),.download(family_rom_download),.wr(ioctl_wr),
 .address({2'd0,ioctl_addr}),.model(family_model),.copier(family_copier),
 .hold_reset(family_hold),.native_wr(family_native_wr),.plus3_wr(family_plus3_wr),
 .native_address(family_native_address),.plus3_address(family_plus3_address),
 .loaded(family_loaded),.overflow(family_overflow));
wire family_plus3=family_model==3;
reg [7:0] family_rom4[0:65535];
reg [7:0] family_rom4_q;
always @(posedge clk_sys)begin
 if(family_plus3_wr)family_rom4[family_plus3_address]<=ioctl_dout;
 family_rom4_q<=family_rom4[{page_rom[1:0],addr[13:0]}];
end
wire [39:0] family_keys;
wire family_pause,family_prev,family_next,family_key_reset;
cip01_keyboard family_keyboard(.clk(clk_sys),.reset(RESET),.ps2_key(ps2_key),
 .joy0({16'd0,joy0_hps}),.joy1({16'd0,joy1_hps}),.keys_n(family_keys),
 .tape_pause(family_pause),.tape_prev(family_prev),.tape_next(family_next),.warm_reset(family_key_reset));
wire family_native_reset=family_hold || family_plus3 || !locked || status_hps[0] || buttons[1] || family_key_reset;
wire [3:0] family_rgb;
wire family_pixel,family_hs,family_vs,family_hb,family_vb,family_beeper,family_mic,family_ce_tape;
wire family_tape_audio,family_tape_active,family_tape_available,family_tape_overflow;
cip01_core #(.RESIDENT_ROM(1),.CLOCK_MULT(2)) family_machine(
 .clk(clk_sys),.reset(family_native_reset),.cold_reset(family_native_reset),.video_reset(RESET || !locked),
 .monitor_rom(family_copier),.keys_n(family_keys),.ear(family_tape_audio),
 .rom_wr(family_native_wr),.rom_addr(family_native_address),.rom_data(ioctl_dout),
 .ce_pixel(family_pixel),.ce_tape(family_ce_tape),.rgb(family_rgb),.hs(family_hs),.vs(family_vs),
 .hblank(family_hb),.vblank(family_vb),.beeper(family_beeper),.mic(family_mic),
 .video_x(),.video_y(),.debug_pc(),.debug_addr(),.debug_data(),.debug_mem_wr(),.debug_io_wr(),.debug_cpu_p(),.debug_stall(),.boot_rom());
cip_family_tape family_tape(.clk(clk_sys),.player_clk(clk_56),.reset(RESET || family_hold || !locked),
 .download(ioctl_download && ioctl_index[4:0]==2),.wr(ioctl_wr),.address({2'd0,ioctl_addr}),.data(ioctl_dout),
 .mode48k(!family_plus3 || page_disable),.mode(ioctl_index[7:6]),.pause(family_pause || status_hps[22]),.prev(family_prev || status_hps[23]),.next(family_next || status_hps[24]),
 .audio(family_tape_audio),.active(family_tape_active),.available(family_tape_available),.overflow(family_tape_overflow));
// Held pixel bus and synchronized event across the related 112/56 MHz clocks.
reg [7:0] family_video_hold=0;
reg family_pixel_toggle=0;
always @(posedge clk_sys)if(family_pixel)begin
 family_video_hold<={!family_hs,!family_vs,family_hb,family_vb,family_rgb};
 family_pixel_toggle<=~family_pixel_toggle;
end
reg [2:0] family_pixel_sync=0;
always @(posedge clk_56)family_pixel_sync<={family_pixel_sync[1:0],family_pixel_toggle};
wire family_pixel_56=family_pixel_sync[2]^family_pixel_sync[1];
wire [15:0] family_native_audio={2'b00,family_beeper,family_mic,(!status_hps[1] && family_tape_active && family_tape_audio),11'd0};
// CIP-04 printer and serial ports on MiSTer's UART pins.
wire family_printer_sel,family_printer_busy,family_ay14_sel;wire [7:0] family_ay14_in;
cip04_ports family_ports(.clk(clk_sys),.reset(reset),.enable(family_plus3),.addr(addr),.din(cpu_dout),.io_wr(io_wr),.psg_we(psg_we),
 .strobe_n(page_reg_plus3[4]),.printer_mode(status_hps[56]),.uart_rxd(UART_RXD),.uart_cts(UART_CTS),.uart_txd(UART_TXD),.uart_rts(UART_RTS),
 .printer_sel(family_printer_sel),.printer_busy(family_printer_busy),.ay14_sel(family_ay14_sel),.ay14_in(family_ay14_in));
