// SPDX-License-Identifier: GPL-3.0-or-later
// 8253 counter/timer: independent clocks/gates, modes 0..5, binary/BCD, latch and byte order.
module rp_i8253(input wire clk,reset,wr,rd,input wire [1:0] address,input wire [7:0] din,input wire [2:0] clocks,gates,
 output reg [7:0] dout,output reg [2:0] out=0);
 reg [15:0] reload_raw[0:2],bcd_count[0:2],latched[0:2];reg [16:0] reload_value[0:2],count[0:2],half_count[0:2];
 reg [2:0] mode[0:2];reg [1:0] access_mode[0:2];reg [2:0] bcd=0,write_high=0,read_high=0,latch_valid=0,latch_high=0,running=0,loaded=0,old_gates=0,pulse=0,trigger_pending=0;
 reg [7:0] low[0:2];wire [2:0] trigger=gates&~old_gates;
 function automatic [16:0] times_1000(input [3:0] digit);
  case(digit)
   4'd0:times_1000=17'd0;
   4'd1:times_1000=17'd1000;
   4'd2:times_1000=17'd2000;
   4'd3:times_1000=17'd3000;
   4'd4:times_1000=17'd4000;
   4'd5:times_1000=17'd5000;
   4'd6:times_1000=17'd6000;
   4'd7:times_1000=17'd7000;
   4'd8:times_1000=17'd8000;
   4'd9:times_1000=17'd9000;
   4'd10:times_1000=17'd10000;
   4'd11:times_1000=17'd11000;
   4'd12:times_1000=17'd12000;
   4'd13:times_1000=17'd13000;
   4'd14:times_1000=17'd14000;
   4'd15:times_1000=17'd15000;
   default:times_1000=0;
  endcase
 endfunction
 function automatic [16:0] times_100(input [3:0] digit);
  case(digit)
   4'd0:times_100=17'd0;
   4'd1:times_100=17'd100;
   4'd2:times_100=17'd200;
   4'd3:times_100=17'd300;
   4'd4:times_100=17'd400;
   4'd5:times_100=17'd500;
   4'd6:times_100=17'd600;
   4'd7:times_100=17'd700;
   4'd8:times_100=17'd800;
   4'd9:times_100=17'd900;
   4'd10:times_100=17'd1000;
   4'd11:times_100=17'd1100;
   4'd12:times_100=17'd1200;
   4'd13:times_100=17'd1300;
   4'd14:times_100=17'd1400;
   4'd15:times_100=17'd1500;
   default:times_100=0;
  endcase
 endfunction
 function automatic [16:0] times_10(input [3:0] digit);
  case(digit)
   4'd0:times_10=17'd0;
   4'd1:times_10=17'd10;
   4'd2:times_10=17'd20;
   4'd3:times_10=17'd30;
   4'd4:times_10=17'd40;
   4'd5:times_10=17'd50;
   4'd6:times_10=17'd60;
   4'd7:times_10=17'd70;
   4'd8:times_10=17'd80;
   4'd9:times_10=17'd90;
   4'd10:times_10=17'd100;
   4'd11:times_10=17'd110;
   4'd12:times_10=17'd120;
   4'd13:times_10=17'd130;
   4'd14:times_10=17'd140;
   4'd15:times_10=17'd150;
   default:times_10=0;
  endcase
 endfunction
 function automatic [16:0] times_500(input [3:0] digit);
  case(digit)
   4'd0:times_500=17'd0;
   4'd1:times_500=17'd500;
   4'd2:times_500=17'd1000;
   4'd3:times_500=17'd1500;
   4'd4:times_500=17'd2000;
   4'd5:times_500=17'd2500;
   4'd6:times_500=17'd3000;
   4'd7:times_500=17'd3500;
   4'd8:times_500=17'd4000;
   4'd9:times_500=17'd4500;
   4'd10:times_500=17'd5000;
   4'd11:times_500=17'd5500;
   4'd12:times_500=17'd6000;
   4'd13:times_500=17'd6500;
   4'd14:times_500=17'd7000;
   4'd15:times_500=17'd7500;
   default:times_500=0;
  endcase
 endfunction
 function automatic [16:0] times_50(input [3:0] digit);
  case(digit)
   4'd0:times_50=17'd0;
   4'd1:times_50=17'd50;
   4'd2:times_50=17'd100;
   4'd3:times_50=17'd150;
   4'd4:times_50=17'd200;
   4'd5:times_50=17'd250;
   4'd6:times_50=17'd300;
   4'd7:times_50=17'd350;
   4'd8:times_50=17'd400;
   4'd9:times_50=17'd450;
   4'd10:times_50=17'd500;
   4'd11:times_50=17'd550;
   4'd12:times_50=17'd600;
   4'd13:times_50=17'd650;
   4'd14:times_50=17'd700;
   4'd15:times_50=17'd750;
   default:times_50=0;
  endcase
 endfunction
 function automatic [16:0] times_5(input [3:0] digit);
  case(digit)
   4'd0:times_5=17'd0;
   4'd1:times_5=17'd5;
   4'd2:times_5=17'd10;
   4'd3:times_5=17'd15;
   4'd4:times_5=17'd20;
   4'd5:times_5=17'd25;
   4'd6:times_5=17'd30;
   4'd7:times_5=17'd35;
   4'd8:times_5=17'd40;
   4'd9:times_5=17'd45;
   4'd10:times_5=17'd50;
   4'd11:times_5=17'd55;
   4'd12:times_5=17'd60;
   4'd13:times_5=17'd65;
   4'd14:times_5=17'd70;
   4'd15:times_5=17'd75;
   default:times_5=0;
  endcase
 endfunction
 // Nibble lookup tables avoid DSP multipliers on the asynchronous write path.
 function automatic [16:0] decode(input [15:0] v,input bit decimal_mode);
  reg [16:0] high_part,low_part;
  begin
   high_part=times_1000(v[15:12])+times_100(v[11:8]);
   low_part=times_10(v[7:4])+{13'd0,v[3:0]};
   decode=decimal_mode?(v==0?17'd10000:high_part+low_part):(v==0?17'd65536:{1'b0,v});
  end
 endfunction
 function automatic [16:0] decode_half(input [15:0] v,input bit decimal_mode);
  reg [16:0] high_part,low_part;
  begin
   high_part=times_500(v[15:12])+times_50(v[11:8]);
   low_part=times_5(v[7:4])+{14'd0,v[3:1]}+{16'd0,v[0]};
   decode_half=decimal_mode?(v==0?17'd5000:high_part+low_part):(v==0?17'd32768:({2'd0,v[15:1]}+{16'd0,v[0]}));
  end
 endfunction
 function automatic [15:0] dec_bcd(input [15:0] v);
  begin dec_bcd=v-1'b1;
   if(v[3:0]==0)begin dec_bcd[3:0]=9;dec_bcd[7:4]=v[7:4]-1'b1;
    if(v[7:4]==0)begin dec_bcd[7:4]=9;dec_bcd[11:8]=v[11:8]-1'b1;
     if(v[11:8]==0)begin dec_bcd[11:8]=9;dec_bcd[15:12]=v[15:12]==0?4'd9:v[15:12]-1'b1;end
    end
   end
  end
 endfunction
 // Decode each channel before the address mux so CPU address selection is not
 // on the BCD multiply/add path. Counter-load timing remains unchanged.
 wire [15:0] assembled_bus[0:2];wire [16:0] number_bus[0:2],half_bus[0:2];
 genvar channel;
 generate for(channel=0;channel<3;channel=channel+1)begin:input_decode
  assign assembled_bus[channel]=access_mode[channel]==1?{8'd0,din}:access_mode[channel]==2?{din,8'd0}:{din,low[channel]};
  assign number_bus[channel]=decode(assembled_bus[channel],bcd[channel]);
  assign half_bus[channel]=decode_half(assembled_bus[channel],bcd[channel]);
 end endgenerate
 reg [15:0] read_value;integer i;
 always @*begin
  dout=8'hff;
  if(address<3)begin
   read_value=latch_valid[address]?latched[address]:(bcd[address]?bcd_count[address]:count[address][15:0]);
   dout=(access_mode[address]==2||(access_mode[address]==3&&(latch_valid[address]?latch_high[address]:read_high[address])))?read_value[15:8]:read_value[7:0];
  end else read_value=0;
 end
 always @(posedge clk)begin
  old_gates<=gates;
  if(reset)begin
   bcd<=0;write_high<=0;read_high<=0;latch_valid<=0;latch_high<=0;running<=0;loaded<=0;old_gates<=0;pulse<=0;trigger_pending<=0;out<=0;
   for(i=0;i<3;i=i+1)begin mode[i]<=0;access_mode[i]<=3;reload_raw[i]<=0;reload_value[i]<=65536;count[i]<=0;half_count[i]<=0;bcd_count[i]<=0;latched[i]<=0;low[i]<=0;end
  end else begin
   for(i=0;i<3;i=i+1)begin
    if(trigger[i]&&loaded[i])trigger_pending[i]<=1;
    if(clocks[i]&&(trigger_pending[i]||trigger[i])&&loaded[i]&&(mode[i]==1||mode[i]==2||mode[i]==3||mode[i]==5))begin
     trigger_pending[i]<=0;
     count[i]<=reload_value[i];bcd_count[i]<=reload_raw[i];running[i]<=1;pulse[i]<=0;
     if(mode[i]==1)out[i]<=0;else out[i]<=1;
     half_count[i]<=(reload_value[i]+1'b1)>>1;
    end else if(!gates[i]&&(mode[i]==2||mode[i]==3))begin out[i]<=1;running[i]<=0;end
    else if(clocks[i]&&running[i]&&(gates[i]||mode[i]==1||mode[i]==5))begin
     if(mode[i]==3)begin
      if(half_count[i]<=1)begin out[i]<=!out[i];half_count[i]<=out[i]?(reload_value[i]>>1):((reload_value[i]+1'b1)>>1);count[i]<=reload_value[i];bcd_count[i]<=reload_raw[i];end
      else begin half_count[i]<=half_count[i]-1'b1;count[i]<=count[i]>2?count[i]-2:reload_value[i];bcd_count[i]<=dec_bcd(dec_bcd(bcd_count[i]));end
     end else if(pulse[i])begin
      out[i]<=1;pulse[i]<=0;
      if(mode[i]==2)begin count[i]<=reload_value[i]>1?reload_value[i]-1'b1:reload_value[i];bcd_count[i]<=dec_bcd(reload_raw[i]);end
      else running[i]<=0;
     end else if(count[i]<=1)begin
      count[i]<=0;bcd_count[i]<=0;
      if(mode[i]==2||mode[i]==4||mode[i]==5)begin out[i]<=0;pulse[i]<=1;end
      else begin out[i]<=1;running[i]<=0;end
     end else begin count[i]<=count[i]-1'b1;bcd_count[i]<=dec_bcd(bcd_count[i]);end
    end
   end
   if(rd&&address<3)begin
    if(latch_valid[address])begin
     if(access_mode[address]==3&&!latch_high[address])latch_high[address]<=1;
     else begin latch_valid[address]<=0;latch_high[address]<=0;end
    end else if(access_mode[address]==3)read_high[address]<=!read_high[address];
   end
   if(wr)begin
    if(address==3)begin
     if(din[7:6]<3)begin
      if(din[5:4]==0)begin
       if(!latch_valid[din[7:6]])begin latched[din[7:6]]<=bcd[din[7:6]]?bcd_count[din[7:6]]:count[din[7:6]][15:0];latch_valid[din[7:6]]<=1;latch_high[din[7:6]]<=0;end
      end else begin
       access_mode[din[7:6]]<=din[5:4];mode[din[7:6]]<=din[3:1]>=6?din[3:1]-4:din[3:1];bcd[din[7:6]]<=din[0];
       write_high[din[7:6]]<=0;read_high[din[7:6]]<=0;latch_valid[din[7:6]]<=0;running[din[7:6]]<=0;loaded[din[7:6]]<=0;trigger_pending[din[7:6]]<=0;out[din[7:6]]<=din[3:1]!=0;
      end
     end
    end else if(access_mode[address]==3&&!write_high[address])begin low[address]<=din;write_high[address]<=1;if(mode[address]==0)begin running[address]<=0;out[address]<=0;end end
    else begin
     reload_raw[address]<=assembled_bus[address];reload_value[address]<=number_bus[address];
     loaded[address]<=1;write_high[address]<=0;
     if(!loaded[address]||!running[address]||mode[address]==0||mode[address]==4)begin
      count[address]<=number_bus[address];bcd_count[address]<=assembled_bus[address];half_count[address]<=half_bus[address];pulse[address]<=0;
      running[address]<=mode[address]!=1&&mode[address]!=5;out[address]<=mode[address]!=0;
     end
    end
   end
  end
 end
endmodule
