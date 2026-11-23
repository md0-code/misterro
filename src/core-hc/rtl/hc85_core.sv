// SPDX-License-Identifier: GPL-3.0-or-later
// 1987 HC-85: 16 KiB ROM, 16 KiB shared video/program RAM, 32 KiB additional RAM.
module hc85_core #(parameter ROM_FILE = "", parameter MODEL = 85, parameter DYNAMIC_MODEL = 0, parameter ROM_BYTES = DYNAMIC_MODEL ? 49152 : 16384) (
    input wire clk, reset, video_reset,
    input wire [1:0] model_select,
    input wire [39:0] keys_n,
    input wire ear,
    input wire rom_wr,
    input wire [$clog2(ROM_BYTES)-1:0] rom_addr,
    input wire [7:0] rom_data,
    output wire ce_pixel, ce_tape,
    output wire [2:0] rgb,
    output wire bright,
    output wire hs, vs, hblank, vblank,
    output reg beeper, mic,
    output wire [8:0] video_x, video_y,
    output wire [15:0] debug_pc, debug_addr,
    output wire [7:0] debug_data,
    output wire debug_mem_wr, debug_io_wr, debug_cpu_p, debug_stall
);
    wire is_hc85 = DYNAMIC_MODEL ? model_select == 0 : MODEL == 85;
    wire [15:0] rom_bank = DYNAMIC_MODEL ? (model_select == 1 ? 16'd16384 : model_select == 2 ? 16'd32768 : 16'd0) : 16'd0;
    reg [5:0] phase = 0;
    always @(posedge clk) if (video_reset) phase <= 0; else phase <= phase + 1'b1;
    assign ce_pixel = phase[2:0] == 7;
    // Cassette timing follows real time, independent of the stopped CPU clock.
    assign ce_tape = phase[3:0] == 15;
    wire [15:0] addr;
    wire [7:0] cpu_out;
    wire mreq_n, iorq_n, rd_n, wr_n, m1_n, rfsh_n;
    wire [211:0] registers;
    wire video_access = !mreq_n && addr[15:14] == 2'b01;
    // Sheet 6: display and CPU share the lower bank; stop the CPU clock, not WAIT.
    // This initial phase schedule must be compared with B4/A3 gate-level traces.
    // HC90 CPU-ROM sheet 1 and HC91 CPU sheet 1 wire CLK directly to X2L.
    wire clock_allowed = !is_hc85 || !video_access || !phase[5];
    wire cpu_p = phase[3:0] == 15 && clock_allowed;
    wire cpu_n = phase[3:0] == 7 && clock_allowed;
    reg [7:0] rom[0:ROM_BYTES-1];
    reg [7:0] vram[0:16383];
    reg [7:0] ram[0:32767];
    reg [7:0] rom_q, vram_q, ram_q, video_q;
    wire [13:0] video_addr;
    initial begin
        beeper = 0; mic = 0;
        if (ROM_FILE != "") $readmemh(ROM_FILE, rom);
    end
    always @(posedge clk) begin
        if (rom_wr) rom[rom_addr] <= rom_data;
        rom_q <= rom[rom_bank+{2'd0,addr[13:0]}];
        vram_q <= vram[addr[13:0]];
        ram_q <= ram[addr[14:0]];
        video_q <= vram[video_addr];
        if (!reset && !mreq_n && !wr_n) begin
            if (addr[15:14] == 2'b01) vram[addr[13:0]] <= cpu_out;
            if (addr[15]) ram[addr[14:0]] <= cpu_out;
        end
    end
    reg [4:0] key_data;
    integer row;
    always @* begin
        key_data = 5'b11111;
        for (row=0; row<8; row=row+1)
            if (!addr[8+row]) key_data = key_data & keys_n[row*5 +: 5];
    end
    // Sheet 8 decodes A0 low AND A6 high. Interrupt acknowledge is excluded by M1.
    // HC90 F7 / HC91 F4: LS138 enables A0, IORQ, M1; selects WR, A7, RD.
    // INFEL is Y3, OUTFEL is Y6. A6 is unconnected on these models.
    wire port_fe = !iorq_n && m1_n && !addr[0] && (is_hc85 ? addr[6] : addr[7]);
    wire [7:0] cpu_in = !mreq_n ? (addr[15] ? ram_q : addr[14] ? vram_q : rom_q)
                          : port_fe && !rd_n ? {1'b1, ear, 1'b1, key_data} : 8'hff;
    reg [2:0] border = 0;
    always @(posedge clk) begin
        if (reset) begin border <= 0; beeper <= 0; mic <= 0; end
        else if (port_fe && !wr_n) begin
            border <= cpu_out[2:0]; mic <= cpu_out[3]; beeper <= cpu_out[4];
        end
    end
    wire int_n = !(video_y == 248 && video_x < 64);
    T80pa cpu (
        .RESET_n(!reset), .CLK(clk), .CEN_p(cpu_p), .CEN_n(cpu_n),
        .WAIT_n(1'b1), .INT_n(int_n), .NMI_n(1'b1), .BUSRQ_n(1'b1),
        .M1_n(m1_n), .MREQ_n(mreq_n), .IORQ_n(iorq_n), .RD_n(rd_n), .WR_n(wr_n),
        .RFSH_n(rfsh_n), .HALT_n(), .BUSAK_n(), .OUT0(1'b0), .A(addr),
        .DI(cpu_in), .DO(cpu_out), .R800_mode(1'b0), .REG(registers), .DIRSet(1'b0), .DIR(212'd0)
    );
    hc85_video #(.HAS_BRIGHT(MODEL != 85),.DYNAMIC_BRIGHT(DYNAMIC_MODEL)) video (
        .clk(clk), .reset(video_reset), .ce_pixel(ce_pixel), .border(border), .bright_enable(!is_hc85),
        .ram_addr(video_addr), .ram_data(video_q), .rgb(rgb), .bright(bright),
        .hs(hs), .vs(vs), .hblank(hblank), .vblank(vblank),
        .x(video_x), .y(video_y), .flash_count()
    );
    assign debug_pc = registers[79:64];
    assign debug_addr = addr;
    assign debug_data = cpu_out;
    assign debug_mem_wr = !mreq_n && !wr_n;
    assign debug_io_wr = port_fe && !wr_n;
    assign debug_cpu_p = cpu_p;
    assign debug_stall = video_access && !clock_allowed;
endmodule
