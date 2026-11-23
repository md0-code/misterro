// SPDX-License-Identifier: GPL-3.0-or-later
// The user's Z80 PIO on the GPZ board (ports A0-A3: A data, A control, B data, B control).
// Modes 0 (output), 1 and 2 (input here: no handshake lines are wired) and 3 (bit control
// with a direction mask). Interrupt words are accepted; the board's interrupt is not connected.
module cubz_pio(input wire clk,reset,wr,input wire [1:0] address,input wire [7:0] din,output wire [7:0] dout,
 input wire [7:0] a_in,b_in,output wire [7:0] a_out,a_drive,b_out,b_drive);
 reg [7:0] data[0:1],mask[0:1];reg [1:0] mode[0:1];reg [1:0] mask_next,skip_next;
 wire p=address[1];
 always @(posedge clk)begin
  if(reset)begin
   data[0]<=8'hff;data[1]<=8'hff;mask[0]<=8'hff;mask[1]<=8'hff;mode[0]<=1;mode[1]<=1;mask_next<=0;skip_next<=0;
  end else if(wr)begin
   if(!address[0])data[p]<=din;
   else if(mask_next[p])begin mask[p]<=din;mask_next[p]<=0;end
   else if(skip_next[p])skip_next[p]<=0;
   else if(din[3:0]==4'hf)begin mode[p]<=din[7:6];mask_next[p]<=din[7:6]==3;end
   else if(din[3:0]==4'h7)skip_next[p]<=din[4];
  end
 end
 wire [7:0] dir_a=mode[0]==0?8'h00:mode[0]==3?mask[0]:8'hff;
 wire [7:0] dir_b=mode[1]==0?8'h00:mode[1]==3?mask[1]:8'hff;
 assign a_out=data[0];assign a_drive=~dir_a;assign b_out=data[1];assign b_drive=~dir_b;
 wire [7:0] read_a=(data[0] & ~dir_a)|(a_in & dir_a),read_b=(data[1] & ~dir_b)|(b_in & dir_b);
 assign dout=address[0]?8'hff:p?read_b:read_a;
endmodule
