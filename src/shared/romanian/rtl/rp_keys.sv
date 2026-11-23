// SPDX-License-Identifier: GPL-3.0-or-later
module rp_keys(input wire clk,reset,input wire [10:0] ps2_key,output reg [511:0] pressed=0);
 reg toggle=0;
 always @(posedge clk)begin
  toggle<=ps2_key[10];
  if(reset)pressed<=0;else if(toggle!=ps2_key[10])pressed[ps2_key[8:0]]<=ps2_key[9];
 end
endmodule
