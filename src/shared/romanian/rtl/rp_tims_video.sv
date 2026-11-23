// SPDX-License-Identifier: GPL-3.0-or-later
// TIM-S Plus manual III 8.1/10.5: 256/320/512/640 pixels, interleaved 8K pages and hardware scroll.
module rp_tims_video(input wire clk,reset,ce,wide,hires,inhibit_attributes,input wire [2:0] border,
 input wire [2:0] display_page,input wire [7:0] scroll,input wire flash,
 output wire [15:0] address,input wire [7:0] data,output wire [2:0] rgb,output wire bright,hs,vs,hblank,vblank,
 output reg [9:0] x=895,output reg [8:0] y=311);
 reg [7:0] bitmap=0,shift=0,attribute=7;
 wire [9:0] step=hires?10'd8:10'd16;
 wire [9:0] nx=x>=896-step?10'd0:((x+step)&(hires?10'h3f8:10'h3f0));
 wire [8:0] ny=x>=896-step?(y==311?9'd0:y+1'b1):y;
 wire [8:0] sy=ny+scroll;wire [7:0] line=sy>=192?sy-192:sy;
 wire [9:0] lx=hires?nx:(nx>>1);wire [5:0] column=hires?lx[9:4]:lx[8:3];
 wire [12:0] pixel_address=column[5]?{2'b11,line[2:0],line[5:3],line[7:6],column[2:0]}:{2'b00,line[7:6],line[2:0],line[5:3],column[4:0]};
 wire [12:0] attribute_address={3'b110,line[7:3],column[4:0]};
 wire attribute_phase=hires?x[2]:x[3];
 wire page_bit=display_page[0]^(hires&&lx[3]);
 assign address={display_page[2:1],page_bit,attribute_phase?attribute_address:pixel_address};
 wire active=x<(wide?640:512)&&y<192;
 wire pixel_on=shift[7]^(attribute[7]&&flash);
 assign rgb=hblank||vblank?3'd0:active?(pixel_on?attribute[2:0]:attribute[5:3]):border;
 assign bright=active&&attribute[6];
 assign hs=!(x>=704&&x<768);assign vs=!(y>=248&&y<252);
 assign hblank=x>=672&&x<864;assign vblank=y>=240&&y<264;
 always @(posedge clk)begin
  if(reset)begin x<=895;y<=311;bitmap<=0;shift<=0;attribute<=7;end
  else if(ce)begin
   if(hires?x[2:0]==3:x[3:0]==7)bitmap<=data;
   if(hires?x[2:0]==7:x[3:0]==15)begin shift<=bitmap;if(!inhibit_attributes)attribute<=data;end
   else if(hires||x[0])shift<={shift[6:0],1'b0};
   if(x==895)begin x<=0;y<=y==311?0:y+1'b1;end else x<=x+1'b1;
  end
 end
endmodule
