`timescale 1ns/1ps
module peripherals_tb;
 reg clk=0;always #5 clk=~clk;reg reset=1;
 reg wr=0,rd=0,cp=0;reg [7:0] din=0;wire [7:0] dout;wire tx;reg cts=0;wire rxr,txr,empty,sd;
 reg receive_override=0,rx_input=1;
 rp_i8251 u(.clk(clk),.reset(reset),.wr(wr),.rd(rd),.command_port(cp),.din(din),.txc(1'b1),.rxc(1'b1),.rx(receive_override?rx_input:tx),.cts_n(cts),.dsr_n(1'b0),.external_sync(1'b0),.dout(dout),.tx(tx),.rts_n(),.dtr_n(),.tx_ready(txr),.rx_ready(rxr),.tx_empty(empty),.sync_detect(sd));
 reg pw=0,pr=0;reg [1:0] pa=0;reg [7:0] pd=0,ai=8'hff,bi=8'hff,ci=8'hff;
 wire [7:0] pq,ao,bo,co,ae,be,ce;wire irq;
 rp_i8255 p(.clk(clk),.reset(reset),.wr(pw),.rd(pr),.address(pa),.din(pd),.pa_in(ai),.pb_in(bi),.pc_in(ci),.dout(pq),.pa_out(ao),.pb_out(bo),.pc_out(co),.pa_oe(ae),.pb_oe(be),.pc_oe(ce),.irq(irq),.control());
 task tick(input integer n);repeat(n)begin @(posedge clk);#1;end endtask
 task uw(input bit port,input [7:0] value);begin @(negedge clk);cp=port;din=value;wr=1;tick(1);@(negedge clk);wr=0;tick(1);end endtask
 task ur;begin @(negedge clk);cp=0;rd=1;tick(1);@(negedge clk);rd=0;tick(1);end endtask
 task pp(input [1:0] port,input [7:0] value);begin @(negedge clk);pa=port;pd=value;pw=1;tick(1);@(negedge clk);pw=0;tick(1);end endtask
 task inituart(input [7:0] mode);begin reset=1;tick(3);reset=0;tick(2);uw(1,mode);uw(1,8'h27);end endtask
 task loopbyte(input [7:0] value,input integer cycles);begin uw(0,value);tick(cycles);cp=0;#1;if(!rxr||dout!=value)$fatal(1,"8251 received %h expected %h ready %b",dout,value,rxr);ur();if(rxr)$fatal(1,"8251 read failed to clear RXRDY");end endtask
 initial begin
  tick(3);reset=0;tick(2);
  pp(3,8'h92);ai=8'ha5;bi=8'h69;pa=0;#1;if(pq!=8'ha5||ae!=0)$fatal(1,"8255 mode0 input");pp(2,8'h53);if(co!=8'h53||ce!=8'hff)$fatal(1,"8255 mode0 output");
  pp(3,8'h09);if(!co[4])$fatal(1,"8255 BSR set");pp(3,8'h08);if(co[4])$fatal(1,"8255 BSR clear");
  pp(3,8'hb0);pp(3,8'h09);ai=8'h3c;ci[4]=0;tick(2);ai=8'he7;ci[4]=1;tick(2);pa=0;#1;if(pq!=8'h3c||!irq)$fatal(1,"8255 strobed input IRQ/latch");pr=1;tick(1);pr=0;tick(1);if(irq)$fatal(1,"8255 input acknowledgment");
  pp(3,8'hc0);#1;if(ce[7:3]!=5'b10101)$fatal(1,"8255 bidirectional handshake directions");
  inituart(8'h4d);loopbyte(8'ha5,80); // x1, 8N1
  inituart(8'hfa);loopbyte(8'h55,300); // x16, 7E2
  inituart(8'h83);loopbyte(8'h15,800); // x64, 5N1.5
  inituart(8'h4e);cts=1;uw(0,8'h96);tick(100);if(!tx||txr)$fatal(1,"8251 CTS gating");cts=0;tick(200);cp=0;#1;if(!rxr||dout!=8'h96)$fatal(1,"8251 CTS resume");
  // A second received word before a CPU read sets overrun and retains the first.
  uw(0,8'h3c);tick(200);cp=1;#1;if(!dout[4])$fatal(1,"8251 overrun");uw(1,8'h37);cp=1;#1;if(dout[5:3]!=0)$fatal(1,"8251 error reset");ur();
  // Synchronous receive hunts an arbitrary bit alignment for two sync characters.
  reset=1;tick(3);reset=0;uw(1,8'h0c);uw(1,8'h16);uw(1,8'h2a);uw(1,8'ha7);receive_override=1;
  for(integer j=0;j<3;j=j+1)begin rx_input=1;tick(1);end
  for(integer j=0;j<8;j=j+1)begin rx_input=(8'h16>>j)&1;tick(1);end
  for(integer j=0;j<8;j=j+1)begin rx_input=(8'h2a>>j)&1;tick(1);end
  if(!sd)$fatal(1,"8251 synchronous hunt");
  for(integer j=0;j<8;j=j+1)begin rx_input=(8'hb9>>j)&1;tick(1);end
  cp=0;#1;if(!rxr||dout!=8'hb9)$fatal(1,"8251 synchronous receive");
  $display("PASS 8255 mode0/mode1/mode2, 8251 x1/x16/x64, framing, CTS, overrun and synchronous hunt");$finish;
 end
 initial begin #200000;$fatal(1,"peripheral timeout");end
endmodule
