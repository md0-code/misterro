// SPDX-License-Identifier: GPL-3.0-or-later
module cip_family_host (
 input wire clk,reset,
 input wire [1:0] requested_model,
 input wire requested_copier,
 input wire download,wr,
 input wire [26:0] address,
 output reg [1:0] model=0,
 output reg copier=0,
 output wire hold_reset,native_wr,plus3_wr,
 output wire [14:0] native_address,
 output wire [15:0] plus3_address,
 output reg loaded=0,
 output reg overflow=0
);
 reg previous_download=0;
 reg [16:0] length=0;
 reg [7:0] restart=0;
 wire select_copier = requested_model==0 || (requested_model==1 && requested_copier);
 assign hold_reset=reset || !loaded || download || restart!=0 || model!=requested_model || copier!=select_copier;
 assign native_wr=download && wr && address<18432;
 assign plus3_wr=download && wr && address>=18432 && address<83968;
 assign native_address=address[14:0];
 assign plus3_address=address-27'd18432;
 always @(posedge clk) begin
  previous_download<=download;
  if(reset) begin loaded<=0;overflow<=0;length<=0;restart<=0;model<=requested_model;copier<=select_copier;end
  else begin
   model<=requested_model;copier<=select_copier;
   if(model!=requested_model || copier!=select_copier) restart<=8'hff;
   else if(restart!=0)restart<=restart-1'b1;
   if(download && !previous_download)begin loaded<=0;overflow<=0;length<=0;end
   if(download && wr)begin
    if(address<83968)length<=address[16:0]+1'b1;else overflow<=1;
   end
   if(!download && previous_download)loaded<=length==83968 && !overflow;
  end
 end
endmodule
