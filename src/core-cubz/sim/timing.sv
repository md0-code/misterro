`timescale 1ns/1ps
module timing;
 reg clk=0;always #5 clk=~clk;reg reset=1;
 reg wr=0,ack=0,reti=0;reg [1:0] channel=0;reg [7:0] din=0;wire [7:0] dout,vector;wire irq,busy;wire [3:0] zero;
 cubz_ctc ctc(clk,reset,1'b1,wr,channel,din,dout,ack,reti,1'b1,irq,vector,zero,busy);
 wire [13:0] address;wire pixel,hs,vs,hb,vb;wire [9:0] x;wire [8:0] y;
 cubz_video video(clk,reset,1'b1,1'b1,8'd7,8'ha5,address,pixel,hs,vs,hb,vb,x,y);
 task out(input [1:0] ch,input [7:0] d);begin @(negedge clk);channel=ch;din=d;wr=1;@(negedge clk);wr=0;end endtask
 task acknowledge;begin @(negedge clk);ack=1;@(negedge clk);ack=0;end endtask
 integer n,visible=0,hs_count=0,vs_count=0;reg [7:0] line_addr;
 initial begin
  repeat(10)@(negedge clk);reset=0;
  out(0,8'hd0);out(3,8'h85);out(3,2);repeat(40)@(negedge clk);
  if(!irq)$fatal(1,"CTC timer IRQ");acknowledge();if(vector!=8'hd6 || irq)$fatal(1,"CTC vector/service");
  repeat(80)@(negedge clk);if(irq)$fatal(1,"CTC lower priority service block");
  out(0,8'h85);out(0,1);repeat(20)@(negedge clk);if(!irq)$fatal(1,"CTC nested priority");
  acknowledge();if(vector!=8'hd0)$fatal(1,"CTC channel priority vector");
  out(0,3);if(irq)$fatal(1,"CTC reset priority");
  @(negedge clk);reti=1;@(negedge clk);reti=0;#1;if(!irq)$fatal(1,"CTC RETI pending release");
  reset=1;repeat(2)@(negedge clk);reset=0;
  for(n=0;n<640*313;n=n+1)begin
   line_addr=y[7:0]+8'd7;
   if(address!={x[8:3],line_addr})$fatal(1,"Column-major VRAM scroll");
   if(!hb && !vb)begin visible=visible+1;if(pixel!=((8'ha5>>(7-x[2:0]))&1))$fatal(1,"Bitmap pixel ordering");end
   if(!hs)hs_count=hs_count+1;if(!vs)vs_count=vs_count+1;
   @(negedge clk);
  end
  if(visible!=512*256 || hs_count!=48*313 || vs_count!=5*640 || x!=0 || y!=0)$fatal(1,"Raster totals");
  $display("PASS: CTC timer, IM2 vectors, priority, RETI and full 640x313 raster/scroll");$finish;
 end
endmodule
