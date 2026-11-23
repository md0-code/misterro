// SPDX-License-Identifier: GPL-3.0-or-later
// 10 MHz dot clock, 64 us lines, 313 lines/frame; 512 x 256 bitmap.
module cubz_video(input wire clk,reset,ce,input wire enable,input wire [7:0] scroll,
 input wire [7:0] data,output wire [13:0] address,
 output wire pixel,hs,vs,hblank,vblank,output reg [9:0] x,output reg [8:0] y);
 wire [7:0] line_addr=y[7:0]+scroll;
 // RAM is read continuously, three system clocks before each pixel enable.
 assign address={x[8:3],line_addr};
 assign hblank=x>=512;
 assign vblank=y>=256;
 assign pixel=enable && !hblank && !vblank && data[7-x[2:0]];
 // Original PROM produces a 15.2 us horizontal pulse; MiSTer accepts
 // the same line rate with a conventional 4.8 us sync inside blanking.
 assign hs=!(x>=544 && x<592);
 assign vs=!(y>=276 && y<281);
 always @(posedge clk)begin
  if(reset)begin x<=0;y<=0;end
  else if(ce)begin
   if(x==639)begin x<=0;y<=y==312?0:y+1'b1;end else x<=x+1'b1;
  end
 end
endmodule
