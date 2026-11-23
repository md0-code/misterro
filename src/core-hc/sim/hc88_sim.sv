// SPDX-License-Identifier: GPL-3.0-or-later
module hc88_sim #(parameter FAST_DISK=1) (
    input wire clk, reset,
    input wire [2:0] requested_model,
    input wire rom_download,rom_write,
    input wire [26:0] rom_address,
    input wire [7:0] rom_byte,
    input wire [10:0] ps2_key,
    input wire tape_download, tape_wr,
    input wire [26:0] tape_addr,
    input wire [7:0] tape_data,
    input wire [1:0] tape_mode,
    output wire [2:0] rgb,
    output wire bright,
    output wire ce_pixel, hs, vs, hblank, vblank, beeper, mic,
    output wire [9:0] video_x, output wire [8:0] video_y,
    output wire [15:0] debug_pc, debug_addr,
    output wire [7:0] debug_data,
    output wire debug_mem_wr, debug_io_wr, debug_cpu_p, debug_stall,
    input wire [1:0] img_mounted,input wire img_wp,input wire [31:0] img_size,
    output wire [31:0] sd_lba,output wire [1:0] sd_rd,sd_wr,input wire sd_ack,
    input wire [8:0] sd_buff_addr,input wire [7:0] sd_buff_dout,output wire [7:0] sd_buff_din,input wire sd_buff_wr,
    output wire [7:0] debug_in,debug_char,output wire debug_fetch,output wire [5:0] debug_command,
    input wire [15:0] peek_address,output wire [7:0] peek_ram,peek_vram,
    output wire tape_active, tape_overflow
);
    wire [39:0] keys_n;
    wire pause_key, prev_key, next_key, reset_key, ce_tape, ear;
    hc85_keyboard keyboard (.clk(clk), .reset(reset), .ps2_key(ps2_key),
        .joy0(32'd0), .joy1(32'd0), .keys_n(keys_n),
        .tape_pause(pause_key), .tape_prev(prev_key), .tape_next(next_key), .warm_reset(reset_key));
    wire family_hold,bank_wr;
    wire [15:0] bank_addr;
    wire [2:0] active_model;
    hc_family_host host(.clk(clk),.reset(reset),.requested_model(requested_model),
      .download(rom_download),.wr(rom_write),.address(rom_address),.model(active_model),
      .hold_reset(family_hold),.rom_wr(bank_wr),.rom_address(bank_addr),.loaded(),.overflow());
    hc_family_core #(.FAST_DISK(FAST_DISK)) machine (
        .clk(clk), .reset(reset || reset_key || family_hold), .video_reset(reset), .model_select(active_model), .keys_n(keys_n), .ear(ear),.interface_enable(1'b0),.ay_enable(1'b1),.boot_cpm(1'b0),.joystick(5'd0),.network_rx(1'b0),.network_tx(),.psg_audio(),
        .rom_wr(bank_wr), .rom_addr(bank_addr), .rom_data(rom_byte), .ce_pixel(ce_pixel), .ce_tape(ce_tape),
        .rgb(rgb), .bright(bright), .hs(hs), .vs(vs), .hblank(hblank), .vblank(vblank), .beeper(beeper), .mic(mic),
        .video_x(video_x), .video_y(video_y), .debug_pc(debug_pc), .debug_addr(debug_addr),
        .debug_data(debug_data), .debug_mem_wr(debug_mem_wr), .debug_io_wr(debug_io_wr),
        .debug_cpu_p(debug_cpu_p), .debug_stall(debug_stall),
        .img_mounted(img_mounted),.img_wp(img_wp),.img_size(img_size),.sd_lba(sd_lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(sd_ack),
        .sd_buff_addr(sd_buff_addr),.sd_buff_dout(sd_buff_dout),.sd_buff_din(sd_buff_din),.sd_buff_wr(sd_buff_wr),
        .serial_rx(1'b1),.serial_ready(1'b1),.serial_tx(),.serial_cts(),.debug_in(debug_in),.debug_char(debug_char),.debug_fetch(debug_fetch),
        .debug_command(debug_command),.peek_address(peek_address),.peek_ram(peek_ram),.peek_vram(peek_vram));
    hc85_tape cassette (.mode48k(1'b1),.clk(clk), .reset(reset || family_hold), .ce(ce_tape),
        .download(tape_download), .wr(tape_wr), .address(tape_addr), .data(tape_data), .mode(tape_mode),
        .pause(pause_key), .prev(prev_key), .next(next_key), .audio(ear),
        .active(tape_active), .available(), .overflow(tape_overflow));
endmodule
