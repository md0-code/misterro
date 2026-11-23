`timescale 1ns/1ps
module printer_tb;
 reg clk=0;always #5 clk=~clk;reg reset=1,push=0,flush=0,mount=0,wp=0;reg [7:0] data=0;wire busy,overflow,wr;wire [31:0] lba,length;
 reg ack=0;reg [8:0] address=0;wire [7:0] q;
 rp_printer_spool #(.CLOCK_HZ(100000)) p(.clk(clk),.reset(reset),.push(push),.data(data),.flush(flush),.mounted(mount),.write_protect(wp),.image_bytes(32'd4096),.busy(busy),.overflow(overflow),.lba(lba),.sd_wr(wr),.sd_ack(ack),.buffer_address(address),.buffer_data(q),.length(length));
 reg [7:0] image[0:4095];reg [2:0] state=0;reg [31:0] sector=0;integer hold=0,sub=0,writes=0;
 always @(negedge clk)begin
  case(state)
   0:if(wr)begin ack=1;address=0;sector=lba;sub=0;state=1;writes=writes+1;if(lba>=8)$fatal(1,"Printer allocation bounds");end
   1:if(sub==2)begin image[sector*512+address]=q;sub=0;if(address==511)begin state=2;hold=8;end else address=address+1'b1;end else sub=sub+1;
   2:if(hold==0)begin ack=0;state=3;end else hold=hold-1;
   3:if(!wr)state=0;
  endcase
 end
 task tick(input integer n);repeat(n)begin @(posedge clk);#1;end endtask
 task send(input [7:0] v);begin while(busy)tick(1);@(negedge clk);push=1;data=v;tick(1);@(negedge clk);push=0;tick(1);end endtask
 task commit;begin flush=1;tick(2);flush=0;while(busy||state!=0)tick(1);tick(5);end endtask
 initial begin
  tick(4);reset=0;mount=1;tick(3);mount=0;tick(520);
  send("H");send("e");send("l");send("l");send("o");commit();
  if(image[32]!=5||image[512]!="H"||image[516]!="o")$fatal(1,"Printer partial commit");
  for(integer i=5;i<512;i=i+1)send(i[7:0]);while(busy)tick(1);
  send(8'h5a);commit();if(image[32]!=1||image[33]!=2||image[1024]!=8'h5a||image[512]!="H")$fatal(1,"Printer append after partial/full commit");
  if(overflow)$fatal(1,"Printer dropped valid handshakes");
  wp=1;mount=1;tick(2);mount=0;tick(520);if(!busy)$fatal(1,"Printer write protection");
  $display("PASS persistent printer partial/full/append jobs, byte count, backpressure, image bounds and write protection (%0d sectors)",writes);$finish;
 end
 initial begin #3000000;$fatal(1,"Printer timeout");end
endmodule
