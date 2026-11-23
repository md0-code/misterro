// SPDX-License-Identifier: GPL-3.0-or-later
// One immutable firmware bank per model; switching never depends on a host reload.
module hc_family_host (
 input wire clk, reset,
 input wire [2:0] requested_model,
 input wire download, wr,
 input wire [26:0] address,
 output reg [2:0] model = 0,
 output wire hold_reset, rom_wr,
 output wire [15:0] rom_address,
 output reg loaded = 0,
 output reg overflow = 0
);
 reg previous_download = 0;
 reg [16:0] length = 0;
 reg [7:0] restart = 0;
 wire [2:0] selected = requested_model;
 assign hold_reset = reset || !loaded || download || restart != 0 || model != selected;
 assign rom_wr = download && wr && address < 65536;
 assign rom_address = address[15:0];
 always @(posedge clk) begin
  previous_download <= download;
  if(reset) begin loaded<=0;overflow<=0;length<=0;restart<=0;model<=selected;end
  else begin
   model<=selected;
   if(model != selected) restart<=8'hff;
   else if(restart != 0) restart<=restart-1'b1;
   if(download && !previous_download) begin loaded<=0;overflow<=0;length<=0;end
   if(download && wr) begin
    if(address<65536) length<=address[16:0]+1'b1;else overflow<=1;
   end
   if(!download && previous_download) loaded<=length==65536 && !overflow;
  end
 end
endmodule
