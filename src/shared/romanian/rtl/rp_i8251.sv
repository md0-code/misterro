// SPDX-License-Identifier: GPL-3.0-or-later
// Intel 8251: asynchronous x1/x16/x64 and internal/external synchronous operation.
module rp_i8251(input wire clk,reset,wr,rd,command_port,input wire [7:0] din,input wire txc,rxc,rx,cts_n,dsr_n,
 input tri0 external_sync,output wire [7:0] dout,output reg tx=1,output wire rts_n,dtr_n,tx_ready,rx_ready,tx_empty,sync_detect);
 reg [7:0] mode=0,command=0,rx_data=0,tx_data=0,sync1=0,sync2=0;
 reg [1:0] programming=0;
 reg rx_full=0,tx_full=0,pe=0,oe=0,fe=0,detected=0,brk=0,hunting=0,sync_toggle=0;
 reg [17:0] tx_shift=18'h3ffff,hunt_shift=0;reg [4:0] tx_left=0;
 reg [7:0] tx_div=0;reg [3:0] rx_state=0,rx_bit=0;reg [6:0] rx_div=0;
 reg [7:0] rx_shift=0;reg rx_parity=0;
 wire synchronous=mode[1:0]==0;
 wire [6:0] factor=mode[1:0]==2 ? 7'd16:mode[1:0]==3 ? 7'd64:7'd1;
 wire [3:0] length=4'd5+{2'd0,mode[3:2]};
 wire parity=mode[4],even=mode[5];wire [7:0] mask=8'hff>>(8-length);
 assign tx_empty=tx_left==0&&!tx_full;
 assign tx_ready=!tx_full&&command[0]&&!cts_n;
 assign rx_ready=rx_full&&command[2];
 assign rts_n=!command[5];assign dtr_n=!command[1];assign sync_detect=synchronous?detected:brk;
 assign dout=command_port?{!dsr_n,sync_detect,fe,oe,pe,tx_empty,rx_ready,tx_ready}:rx_data;
 function automatic [17:0] sync_frame(input [7:0] data);
  reg [17:0] value;
  begin value={10'd0,data&mask};if(parity)value[length]=((^(data&mask))^!even);sync_frame=value;end
 endfunction
 wire [4:0] sync_bits=length+parity;
 wire [5:0] hunt_bits=mode[7]?{1'b0,sync_bits}:{sync_bits,1'b0};
 wire [17:0] hunt_mask=18'h3ffff>>(18-hunt_bits);
 wire [17:0] hunt_target=mode[7]?sync_frame(sync1):(sync_frame(sync1)|(sync_frame(sync2)<<sync_bits));
 wire [17:0] hunt_next=(hunt_shift>>1)|({17'd0,rx}<<(hunt_bits-1'b1));
 reg [17:0] frame;reg [4:0] total_bits;integer i;
 always @(posedge clk)begin
  if(reset)begin
   mode<=0;command<=0;programming<=0;rx_full<=0;tx_full<=0;tx_left<=0;tx<=1;pe<=0;oe<=0;fe<=0;rx_state<=0;tx_div<=0;rx_div<=0;detected<=0;hunting<=0;brk<=0;sync_toggle<=0;
  end else begin
   if(rd&&!command_port)rx_full<=0;
   if(rx)brk<=0;
   if(wr)begin
    if(command_port)case(programming)
     0:begin mode<=din;programming<=din[1:0]==0&&!din[6]?1:3;end
     1:begin sync1<=din;programming<=mode[7]?3:2;end
     2:begin sync2<=din;programming<=3;end
     3:if(din[6])begin programming<=0;command<=0;rx_full<=0;tx_full<=0;tx_left<=0;tx<=1;rx_state<=0;detected<=0;hunting<=0;end
       else begin command<=din;if(din[4])begin pe<=0;oe<=0;fe<=0;end
        if(din[7]&&synchronous)begin hunting<=1;detected<=0;rx_bit<=0;hunt_shift<=0;end
       end
    endcase
    else if(!tx_full)begin tx_data<=din;tx_full<=1;end
   end
   if(txc)begin
    if(command[3]&&!synchronous)tx<=0;
    else if(tx_left==0||(synchronous&&tx_left==1&&tx_div==0))begin
     tx<=1;
     if(command[0]&&!cts_n&&(tx_full||synchronous))begin
      if(synchronous)begin
       frame=sync_frame(tx_full?tx_data:(sync_toggle?sync2:sync1));total_bits=length+parity;
       if(!tx_full)sync_toggle<=!mode[7]&&!sync_toggle;else sync_toggle<=0;
      end else begin
       frame=18'h3ffff;frame[0]=0;
       for(i=0;i<8;i=i+1)if(i<length)frame[i+1]=tx_data[i];
       if(parity)frame[length+1]=((^(tx_data&mask))^!even);
       total_bits=1+length+parity+(mode[7:6]==3 ? 2:1);
      end
      tx<=frame[0];tx_shift<={1'b1,frame[17:1]};tx_left<=total_bits;tx_div<=factor-1'b1;tx_full<=0;
     end else begin tx_left<=0;tx_div<=0;end
    end else if(tx_div!=0)tx_div<=tx_div-1'b1;
    else if(tx_left==1)begin
     // A 1.5-stop frame adds half a bit to the already transmitted stop bit.
     if(!synchronous&&mode[7:6]==2&&tx_shift[17]==0)begin tx_div<=(factor>1 ? (factor>>1)-1'b1:0);tx_shift[17]<=1;end
     else begin tx_left<=0;tx<=1;end
    end else begin
     tx<=tx_shift[0];tx_shift<={1'b1,tx_shift[17:1]};tx_left<=tx_left-1'b1;tx_div<=factor-1'b1;
     if(!synchronous&&mode[7:6]==2&&tx_left==2)tx_shift[17]<=0;
    end
   end
   if(rxc&&command[2])begin
    if(synchronous)begin
     if(hunting)begin
      hunt_shift<=hunt_next;
      if(mode[6]?external_sync:((hunt_next&hunt_mask)==(hunt_target&hunt_mask)))begin hunting<=0;detected<=1;rx_bit<=0;rx_shift<=0;rx_parity<=0;end
     end else if(rx_bit<length)begin rx_shift[rx_bit]<=rx;rx_parity<=rx_parity^rx;
      if(rx_bit==length-1&&!parity)begin if(rx_full)oe<=1;else begin rx_data<=(rx_shift&mask&~(8'd1<<rx_bit))|({7'd0,rx}<<rx_bit);rx_full<=1;end rx_bit<=0;rx_parity<=0;end
      else rx_bit<=rx_bit+1'b1;
     end else begin
      if(rx!=(rx_parity^!even))pe<=1;if(rx_full)oe<=1;else begin rx_data<=rx_shift&mask;rx_full<=1;end rx_bit<=0;rx_parity<=0;
     end
    end else if(rx_state==0)begin
     if(!rx)begin rx_state<=factor==1?2:1;rx_div<=factor==1?0:(factor>>1)-1'b1;rx_bit<=0;rx_shift<=0;rx_parity<=0;end
    end else if(rx_div!=0)rx_div<=rx_div-1'b1;
    else begin
     rx_div<=factor-1'b1;
     case(rx_state)
      1:if(!rx)begin rx_state<=2;rx_bit<=0;rx_shift<=0;rx_parity<=0;end else rx_state<=0;
      2:begin rx_shift[rx_bit]<=rx;rx_parity<=rx_parity^rx;if(rx_bit==length-1)rx_state<=parity?3:4;else rx_bit<=rx_bit+1'b1;end
      3:begin if(rx!=(rx_parity^!even))pe<=1;rx_state<=4;end
      4:begin if(!rx)begin fe<=1;if((rx_shift&mask)==0)brk<=1;end if(rx_full)oe<=1;else begin rx_data<=rx_shift&mask;rx_full<=1;end rx_state<=0;end
      default:rx_state<=0;
     endcase
    end
   end
  end
 end
endmodule
