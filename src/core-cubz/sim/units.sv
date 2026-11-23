`timescale 1ns/1ps
module units;
 reg clk=0;always #5 clk=~clk;
 reg reset=1;reg [10:0] key=0;reg pulse=0;wire kd,kc,overflow;
 cubz_keyboard #(.SYS_HZ(40000)) keyboard(clk,reset,key,pulse,kd,kc,overflow);
 reg wr=0,rd=0;reg [3:0] regsel=0;reg [7:0] din=0;wire [7:0] dout;
 wire busrq_n,fr,fw,rw,tc;wire [15:0] address;wire [7:0] to_fdc,to_ram;wire [31:0] transfers;
 reg [4:0] ackdelay=31;wire busack_n=ackdelay[4];
 always @(posedge clk)ackdelay<={ackdelay[3:0],busrq_n};
 cubz_dma dma(clk,reset,wr,rd,regsel,din,dout,1'b1,busack_n,8'ha5,8'h5a,busrq_n,fr,fw,rw,address,to_fdc,to_ram,tc,transfers);
 integer writes=0,tcs=0;reg old_tc=0;
 always @(posedge clk)begin
  if(rw)begin
   if(address!=16'h1234+writes || to_ram!=8'ha5 || busack_n)$fatal(1,"DMA data/address/ownership");
   writes=writes+1;
  end
  if(tc && !old_tc)tcs=tcs+1;
  if(tc && !(fr || fw))$fatal(1,"TC must accompany the final I/O byte");
  old_tc<=tc;
 end
 task out(input [3:0] port,input [7:0] data);
  begin @(negedge clk);regsel=port;din=data;wr=1;@(negedge clk);wr=0;end
 endtask
 task query(input expected);
  begin @(negedge clk);pulse=1;repeat(10)@(negedge clk);pulse=0;repeat(10)@(negedge clk);if(kd!==expected)$fatal(1,"Keyboard serial bit");end
 endtask
 integer j;
 initial begin
  repeat(10)@(negedge clk);reset=0;
  key=11'h61c; // toggle=1, make=1, A set-2 scancode
  repeat(4100)@(negedge clk);
  if(!kc)$fatal(1,"Keyboard busy did not end");
  query(0);for(j=0;j<8;j=j+1)query((8'h61>>j)&1);query(1);
  repeat(12000)@(negedge clk);
  query(0);for(j=0;j<8;j=j+1)query((8'h61>>j)&1);query(1);
  key=11'h01c;repeat(5000)@(negedge clk);query(1);
  if(overflow)$fatal(1,"Keyboard overflow");
  out(4,8'h34);out(4,8'h12);out(5,3);out(5,8'h40);out(8,8'h64);
  repeat(1000)@(negedge clk);
  if(writes!=4 || transfers!=4 || tcs!=1 || !busrq_n)$fatal(1,"DMA count/TC/stop");
  regsel=8;#1;if(dout!=4)$fatal(1,"DMA TC status");
  @(negedge clk);rd=1;@(negedge clk);rd=0;#1;if(dout!=0)$fatal(1,"DMA status clear");
  $display("PASS: native serial keyboard and 8257 channel-2 bus ownership, byte order, TC and status");$finish;
 end
endmodule
