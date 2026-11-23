// SPDX-License-Identifier: GPL-3.0-or-later
module tape_memory_tb;
 reg clk=0,reset=1,download=0,wr=0;reg [26:0] address=0;reg [7:0] data=0;
 reg [24:0] probe=0;integer i;wire overflow;
 always #5 clk=~clk;
 function [7:0] value(input integer n);value=(n*73+(n>>8)*17)^8'ha5;endfunction
 rp_tape dut(.mode48k(1'b1),.clk(clk),.reset(reset),.ce(1'b0),.download(download),.wr(wr),.address(address),.data(data),
 .mode(2'd0),.pause(1'b0),.prev(1'b0),.next(1'b0),.audio(),.active(),.available(),.overflow(overflow));
 initial begin
  repeat(4)@(negedge clk);reset=0;download=1;repeat(3)@(negedge clk);
  for(i=0;i<262144;i=i+1)begin wr=1;address=i;data=value(i);@(negedge clk);if(i%31==0)begin wr=0;repeat(2)@(negedge clk);end end
  wr=0;download=0;repeat(8)@(negedge clk);
  if(overflow || !dut.ready || dut.length!=262144)$fatal(1,"Full tape capacity was not retained");
  for(i=0;i<262144;i=i+1)begin
   probe=i;force dut.read_address=probe;repeat(10)@(negedge clk);
   if(dut.read_q!=value(i))$fatal(1,"Packed tape mismatch at %h: %h vs %h",i,dut.read_q,value(i));
   release dut.read_address;
  end
  download=1;repeat(3)@(negedge clk);address=262144;wr=1;@(negedge clk);wr=0;download=0;repeat(8)@(negedge clk);
  if(!overflow || dut.ready)$fatal(1,"Oversized tape accepted");
  $display("PASS: every byte of 256 KiB packed tape RAM, upload gaps, partial word flush and overflow rejection");$finish;
 end
endmodule
