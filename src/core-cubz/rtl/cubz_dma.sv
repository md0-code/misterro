// SPDX-License-Identifier: GPL-3.0-or-later
// Intel 8257 register file and channel-2 bus-master handshake.
module cubz_dma(input wire clk,reset,input wire io_wr,io_rd,input wire [3:0] regsel,
 input wire [7:0] din,output reg [7:0] dout,
 input wire drq,busack_n,input wire [7:0] fdc_data,ram_data,
 output wire busrq_n,fdc_read,fdc_write,ram_write,output wire [15:0] address,
 output wire [7:0] to_fdc,to_ram,output wire tc,output reg [31:0] transfers);
 reg [15:0] addr[0:3],count[0:3];reg [7:0] mode,status;
 reg high_byte;reg [2:0] state;reg [4:0] delay_count;reg [7:0] sampled;
 assign busrq_n=state==0 || state==6;
 assign address=addr[2];
 assign fdc_read=state==2 && count[2][15:14]!=2'b10;
 assign fdc_write=state==2 && count[2][15:14]==2'b10;
 assign ram_write=state==4 && count[2][15:14]==2'b01;
 // 8257 TC is valid during the last I/O strobe, before the FDC decides
 // whether EOT terminates the command. RAM commit follows the accepted byte.
 assign tc=state==2 && count[2][13:0]==0;
 assign to_ram=sampled;assign to_fdc=ram_data;
 always @*begin
  dout=8'hff;
  if(regsel<8)dout=regsel[0]?(high_byte?count[regsel[2:1]][15:8]:count[regsel[2:1]][7:0]):
                                              (high_byte?addr[regsel[2:1]][15:8]:addr[regsel[2:1]][7:0]);
  if(regsel==8)dout=status;
 end
 integer i;
 always @(posedge clk)begin
  if(reset)begin
   for(i=0;i<4;i=i+1)begin addr[i]<=0;count[i]<=0;end
   mode<=0;status<=0;high_byte<=0;state<=0;delay_count<=0;transfers<=0;sampled<=0;
  end else begin
   if(io_wr)begin
    if(regsel<8)begin
     if(regsel[0])begin
      if(high_byte)count[regsel[2:1]][15:8]<=din;else count[regsel[2:1]][7:0]<=din;
     end else begin
      if(high_byte)addr[regsel[2:1]][15:8]<=din;else addr[regsel[2:1]][7:0]<=din;
     end
     high_byte<=!high_byte;
    end else if(regsel==8)begin mode<=din;high_byte<=0;end
   end
   if(io_rd)begin if(regsel<8)high_byte<=!high_byte;else if(regsel==8)status<=0;end
   case(state)
    0:if(mode[2] && drq)state<=1;
    1:if(!busack_n)begin state<=2;delay_count<=15;end
    2:if(delay_count!=0)delay_count<=delay_count-1'b1;else begin state<=3;delay_count<=15;end
    3:if(delay_count!=0)delay_count<=delay_count-1'b1;else begin sampled<=fdc_data;state<=4;end
    4:begin
     addr[2]<=addr[2]+1'b1;count[2][13:0]<=count[2][13:0]-1'b1;transfers<=transfers+1'b1;
     if(count[2][13:0]==0)begin status[2]<=1;if(mode[6])mode[2]<=0;end
     state<=5;delay_count<=15;
    end
    5:if(delay_count!=0)delay_count<=delay_count-1'b1;else state<=6;
    6:if(busack_n)state<=0;
    default:state<=0;
   endcase
  end
 end
endmodule
