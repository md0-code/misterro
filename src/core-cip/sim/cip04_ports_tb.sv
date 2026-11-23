`timescale 1ns/1ps
// The firmware's printer sequence (data to 0FFD, strobe low then high) and its serial bits on AY register 14.
module cip04_ports_tb;
 reg clk=0;always #5 clk=~clk;reg reset=1;
 reg [15:0] addr=0;reg [7:0] din=0;reg io_wr=0,psg_we=0,strobe_n=1,printer_mode=1,rxd=1,cts=0;
 wire txd,rts,sel,busy,ay_sel;wire [7:0] ay_in;
 cip04_ports #(.DIVIDER(4)) ports(clk,reset,1'b1,addr,din,io_wr,psg_we,strobe_n,printer_mode,rxd,cts,txd,rts,sel,busy,ay_sel,ay_in);
 reg [9:0] seen;integer i;
 initial begin
  repeat(4)@(negedge clk);reset=0;
  addr=16'h0ffd;din=8'h41;#1;if(!sel || busy)$fatal(1,"Printer select/ready");
  io_wr=1;@(negedge clk);io_wr=0;strobe_n=0;@(negedge clk);strobe_n=1;@(negedge clk);
  if(!busy)$fatal(1,"Printer busy during the byte");
  for(i=0;i<10;i=i+1)begin seen[i]=txd;repeat(4)@(negedge clk);end
  if(seen!={1'b1,8'h41,1'b0})$fatal(1,"Printer frame %b",seen);
  repeat(8)@(negedge clk);if(busy)$fatal(1,"Printer ready after the byte");
  printer_mode=0;addr=16'hfffd;din=14;psg_we=1;@(negedge clk);addr=16'hbffd;din=8'hf2;@(negedge clk);psg_we=0;rxd=0;cts=1;#1;
  if(txd || rts || !ay_sel || ay_in!=8'h72 || !busy)$fatal(1,"Serial bits %b %b %h",txd,rts,ay_in);
  $display("PASS: CIP-04 printer data/strobe/busy and serial TXD/CTS/RXD/DTR on AY register 14");$finish;
 end
endmodule
