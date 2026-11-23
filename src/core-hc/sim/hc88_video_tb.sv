// SPDX-License-Identifier: GPL-3.0-or-later
module hc88_video_tb #(parameter HIRES=1);
 reg clk=0,reset=1;reg[1:0]phase=0;always #5 clk=~clk;
 always @(posedge clk)phase<=phase+1'b1;
 wire[13:0]ba,aa;reg[7:0]bitmap,attribute;wire ce;wire[2:0]rgb;wire bright,hs,vs,hb,vb;wire[9:0]x;wire[8:0]y;
 reg[7:0]mem[0:16383];
 always @(posedge clk)begin bitmap<=mem[ba];attribute<=mem[aa];end
 hc88_video dut(.clk(clk),.reset(reset),.dot(phase==3),.hires(HIRES!=0),.border(3'd6),.bitmap_address(ba),.attribute_address(aa),
 .bitmap(bitmap),.attribute(attribute),.ce_pixel(ce),.rgb(rgb),.bright(bright),.hs(hs),.vs(vs),.hblank(hb),.vblank(vb),.x(x),.y(y));
 integer i,b,col,row,n,frames=0,checks=0,bytecol,bank,pattern,onpixel,ink,paper,expected;
 initial begin
 for(i=0;i<16384;i=i+1)mem[i]=i[13]?8'h5a:8'ha5;
 for(b=0;b<2;b=b+1)for(row=0;row<24;row=row+1)for(col=0;col<32;col=col+1)
 mem[b*8192+6144+row*32+col]=((col&8)?128:0)|((col&16)?64:0)|(((col+3+b)&7)<<3)|((col+b)&7);
 repeat(4)@(negedge clk);reset=0;
 for(n=0;n<896*312*18*4;n=n+1)begin
 @(negedge clk);
 if(ce)begin
 if(x==0 && y==0)frames=frames+1;
 if(frames>=2)begin
 if(x<(HIRES?512:256) && y<192)begin
 bytecol=x/8;bank=HIRES?(bytecol&1):0;col=HIRES?(bytecol/2):bytecol;pattern=bank?8'h5a:8'ha5;
 ink=(col+bank)&7;paper=(col+3+bank)&7;
 onpixel=((pattern>>(7-(x%8)))&1)^(((col&8)!=0)&&dut.flash[4]);expected=onpixel?ink:paper;
 if(rgb!==expected[2:0] || bright!==((col&16)!=0))$fatal(1,"HC88 pixel/bank/attribute mismatch hires=%d x=%d y=%d actual=%h expected=%h",HIRES,x,y,rgb,expected);
 checks=checks+1;
 end else if(bright || (!hb && !vb && rgb!=6))$fatal(1,"HC88 border or blanking mismatch");
 end
 end
 end
 if(checks<700000 || dut.flash!=18)$fatal(1,"HC88 raster/FLASH cadence failed");
 $display("PASS: HC88 %d-pixel bank interleave, independent attributes, BRIGHT, FLASH and border (%d pixels)",HIRES?512:256,checks);$finish;
 end
endmodule
