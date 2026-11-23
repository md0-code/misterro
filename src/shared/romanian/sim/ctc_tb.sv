`timescale 1ns/1ps
module ctc_tb;
 reg clk=0;always #5 clk=~clk;reg reset=1,ce=1,wr=0,ack=0,reti=0;reg [1:0] channel=0;reg [7:0] data=0;reg [3:0] triggers=0;wire [7:0] q,vector;wire [3:0] zero;wire irq;
 rp_z80ctc c(.clk(clk),.reset(reset),.ce(ce),.wr(wr),.channel(channel),.din(data),.dout(q),.acknowledge(ack),.reti(reti),.triggers(triggers),.zero(zero),.irq(irq),.vector(vector));
 task tick(input integer n);repeat(n)begin @(posedge clk);#1;end endtask
 task write(input [1:0] ch,input [7:0] v);begin @(negedge clk);channel=ch;data=v;wr=1;tick(1);@(negedge clk);wr=0;end endtask
 task edge_in(input integer ch);begin @(negedge clk);triggers[ch]=0;tick(1);@(negedge clk);triggers[ch]=1;tick(1);end endtask
 task acknowledge(input [7:0] expected);begin @(negedge clk);ack=1;tick(1);@(negedge clk);ack=0;tick(1);if(vector!==expected)$fatal(1,"CTC vector %h expected %h",vector,expected);end endtask
 task return_irq;begin @(negedge clk);reti=1;tick(1);@(negedge clk);reti=0;tick(1);end endtask
 initial begin
 tick(3);reset=0;write(0,8'hd0);write(0,8'hd7);write(0,2);write(2,8'hd7);write(2,1);write(3,8'hd7);write(3,1);
 edge_in(0);if(irq)$fatal(1,"CTC counter divisor");edge_in(0);if(!irq)$fatal(1,"CTC counter edge");acknowledge(8'hd0);
 edge_in(3);if(irq)$fatal(1,"CTC daisy priority");return_irq;if(!irq)$fatal(1,"CTC pending lower priority");acknowledge(8'hd6);
 edge_in(2);if(!irq)$fatal(1,"CTC nested higher priority");acknowledge(8'hd4);return_irq;return_irq;
 write(1,8'h87);write(1,2);tick(34);if(!irq)$fatal(1,"CTC timer prescaler");acknowledge(8'hd2);write(1,3);return_irq;
 // External timer trigger must start, not decrement, its 16x prescaler.
 write(1,8'h9f);write(1,1);tick(40);if(irq)$fatal(1,"CTC external start armed");edge_in(1);tick(17);if(!irq)$fatal(1,"CTC external trigger");
 $display("PASS CTC counter edges, timer prescaler, external trigger, nested priority, vector hold and RETI");$finish;
 end
 initial begin #100000;$fatal(1,"CTC timeout");end
endmodule
