// SPDX-License-Identifier: GPL-3.0-or-later
// HC-85 display: manual section 4.6, schematic sheets 4-7.
// The initial raster uses the nominal 448 x 312 PAL envelope. See docs/hardware.md.
module rp_cobra_video #(parameter HAS_BRIGHT = 0, parameter DYNAMIC_BRIGHT = 0) (
    input wire clk, reset, ce_pixel, bright_enable,extended,upper_page,
    input wire [2:0] border,
    output wire [13:0] ram_addr,
    input wire [7:0] ram_data,
    output wire [2:0] rgb,
    output wire bright,
    output wire hs, vs, hblank, vblank,
    output reg [8:0] x, y,
    output reg [4:0] flash_count
);
    initial begin x = 447; y = 311; flash_count = 0; end
    reg [7:0] bitmap = 0, shift = 0, attr = 0;
    wire [8:0] fetch_x = x >= 440 ? 9'd0 : {x[8:3] + 6'd1, 3'b000};
    wire [8:0] fetch_y = x >= 440 ? (y == 311 ? 9'd0 : y + 9'd1) : y;
    // DRAM row/column multiplexing reduces to the Spectrum-compatible address order.
    wire [8:0] native_x=extended?fetch_x-9'd32:fetch_x;
    wire [13:0] bitmap_addr = {extended?native_x[8]:upper_page, fetch_y[7:6], fetch_y[2:0], fetch_y[5:3], native_x[7:3]};
    wire [13:0] attr_addr = {extended?native_x[8]:upper_page,3'b110, fetch_y[7:3], native_x[7:3]};
    assign ram_addr = x[2] ? attr_addr : bitmap_addr;
    wire pixel_on = shift[7] ^ (attr[7] & flash_count[4]);
    wire [2:0] colour = pixel_on ? attr[2:0] : attr[5:3];
    // HC85 sheet 7 leaves bit 6 unconnected; HC90 RGB sheet 6 / HC91 CLK
    // sheet 7 route it to BRIGHT. Border has no brightness attribute.
    assign bright = (DYNAMIC_BRIGHT ? bright_enable : HAS_BRIGHT) && !hblank && !vblank && x < (extended?320:256) && y < 192 && attr[6];
    assign rgb = (hblank || vblank) ? 3'b000 : (x < (extended?320:256) && y < 192) ? colour : border;
    assign hs = extended?!(x>=352&&x<384):!(x>=320&&x<352);
    assign vs = !(y >= 248 && y < 252);
    assign hblank = extended?(x>=336&&x<432):(x>=304&&x<400);
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
