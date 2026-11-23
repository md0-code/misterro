`timescale 1ns/1ps
module serial_tb;
 reg clk=0;always #10 clk=~clk;
 reg reset=1,selected=0,rd_n=1,wr_n=1;reg [3:0] a=0;reg [7:0] din=0;wire [7:0] dout;
 wire [1:0] tx,rts,dtr;wire irq;
 junior_serial dut(.clk(clk),.reset(reset),.selected(selected),.address(a),.read_n(rd_n),.write_n(wr_n),
 .din(din),.dout(dout),.irq(irq),.rx(tx),.cts_n(2'b00),.dcd_n(2'b00),.dsr_n(2'b00),.tx(tx),.rts_n(rts),.dtr_n(dtr));
 task write(input [3:0] port,input [7:0] data);
 begin @(negedge clk);selected=1;a=port;din=data;wr_n=0;repeat(4)@(negedge clk);wr_n=1;din=~data;repeat(3)@(negedge clk);selected=0;end endtask
 task read(input [3:0] port,output [7:0] data);
 begin @(negedge clk);selected=1;a=port;rd_n=0;repeat(4)@(negedge clk);data=dout;rd_n=1;repeat(3)@(negedge clk);selected=0;end endtask
 task regwr(input [3:0] port,input [7:0] index,input [7:0] val);begin write(port,index);write(port,val);end endtask
 task check_value(input [7:0] actual,input [7:0] wanted,input [255:0] why);
 begin if(actual!==wanted)$fatal(1,"%s: %02x wanted %02x",why,actual,wanted);end endtask
 reg [7:0] val; realtime tx_start;
 initial begin
 repeat(10)@(negedge clk);reset=0;
 write(1,8'h18);write(3,8'h18);
 // 1.8432 MHz / 12 / 16 = 9600 baud. Channel B at 4800.
 write(7,8'h36);write(4,12);write(4,0);
 write(7,8'h76);write(5,24);write(5,0);
 regwr(1,4,8'h44);regwr(1,3,8'hc1);regwr(1,5,8'hea);
 regwr(3,4,8'h44);regwr(3,3,8'hc1);regwr(3,5,8'hea);
 regwr(3,2,8'h50);write(3,2);read(3,val);check_value(val,8'h50,"native BIOS SIO probe");
 regwr(3,2,8'hc0);regwr(3,1,8'h04);regwr(1,1,8'h18);
 read(1,val);check_value(val,8'h2c,"empty status");
 fork
  begin write(0,8'h55);end
  begin @(negedge tx[0]);tx_start=$realtime;@(posedge tx[0]);if($realtime-tx_start<104140 || $realtime-tx_start>104200)$fatal(1,"native baud rate incorrect: %f",$realtime-tx_start);end
 join
 #1500000;
 read(1,val);check_value(val,8'h2f,"A received with interrupt");
 if(!irq)$fatal(1,"RX IRQ absent");
 read(8,val);check_value(val,8'hcc,"vectored interrupt acknowledge");
 if(irq)$fatal(1,"in-service did not mask IRQ");
 read(0,val);check_value(val,8'h55,"loopback byte A");write(1,8'h38);
 if(irq)$fatal(1,"IRQ did not clear");
 write(1,1);read(1,val);check_value(val,1,"RR1 all sent and pointer stability");
 write(2,8'ha6);#2600000;read(2,val);check_value(val,8'ha6,"independent channel B");
 write(0,1);#1200000;write(0,2);#1200000;write(0,3);#1200000;write(0,4);#1200000;
 write(1,1);read(1,val);if(!val[5])$fatal(1,"RX overrun not reported");
 read(0,val);check_value(val,1,"FIFO byte1");read(0,val);check_value(val,2,"FIFO byte2");read(0,val);check_value(val,3,"FIFO byte3");
 write(1,8'h30);write(1,1);read(1,val);check_value(val,1,"error reset");
 read(12,val);check_value(val,1,"native DSR port");
 $display("RESULT: PASS native baud generator, A/B serial, FIFO, overrun, RR selection, IRQ vector and acknowledge");$finish;
 end
 initial begin #20000000;$fatal(1,"serial timeout");end
endmodule
