// SPDX-License-Identifier: GPL-3.0-or-later
module rp_i8255(input wire clk,reset,wr,rd,input wire [1:0] address,input wire [7:0] din,
 input wire [7:0] pa_in,pb_in,pc_in,output reg [7:0] dout,pa_out,pb_out,pc_out,
 output reg [7:0] pa_oe,pb_oe,pc_oe,output wire irq,output reg [7:0] control=8'h9b);
 reg [7:0] a=0,b=0,c=0,ia=0,ib=0,previous_c=8'hff;
 reg ibfa=0,ibfb=0,obfa=1,obfb=1,inte_ai=0,inte_ao=0,inte_b=0;
 wire mode2=control[6],mode1a=!control[6]&&control[5],mode1b=control[2];
 wire inputa=control[4],inputb=control[1];
 wire intra=((mode2||mode1a&&inputa)&&inte_ai&&ibfa&&pc_in[4])||((mode2||mode1a&&!inputa)&&inte_ao&&obfa&&pc_in[6]);
 wire intrb=mode1b&&inte_b&&(inputb?ibfb:obfb)&&pc_in[2];
 assign irq=intra||intrb;
 always @*begin
  pa_out=a;pb_out=b;pc_out=c;pa_oe={8{!inputa&&!mode2 || mode2&&!pc_in[6]}};
  pb_oe={8{!inputb}};pc_oe={{4{!control[3]}},{4{!control[0]}}};
  if(mode2)begin pc_oe[7:3]=5'b10101;pc_out[7]=obfa;pc_out[5]=ibfa;pc_out[3]=intra;end
  else if(mode1a)begin
   pc_oe[3]=1;pc_out[3]=intra;
   if(inputa)begin pc_oe[4]=0;pc_oe[5]=1;pc_out[5]=ibfa;end
   else begin pc_oe[6]=0;pc_oe[7]=1;pc_out[7]=obfa;end
  end
  if(mode1b)begin pc_oe[2:0]=3'b011;pc_out[1]=inputb?ibfb:obfb;pc_out[0]=intrb;end
  case(address)
   0:dout=mode2||mode1a&&inputa?ia:inputa?pa_in:a;
   1:dout=mode1b&&inputb?ib:inputb?pb_in:b;
   2:dout=(pc_out&pc_oe)|(pc_in&~pc_oe);
   3:dout=control;
  endcase
 end
 always @(posedge clk)begin
  previous_c<=pc_in;
  if(reset)begin control<=8'h9b;a<=0;b<=0;c<=0;ibfa<=0;ibfb<=0;obfa<=1;obfb<=1;inte_ai<=0;inte_ao<=0;inte_b<=0;previous_c<=8'hff;end
  else begin
   if((mode2||mode1a&&inputa)&&previous_c[4]&&!pc_in[4])begin ia<=pa_in;ibfa<=1;end
   if((mode2||mode1a&&!inputa)&&!previous_c[6]&&pc_in[6])obfa<=1;
   if(mode1b&&inputb&&previous_c[2]&&!pc_in[2])begin ib<=pb_in;ibfb<=1;end
   if(mode1b&&!inputb&&!previous_c[2]&&pc_in[2])obfb<=1;
   if(rd)begin if(address==0)ibfa<=0;if(address==1)ibfb<=0;end
   if(wr)case(address)
    0:begin a<=din;if(mode2||mode1a&&!inputa)obfa<=0;end
    1:begin b<=din;if(mode1b&&!inputb)obfb<=0;end
    2:c<=din;
    3:if(din[7])begin control<=din;a<=0;b<=0;c<=0;ibfa<=0;ibfb<=0;obfa<=1;obfb<=1;inte_ai<=0;inte_ao<=0;inte_b<=0;end
    else begin
     c[din[3:1]]<=din[0];
     if(din[3:1]==4)inte_ai<=din[0];if(din[3:1]==6)inte_ao<=din[0];if(din[3:1]==2)inte_b<=din[0];
    end
   endcase
  end
 end
endmodule
