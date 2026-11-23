// SPDX-License-Identifier: GPL-3.0-or-later
module cip01_sim #(parameter CLOCK_STEP=8, parameter RESIDENT_ROM=0) (
    input wire clk, reset, cold_reset,
    input wire monitor_rom,
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
    cip01_core #(.ROM_FILE(RESIDENT_ROM ? "assets/roms/resident.hex" : "assets/roms/cip01.hex"),
                 .CLOCK_STEP(CLOCK_STEP), .RESIDENT_ROM(RESIDENT_ROM)) machine (
        .clk(clk), .reset(reset || reset_key), .cold_reset(cold_reset || reset_key), .video_reset(cold_reset), .keys_n(keys_n), .ear(ear),
        .monitor_rom(monitor_rom), .rom_wr(1'b0), .rom_addr('0), .rom_data(8'd0), .ce_pixel(ce_pixel), .ce_tape(ce_tape),
        .rgb(rgb), .hs(hs), .vs(vs), .hblank(hblank), .vblank(vblank), .beeper(beeper), .mic(mic),
        .video_x(video_x), .video_y(video_y), .debug_pc(debug_pc), .debug_addr(debug_addr),
        .debug_data(debug_data), .debug_mem_wr(debug_mem_wr), .debug_io_wr(debug_io_wr),
        .debug_cpu_p(debug_cpu_p), .debug_stall(debug_stall), .boot_rom(boot_rom));
    cip01_tape cassette (.clk(clk), .reset(reset), .ce(ce_tape),
        .download(tape_download), .wr(tape_wr), .address(tape_addr), .data(tape_data), .mode(tape_mode),
        .pause(pause_key), .prev(prev_key), .next(next_key), .audio(ear),
        .active(tape_active), .available(), .overflow(tape_overflow));
endmodule
