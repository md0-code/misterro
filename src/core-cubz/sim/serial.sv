`timescale 1ns/1ps
// SIO channel A looped back on a CTC clock, receive interrupt through the daisy chain, and the GPZ PIO.
module serial;
 reg clk=0;always #5 clk=~clk;reg reset=1;
 reg cwr=0,swr=0,srd=0,pwr=0,ack=0,reti=0;reg [1:0] address=0;reg [7:0] din=0;
 wire [7:0] cdout,cvector,sdout,svector,pdout,a_out,a_drive;wire cirq,cbusy,sirq,sbusy;wire [3:0] zero;wire [1:0] tx,rts_n,dtr_n;
 cubz_ctc ctc(clk,reset,1'b1,cwr,address,din,cdout,1'b0,1'b0,1'b1,cirq,cvector,zero,cbusy);
 cubz_sio sio(clk,reset,swr,srd,address,address,din,sdout,zero[1:0],ack,reti,sirq,sbusy,svector,{1'b1,tx[0]},2'b00,2'b00,tx,rts_n,dtr_n);
 cubz_pio pio(clk,reset,pwr,address,din,pdout,8'h3c,8'hff,a_out,a_drive,,);
 task ctc_out(input [1:0] p,input [7:0] d);begin @(negedge clk);address=p;din=d;cwr=1;@(negedge clk);cwr=0;end endtask
 task sio_out(input [1:0] p,input [7:0] d);begin @(negedge clk);address=p;din=d;swr=1;@(negedge clk);swr=0;end endtask
 task pio_out(input [1:0] p,input [7:0] d);begin @(negedge clk);address=p;din=d;pwr=1;@(negedge clk);pwr=0;end endtask
 task sio_in(input [1:0] p,output [7:0] d);begin @(negedge clk);address=p;#1;d=sdout;srd=1;@(negedge clk);srd=0;end endtask
 reg [7:0] value;
 initial begin
  repeat(10)@(negedge clk);reset=0;
  ctc_out(0,8'h05);ctc_out(0,2);                       // timer, prescaler 16, constant 2: the SIO clock
  sio_out(3,2);sio_out(3,8'h40);sio_out(3,1);sio_out(3,4); // B: vector 40, status affects vector
  sio_out(1,4);sio_out(1,8'h44);                       // A: x16, one stop bit
  sio_out(1,3);sio_out(1,8'hc1);sio_out(1,5);sio_out(1,8'h68);sio_out(1,1);sio_out(1,8'h10); // 8 bits, receive interrupts
  sio_out(0,8'h5a);
  repeat(7000)@(negedge clk);
  if(!sirq)$fatal(1,"SIO receive interrupt");
  @(negedge clk);ack=1;@(negedge clk);ack=0;#1;
  if(svector!=8'h4c || sirq || !sbusy)$fatal(1,"SIO vector/service %h",svector);
  sio_in(1,value);if(!value[0])$fatal(1,"SIO receive status");
  sio_in(0,value);if(value!=8'h5a)$fatal(1,"SIO loopback data %h",value);
  @(negedge clk);reti=1;@(negedge clk);reti=0;#1;if(sbusy)$fatal(1,"SIO RETI");
  pio_out(1,8'hcf);pio_out(1,8'hf0);pio_out(0,8'ha5);address=0;#1;
  if(a_drive!=8'h0f || a_out[3:0]!=4'h5 || pdout!=8'h35)$fatal(1,"PIO bit mode %h %h %h",a_drive,a_out,pdout);
  $display("PASS: SIO loopback on the CTC clock, vectored receive interrupt, RETI and GPZ PIO bit mode");$finish;
 end
endmodule
