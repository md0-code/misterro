`timescale 1ns/1ps
module video_tb;
 reg clk=0;always #5 clk=~clk;reg reset=1,wide=0,hires=0,inhibit=0;reg [2:0] page=0;reg [7:0] scroll=0;wire [15:0] address;reg [7:0] data=8'hff;wire [2:0] rgb;wire bright,hs,vs,hb,vb;wire [9:0] x;wire [8:0] y;
 rp_tims_video v(.clk(clk),.reset(reset),.ce(1'b1),.wide(wide),.hires(hires),.inhibit_attributes(inhibit),.border(3'd2),.display_page(page),.scroll(scroll),.flash(1'b0),.address(address),.data(data),.rgb(rgb),.bright(bright),.hs(hs),.vs(vs),.hblank(hb),.vblank(vb),.x(x),.y(y));
 task tick(input integer n);repeat(n)begin @(posedge clk);#1;end endtask
 task start;begin reset=1;tick(2);reset=0;tick(1);end endtask
 initial begin
 start;tick(16);if(x!=16||y!=0)$fatal(1,"TIMS raster origin");page=5;#1;if(address[15:13]!=5)$fatal(1,"TIMS display pages");
 page=0;hires=1;start;if(address[13]!==1)$fatal(1,"TIMS hires interleaved 8K pages");tick(8);if(address[13]!==0)$fatal(1,"TIMS hires page alternation");
 hires=0;wide=1;start;tick(512);if(address[12:11]!==3)$fatal(1,"TIMS 40-column extension address");
 wide=0;start;tick(600);if(rgb!=2)$fatal(1,"TIMS narrow border");wide=1;#1;if(rgb==2)$fatal(1,"TIMS wide active display");
 scroll=191;start;tick(896);if(address[10:8]!=0)$fatal(1,"TIMS scroll wrap");
 tick(896*311);if(y!=0)$fatal(1,"TIMS 312 line frame");$display("PASS TIMS 256/320/512/640 display geometry, page interleave and scroll");$finish;
 end
 initial begin #4000000;$fatal(1,"video timeout");end
endmodule
