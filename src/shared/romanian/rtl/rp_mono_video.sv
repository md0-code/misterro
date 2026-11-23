// SPDX-License-Identifier: GPL-3.0-or-later
// aMIC manual I 3.6: 640 dots at 10 MHz, two dots per logical pixel, 312 lines.
module rp_mono_video(input wire clk,reset,ce,invert,input wire [7:0] data,
 output wire [12:0] address,output wire [2:0] rgb,output wire hs,vs,hblank,vblank,
 output reg [9:0] x=319,output reg [8:0] y=311);
 assign address={y[7:0],x[7:3]};
 assign hblank=x>=256;assign vblank=y>=256;
 assign hs=!(x>=272 && x<304);assign vs=!(y>=288 && y<291);
 wire black=data[7-x[2:0]]^invert;
 assign rgb=(hblank||vblank)?3'd0:black?3'd0:3'd7;
 always @(posedge clk)if(reset)begin x<=319;y<=311;end
 else if(ce)begin if(x==319)begin x<=0;y<=y==311?0:y+1'b1;end else x<=x+1'b1;end
endmodule
