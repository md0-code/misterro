// SPDX-License-Identifier: GPL-3.0-or-later
// Persistent raw printer jobs on a mounted .PRN image. Sector zero commits byte count.
module rp_printer_spool #(parameter CLOCK_HZ=56000000)(input wire clk,reset,push,input wire [7:0] data,input wire flush,
 input wire mounted,write_protect,input wire [31:0] image_bytes,output wire busy,output reg overflow=0,
 output wire [31:0] lba,output reg sd_wr=0,input wire sd_ack,input wire [8:0] buffer_address,output wire [7:0] buffer_data,
 output reg [31:0] length=0);
 (* ramstyle="M10K, no_rw_check" *) reg [7:0] bytes[0:511];
 reg [7:0] ram_q=0,header_q=0;assign buffer_data=header?header_q:ram_q;
 reg [3:0] state=0;reg present=0,old_mount=0,old_flush=0,dirty=0,header=0,full_block=0;
 reg [9:0] used=0,clear_index=0;reg [31:0] block=0,capacity=0;reg [26:0] idle_count=0;
 wire commit=(flush&&!old_flush)||(dirty&&idle_count>=CLOCK_HZ/10)||used==512;
 assign busy=!present||state!=1||length>=capacity;
 assign lba=header?32'd0:block+1'b1;
 function automatic [7:0] header_byte(input [8:0] a);
  begin
   case(a)
    0:header_byte="M";1:header_byte="i";2:header_byte="S";3:header_byte="T";4:header_byte="e";5:header_byte="r";
    6:header_byte="-";7:header_byte="P";8:header_byte="R";9:header_byte="N";10:header_byte="-";11:header_byte="v";12:header_byte="1";13:header_byte=10;
    32:header_byte=length[7:0];33:header_byte=length[15:8];34:header_byte=length[23:16];35:header_byte=length[31:24];36:header_byte={7'd0,overflow};
    default:header_byte=0;
   endcase
  end
 endfunction
 always @(posedge clk)begin
  ram_q<=bytes[buffer_address];header_q<=header_byte(buffer_address);
  old_mount<=mounted;old_flush<=flush;
  if(reset)begin state<=0;present<=0;sd_wr<=0;used<=0;length<=0;block<=0;overflow<=0;dirty<=0;idle_count<=0;end
  else if(mounted&&!old_mount)begin
   present<=!write_protect&&image_bytes>=1024;capacity<={image_bytes[31:9],9'd0}-512;
   state<=0;clear_index<=0;used<=0;length<=0;block<=0;dirty<=0;overflow<=0;sd_wr<=0;idle_count<=0;
  end else begin
   if(push&&busy)overflow<=1;
   if(dirty&&idle_count<CLOCK_HZ/10)idle_count<=idle_count+1'b1;
   case(state)
    0:begin bytes[clear_index[8:0]]<=0;if(clear_index==511)begin clear_index<=0;state<=1;end else clear_index<=clear_index+1'b1;end
    1:begin
     if(commit&&dirty&&!push)begin header<=0;full_block<=used==512;sd_wr<=1;state<=2;end
     else if(push&&!busy)begin bytes[used[8:0]]<=data;used<=used+1'b1;length<=length+1'b1;dirty<=1;idle_count<=0;end
    end
    2:if(sd_ack)begin sd_wr<=0;state<=3;end
    3:if(!sd_ack)begin header<=1;state<=6;end
    6:begin sd_wr<=1;state<=4;end
    4:if(sd_ack)begin sd_wr<=0;state<=5;end
    5:if(!sd_ack)begin
     header<=0;dirty<=0;idle_count<=0;
     if(full_block)begin block<=block+1'b1;used<=0;clear_index<=0;state<=0;end else state<=1;
    end
    default:state<=0;
   endcase
  end
 end
endmodule
