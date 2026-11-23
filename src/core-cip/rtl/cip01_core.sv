// SPDX-License-Identifier: GPL-3.0-or-later
// CIP-01: 2 KiB mirrored bootstrap, 64 KiB RAM, IC37A cassette-ROM latch.
module cip01_core #(parameter ROM_FILE = "", parameter CLOCK_STEP = 1,
                   parameter CLOCK_MULT = 1, parameter RESIDENT_ROM = 0, parameter ROM_BYTES = RESIDENT_ROM ? 18432 : 2048) (
    input wire clk, reset, cold_reset, video_reset,
    input wire monitor_rom,
    input wire [39:0] keys_n,
    input wire ear,
    input wire rom_wr,
    input wire [$clog2(ROM_BYTES)-1:0] rom_addr,
    input wire [7:0] rom_data,
    output wire ce_pixel, ce_tape,
    output wire [3:0] rgb,
    output wire hs, vs, hblank, vblank,
    output reg beeper, mic,
    output wire [8:0] video_x, video_y,
    output wire [15:0] debug_pc, debug_addr,
    output wire [7:0] debug_data,
    output wire debug_mem_wr, debug_io_wr, debug_cpu_p, debug_stall,
    output reg boot_rom = 1
);
    reg [$clog2(64*CLOCK_MULT)-1:0] phase = 0;
    always @(posedge clk) if (video_reset) phase <= 0; else phase <= phase + CLOCK_STEP;
    assign ce_pixel = (phase % (8*CLOCK_MULT)) == 8*CLOCK_MULT-CLOCK_STEP;
    // Cassette timing follows real time, independent of the stopped CPU clock.
    assign ce_tape = (phase % (16*CLOCK_MULT)) == 16*CLOCK_MULT-CLOCK_STEP;
    wire [15:0] addr;
    wire [7:0] cpu_out;
    wire mreq_n, iorq_n, rd_n, wr_n, m1_n, rfsh_n;
    wire [211:0] registers;
    wire video_access = !mreq_n && addr[15:14] == 2'b01;
    // Sheet 2 IC20 Q1 divides the 14 MHz oscillator by four without clock gating.
    // RAM/display accesses interleave; they do not stop the CPU as on HC-85.
    wire clock_allowed = 1'b1;
    wire cpu_p = (phase % (16*CLOCK_MULT)) == 16*CLOCK_MULT-CLOCK_STEP && clock_allowed;
    wire cpu_n = (phase % (16*CLOCK_MULT)) == 8*CLOCK_MULT-CLOCK_STEP && clock_allowed;
    reg [7:0] rom[0:ROM_BYTES-1];
    reg [7:0] lowram[0:16383];
    reg [7:0] vram[0:16383];
    reg [7:0] ram[0:32767];
    reg [7:0] rom_q, low_q, vram_q, ram_q, video_q;
    wire [13:0] video_addr;
    initial begin
        beeper = 0; mic = 0;
        if (ROM_FILE != "") $readmemh(ROM_FILE, rom);
    end
    always @(posedge clk) begin
        if (rom_wr) rom[rom_addr] <= rom_data;
        // Resident bundle: original 2K copier followed by the original 16K BASIC.
        // CIP-01 keeps its original 2K mirroring, including when this input is unused.
        rom_q <= rom[(RESIDENT_ROM && !monitor_rom) ? 15'd2048+{1'b0,addr[13:0]} : {4'd0,addr[10:0]}];
        low_q <= lowram[addr[13:0]];
        vram_q <= vram[addr[13:0]];
        ram_q <= ram[addr[14:0]];
        video_q <= vram[video_addr];
        if (!reset && !mreq_n && !wr_n) begin
            if (addr[15:14] == 2'b00) lowram[addr[13:0]] <= cpu_out;
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
    // Sheet 1 IC35: A0=0, A6=1; A4 selects FE peripherals or EE boot latch.
    wire port_fe = !iorq_n && m1_n && !addr[0] && addr[6] && addr[4];
    wire port_ee = !iorq_n && m1_n && !addr[0] && addr[6] && !addr[4];
    always @(posedge clk) begin
        if (cold_reset) boot_rom <= 1;
        else if (port_ee && !wr_n) boot_rom <= !cpu_out[0];
    end
    wire [7:0] cpu_in = !mreq_n ? (addr[15] ? ram_q : addr[14] ? vram_q : boot_rom ? rom_q : low_q)
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
    cip01_video video (
        .clk(clk), .reset(video_reset), .ce_pixel(ce_pixel), .border(border),
        .ram_addr(video_addr), .ram_data(video_q), .rgb(rgb),
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
