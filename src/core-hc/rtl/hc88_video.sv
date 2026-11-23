// SPDX-License-Identifier: GPL-3.0-or-later
// HC-88: the 14 MHz serializer interleaves the two Spectrum-format screens.
module hc88_video(
 input wire clk,reset,dot,hires,input wire [2:0] border,
 output wire [13:0] bitmap_address,attribute_address,
 input wire [7:0] bitmap,attribute,
 output reg ce_pixel,output reg [2:0] rgb,output reg bright,
 output reg hs,vs,hblank,vblank,output reg [9:0] x,output reg [8:0] y
);
 reg [9:0] scan_x=895;reg [8:0] scan_y=311;reg [4:0] flash=0;
 wire bank=hires && scan_x[3];
 assign bitmap_address={bank,scan_y[7:6],scan_y[2:0],scan_y[5:3],scan_x[8:4]};
 assign attribute_address={bank,3'b110,scan_y[7:3],scan_x[8:4]};
 wire ink=bitmap[7-(hires?scan_x[2:0]:scan_x[3:1])] ^ (attribute[7] && flash[4]);
 always @(posedge clk)begin
  ce_pixel<=0;
  if(reset)begin scan_x<=895;scan_y<=311;flash<=0;rgb<=0;bright<=0;hs<=1;vs<=1;hblank<=1;vblank<=1;x<=0;y<=0;end
  else if(dot)begin
   ce_pixel<=hires || !scan_x[0];x<=hires?scan_x:{1'b0,scan_x[9:1]};y<=scan_y;
   hs<=!(scan_x>=640 && scan_x<704);vs<=!(scan_y>=248 && scan_y<252);
   hblank<=scan_x>=608 && scan_x<800;vblank<=scan_y>=240 && scan_y<264;
   rgb<=((scan_x>=608 && scan_x<800)||(scan_y>=240 && scan_y<264))?3'b000:
       (scan_x<512 && scan_y<192)?(ink?attribute[2:0]:attribute[5:3]):border;
   bright<=scan_x<512 && scan_y<192 && attribute[6];
   if(scan_x==895)begin scan_x<=0;if(scan_y==311)begin scan_y<=0;flash<=flash+1'b1;end else scan_y<=scan_y+1'b1;end
   else scan_x<=scan_x+1'b1;
  end
 end
endmodule
