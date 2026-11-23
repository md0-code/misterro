// SPDX-License-Identifier: GPL-3.0-or-later
module cubz_ctc(input wire clk,reset,ce,wr,input wire [1:0] channel,input wire [7:0] din,output wire [7:0] dout,input wire acknowledge,reti,input wire trigger3,output wire irq,output reg [7:0] vector,output reg [3:0] zero,output wire busy);
 reg [7:0] control[0:3],constant[0:3];reg [8:0] count[0:3];reg [7:0] prescale[0:3];reg [3:0] expecting,running;
 reg [3:0] pending,in_service;
 reg [7:0] vector_base;
 reg [1:0] selected;
 reg request,blocked;
 reg old_trigger3;
 always @*begin
  selected=0;request=0;blocked=0;
  for(integer k=0;k<4;k=k+1)begin
   if(in_service[k])blocked=1;
   if(!blocked && !request && pending[k] && control[k][7])begin request=1;selected=k[1:0];end
  end
 end
 assign irq=request;assign busy=|in_service;
 reg [25:0] ext_phase;reg ext_ce;integer i;
 assign dout=count[channel][7:0];
 always @(posedge clk)begin
  ext_ce<=0;old_trigger3<=trigger3;zero<=0;
  if(ext_phase>=40000000-583125)begin ext_phase<=ext_phase-(40000000-583125);ext_ce<=1;end else ext_phase<=ext_phase+583125;
  if(reset)begin
   ext_phase<=0;ext_ce<=0;expecting<=0;running<=0;pending<=0;in_service<=0;vector_base<=0;vector<=0;old_trigger3<=1;
   for(i=0;i<4;i=i+1)begin control[i]<=3;constant[i]<=0;count[i]<=256;prescale[i]<=0;end
  end else begin
   for(i=0;i<4;i=i+1)begin
    if(running[i])begin
     if(control[i][6] ? ((ext_ce && i<3) || (i==3 && (control[i][4]?(trigger3 && !old_trigger3):(!trigger3 && old_trigger3)))) : (ce && (control[i][5]?prescale[i]==255:prescale[i][3:0]==15)))begin
      if(count[i]<=1 && control[i][7])pending[i]<=1;
      if(count[i]<=1)zero[i]<=1;
      count[i]<=count[i]<=1?(constant[i]==0?9'd256:{1'b0,constant[i]}):count[i]-1'b1;
     end
     if(ce)prescale[i]<=prescale[i]+1'b1;
    end
   end
   if(acknowledge && request)begin
    vector<={vector_base[7:3],selected,1'b0};pending[selected]<=0;in_service[selected]<=1;
   end
   if(reti)begin
    if(in_service[0])in_service[0]<=0;
    else if(in_service[1])in_service[1]<=0;
    else if(in_service[2])in_service[2]<=0;
    else if(in_service[3])in_service[3]<=0;
   end
   if(wr)begin
    if(expecting[channel])begin constant[channel]<=din;count[channel]<=din==0?9'd256:{1'b0,din};expecting[channel]<=0;running[channel]<=1;prescale[channel]<=0;end
    else if(din[0])begin control[channel]<=din;expecting[channel]<=din[2];if(din[1])begin running[channel]<=0;pending[channel]<=0;in_service[channel]<=0;end end
    else if(channel==0)vector_base<=din & 8'hf8;
   end
  end
 end
endmodule
