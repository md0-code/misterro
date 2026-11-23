// SPDX-License-Identifier: GPL-3.0-or-later
// CIP-01 display: schematic sheet 3, including ATTR6 BRIGHT.
// The initial raster uses the nominal 448 x 312 PAL envelope. See docs/hardware.md.
module cip01_video (
    input wire clk, reset, ce_pixel,
    input wire [2:0] border,
    output wire [13:0] ram_addr,
    input wire [7:0] ram_data,
    output wire [3:0] rgb,
    output wire hs, vs, hblank, vblank,
    output reg [8:0] x, y,
    output reg [4:0] flash_count
);
    initial begin x = 447; y = 311; flash_count = 0; end
    reg [7:0] bitmap = 0, shift = 0, attr = 0;
    wire [8:0] fetch_x = x >= 440 ? 9'd0 : {x[8:3] + 6'd1, 3'b000};
    wire [8:0] fetch_y = x >= 440 ? (y == 311 ? 9'd0 : y + 9'd1) : y;
    // DRAM row/column multiplexing reduces to the Spectrum-compatible address order.
    wire [13:0] bitmap_addr = {1'b0, fetch_y[7:6], fetch_y[2:0], fetch_y[5:3], fetch_x[7:3]};
    wire [13:0] attr_addr = {4'b0110, fetch_y[7:3], fetch_x[7:3]};
    assign ram_addr = x[2] ? attr_addr : bitmap_addr;
    wire pixel_on = shift[7] ^ (attr[7] & flash_count[4]);
    wire [2:0] colour = pixel_on ? attr[2:0] : attr[5:3];
    assign rgb = (hblank || vblank) ? 4'b0000 : (x < 256 && y < 192) ? {attr[6],colour} : {1'b0,border};
    assign hs = !(x >= 320 && x < 352);
    assign vs = !(y >= 248 && y < 252);
    assign hblank = x >= 304 && x < 400;
    assign vblank = y >= 240 && y < 264;
    always @(posedge clk) begin
        if (reset) begin
            x <= 447; y <= 311; flash_count <= 0;
            bitmap <= 0; shift <= 0; attr <= 0;
        end else if (ce_pixel) begin
            if (x[2:0] == 3) bitmap <= ram_data;
            if (x[2:0] == 7) begin
                shift <= bitmap;
                attr <= ram_data;
            end else shift <= {shift[6:0], 1'b0};
            if (x == 447) begin
                x <= 0;
                if (y == 311) begin y <= 0; flash_count <= flash_count + 1'b1; end
                else y <= y + 1'b1;
            end else x <= x + 1'b1;
        end
    end
endmodule
