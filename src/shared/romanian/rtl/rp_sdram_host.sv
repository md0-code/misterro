// SPDX-License-Identifier: GPL-3.0-or-later
// Level request/acknowledge adapter for the pinned MiSTer SDRAM controller.
module rp_sdram_host(input wire clk,reset,req,write,input wire [24:0] address,input wire [7:0] din,
 output reg ack=0,output wire [7:0] dout,inout wire [15:0] SDRAM_DQ,output wire [12:0] SDRAM_A,output wire [1:0] SDRAM_BA,
 output wire SDRAM_DQML,SDRAM_DQMH,SDRAM_nCS,SDRAM_nCAS,SDRAM_nRAS,SDRAM_nWE,SDRAM_CKE,SDRAM_CLK);
 wire ready;reg rd=0,we=0;reg [2:0] state=0;
 always @(posedge clk)begin
  rd<=0;we<=0;
  if(reset)begin state<=0;ack<=0;end
  else case(state)
   0:if(req&&ready)begin rd<=!write;we<=write;state<=1;end
   1:state<=2;
   2:state<=3;
   3:if(ready)begin ack<=1;state<=4;end
   4:if(!req)begin ack<=0;state<=0;end
   default:state<=0;
  endcase
 end
 rp_sdram memory(.init(reset),.clk(clk),.addr(address),.din(din),.dout(dout),.rd(rd),.we(we),.ready(ready),
 .SDRAM_DQ(SDRAM_DQ),.SDRAM_A(SDRAM_A),.SDRAM_BA(SDRAM_BA),.SDRAM_DQML(SDRAM_DQML),.SDRAM_DQMH(SDRAM_DQMH),.SDRAM_nCS(SDRAM_nCS),.SDRAM_nCAS(SDRAM_nCAS),.SDRAM_nRAS(SDRAM_nRAS),.SDRAM_nWE(SDRAM_nWE),.SDRAM_CKE(SDRAM_CKE),.SDRAM_CLK(SDRAM_CLK));
endmodule
