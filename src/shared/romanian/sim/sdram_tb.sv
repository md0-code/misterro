`timescale 1ns/1ps
module altddio_out #(parameter extend_oe_disable="",intended_device_family="",invert_output="",lpm_hint="",lpm_type="",oe_reg="",power_up_high="",width=1)(input [width-1:0]datain_h,datain_l,input outclock,aclr,aset,oe,outclocken,sclr,sset,output [width-1:0]dataout);assign dataout=outclock?datain_h:datain_l;endmodule
module sdram_tb;
 reg clk=0;always #6 clk=~clk;reg reset=1,req=0,write=0;reg [24:0] address=0;reg [7:0] din=0;wire ack;wire [7:0] q;tri [15:0] dq;wire [12:0] a;wire [1:0] ba;wire ml,mh,cs,cas,ras,we,cke,sclk;
 rp_sdram_host h(.clk(clk),.reset(reset),.req(req),.write(write),.address(address),.din(din),.ack(ack),.dout(q),.SDRAM_DQ(dq),.SDRAM_A(a),.SDRAM_BA(ba),.SDRAM_DQML(ml),.SDRAM_DQMH(mh),.SDRAM_nCS(cs),.SDRAM_nCAS(cas),.SDRAM_nRAS(ras),.SDRAM_nWE(we),.SDRAM_CKE(cke),.SDRAM_CLK(sclk));
 reg [12:0] row[0:3];reg [15:0] memory[0:262143];reg [15:0] read_data;reg [2:0] read_pipe=0;integer reads=0,writes=0,refreshes=0;reg [17:0] index;
 assign dq=read_pipe[0]?read_data:16'hzzzz;
 always @(negedge clk)begin
  read_pipe<={1'b0,read_pipe[2:1]};
  if(!cs)case({ras,cas,we})
   3'b011:row[ba]<=a;
   3'b100:begin index={ba,row[ba][7:0],a[7:0]};if(!ml)memory[index][7:0]<=dq[7:0];if(!mh)memory[index][15:8]<=dq[15:8];writes=writes+1;end
   3'b101:begin index={ba,row[ba][7:0],a[7:0]};read_data<=memory[index];read_pipe<=3'b100;reads=reads+1;end
   3'b001:refreshes=refreshes+1;
  endcase
 end
 task tick(input integer n);repeat(n)begin @(posedge clk);#1;end endtask
 task access(input bit writing,input [24:0] addr,input [7:0] value);integer timeout;begin
 @(negedge clk);req=1;write=writing;address=addr;din=value;timeout=0;
 while(!ack&&timeout<20000)begin tick(1);timeout=timeout+1;end
 if(!ack)$fatal(1,"SDRAM host acknowledgement timeout");if(!writing&&q!==value)$fatal(1,"SDRAM byte read %h = %h expected %h",addr,q,value);
 tick(4);if(!ack)$fatal(1,"SDRAM ack must hold while req asserted");@(negedge clk);req=0;tick(4);
 end endtask
 initial begin
 tick(10);reset=0;access(1,25'h0,8'h51);access(1,25'h1,8'ha6);access(1,25'h40000,8'hc3);access(1,25'h1000000,8'h12);access(1,25'h1800200,8'h34);
 access(0,25'h0,8'h51);access(0,25'h1,8'ha6);access(0,25'h40000,8'hc3);access(0,25'h1000000,8'h12);access(0,25'h1800200,8'h34);access(0,25'h0,8'h51);access(0,25'h1,8'ha6);
 tick(3000);if(reads<5||writes!=5||refreshes<6)$fatal(1,"SDRAM command/refresh coverage");$display("PASS SDRAM PHY startup, byte masks, bank/column address, cached reads, host acknowledgement and refresh");$finish;
 end
 initial begin #1000000;$fatal(1,"SDRAM timeout");end
endmodule
