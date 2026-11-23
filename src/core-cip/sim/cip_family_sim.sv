// SPDX-License-Identifier: GPL-3.0-or-later
module cip_family_sim #(parameter CLOCK_STEP=16) (
    input wire clk, reset, cold_reset,
    input wire monitor_rom,
    input wire [1:0] requested_model,
    input wire rom_download,rom_write,
    input wire [26:0] rom_address,
    input wire [7:0] rom_byte,
    input wire [10:0] ps2_key,
    input wire tape_download, tape_wr,
    input wire [26:0] tape_addr,
    input wire [7:0] tape_data,
    input wire [1:0] tape_mode,
    output wire [3:0] rgb,
    output wire ce_pixel, hs, vs, hblank, vblank, beeper, mic,
    output wire [8:0] video_x, video_y,
    output wire [15:0] debug_pc, debug_addr,
    output wire [7:0] debug_data,
    output wire debug_mem_wr, debug_io_wr, debug_cpu_p, debug_stall,
    output wire tape_active, tape_overflow, boot_rom
);
    wire [39:0] keys_n;
    wire pause_key, prev_key, next_key, reset_key, ce_tape, ear;
    cip01_keyboard keyboard (.clk(clk), .reset(reset), .ps2_key(ps2_key),
        .joy0(32'd0), .joy1(32'd0), .keys_n(keys_n),
        .tape_pause(pause_key), .tape_prev(prev_key), .tape_next(next_key), .warm_reset(reset_key));
    wire family_hold,bank_wr,plus_wr,selected_copier;
    wire [14:0] bank_addr;wire [15:0] plus_addr;wire[1:0] active_model;
    cip_family_host host(.clk(clk),.reset(reset),.requested_model(requested_model),.requested_copier(monitor_rom),
      .download(rom_download),.wr(rom_write),.address(rom_address),.model(active_model),.copier(selected_copier),
      .hold_reset(family_hold),.native_wr(bank_wr),.plus3_wr(plus_wr),.native_address(bank_addr),.plus3_address(plus_addr),.loaded(),.overflow());
    cip01_core #(.CLOCK_STEP(CLOCK_STEP),.CLOCK_MULT(2),.RESIDENT_ROM(1)) machine (
        .clk(clk), .reset(reset || reset_key || family_hold || active_model==3), .cold_reset(cold_reset || reset_key || family_hold || active_model==3), .video_reset(cold_reset), .keys_n(keys_n), .ear(ear),
        .monitor_rom(selected_copier), .rom_wr(bank_wr), .rom_addr(bank_addr), .rom_data(rom_byte), .ce_pixel(ce_pixel), .ce_tape(ce_tape),
        .rgb(rgb), .hs(hs), .vs(vs), .hblank(hblank), .vblank(vblank), .beeper(beeper), .mic(mic),
        .video_x(video_x), .video_y(video_y), .debug_pc(debug_pc), .debug_addr(debug_addr),
        .debug_data(debug_data), .debug_mem_wr(debug_mem_wr), .debug_io_wr(debug_io_wr),
        .debug_cpu_p(debug_cpu_p), .debug_stall(debug_stall), .boot_rom(boot_rom));
    reg player_clk=0;
    always @(posedge clk)player_clk<=~player_clk;
    cip_family_tape #(.PLAYER_DIVIDER(16/CLOCK_STEP)) cassette (.clk(clk), .player_clk(player_clk), .reset(reset || family_hold), .mode48k(1'b1),
        .download(tape_download), .wr(tape_wr), .address(tape_addr), .data(tape_data), .mode(tape_mode),
        .pause(pause_key), .prev(prev_key), .next(next_key), .audio(ear),
        .active(tape_active), .available(), .overflow(tape_overflow));
endmodule
