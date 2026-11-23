`timescale 1ns/1ps
module timer_tb;
 reg clk=0;always #5 clk=~clk;reg reset=1,wr=0,rd=0;reg [1:0] address=0;reg [7:0] din=0;reg [2:0] clocks=0,gates=7;wire [7:0] dout;wire [2:0] out;
 rp_i8253 p(.*);
 task tick(input integer n);repeat(n)begin @(posedge clk);#1;end endtask
 task put(input [1:0] a,input [7:0] v);begin @(negedge clk);address=a;din=v;wr=1;tick(1);@(negedge clk);wr=0;tick(1);end endtask
 task clock0(input integer n);repeat(n)begin @(negedge clk);clocks=1;tick(1);@(negedge clk);clocks=0;tick(1);end endtask
 task configure(input [2:0] mode,input [15:0] n,input bit bcd);begin put(3,{2'b00,2'b11,mode,bcd});put(0,n[7:0]);put(0,n[15:8]);end endtask
 task getcount(output [15:0] value);begin put(3,0);address=0;#1;value[7:0]=dout;rd=1;tick(1);rd=0;tick(1);value[15:8]=dout;rd=1;tick(1);rd=0;tick(1);end endtask
 reg [15:0] v;
 initial begin
  tick(3);reset=0;tick(2);
  configure(0,3,0);clock0(2);if(out[0])$fatal(1,"8253 mode0 early terminal");clock0(1);if(!out[0])$fatal(1,"8253 mode0 terminal");
  configure(0,16'h0100,1);clock0(1);getcount(v);if(v!=16'h0099)$fatal(1,"8253 BCD borrow %h",v);
  gates[0]=0;clock0(10);getcount(v);if(v!=16'h0099)$fatal(1,"8253 gate pause");gates[0]=1;
  configure(0,0,1);clock0(1);getcount(v);if(v!=16'h9999)$fatal(1,"8253 BCD zero divisor");
  configure(2,4,0);clock0(2);put(0,6);put(0,0);clock0(1);if(!out[0])$fatal(1,"8253 rate update disturbed current period");clock0(1);if(out[0])$fatal(1,"8253 mode2 terminal");clock0(1);if(!out[0])$fatal(1,"8253 mode2 one-clock pulse");clock0(5);if(out[0])$fatal(1,"8253 new divisor period");
  configure(3,5,0);clock0(2);if(!out[0])$fatal(1,"8253 odd square high phase");clock0(1);if(out[0])$fatal(1,"8253 odd square transition");clock0(1);if(out[0])$fatal(1,"8253 odd square low phase");clock0(1);if(!out[0])$fatal(1,"8253 square period");
  configure(4,2,0);clock0(2);if(out[0])$fatal(1,"8253 software strobe");clock0(1);if(!out[0])$fatal(1,"8253 software strobe width");
  gates[0]=0;tick(2);configure(1,3,0);gates[0]=1;tick(2);if(!out[0])$fatal(1,"8253 one-shot started without clock");clock0(1);if(out[0])$fatal(1,"8253 one-shot trigger");clock0(2);if(out[0])$fatal(1,"8253 one-shot width");clock0(1);if(!out[0])$fatal(1,"8253 one-shot terminal");
  gates[0]=0;tick(2);configure(5,2,0);gates[0]=1;clock0(3);if(out[0])$fatal(1,"8253 hardware strobe");clock0(1);if(!out[0])$fatal(1,"8253 hardware strobe width");
  configure(0,16'h1234,0);put(3,0);clock0(8);address=0;#1;v[7:0]=dout;rd=1;tick(1);rd=0;tick(1);v[15:8]=dout;if(v!=16'h1234)$fatal(1,"8253 snapshot latch");
  $display("PASS 8253 modes0-5, BCD, gates, odd square wave, live divisor update and snapshot latch");$finish;
 end
 initial begin #100000;$fatal(1,"Timer timeout");end
endmodule
