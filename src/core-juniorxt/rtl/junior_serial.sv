// SPDX-License-Identifier: GPL-3.0-or-later
// JUNIOR-XT 703.910.050 asynchronous serial adapter (schematic sheets 17-19).
// 250/252: A/B data; 251/253: A/B control; 254-257: baud 8253;
// 258-25B: Z80 interrupt acknowledge; 25C-25F: DSR A in bit 0.
module junior_serial # (parameter integer CLOCK_HZ=50000000)(
 input clk,reset,selected, input [3:0] address, input read_n,write_n,
 input [7:0] din,output reg [7:0] dout,output irq,
 input [1:0] rx,cts_n,dcd_n,dsr_n,output [1:0] tx,rts_n,dtr_n);
 reg prev_rd=1,prev_wr=1;reg [7:0] write_data=0;
 always @(posedge clk)if(selected && !write_n)write_data<=din;
 wire rd=selected && read_n && !prev_rd;
 wire wr=selected && write_n && !prev_wr;
 always @(posedge clk) begin prev_rd<=read_n;prev_wr<=write_n;end
 // The crystal is divided by 10 by U5 (7490) before the 8253, sheet 17.
 reg [26:0] osc_phase=0;
 reg baud_ref=0;
 always @(posedge clk) begin
  if(reset)begin osc_phase<=0;baud_ref<=0;end
  else if(osc_phase>=CLOCK_HZ-3686400)begin osc_phase<=osc_phase+3686400-CLOCK_HZ;baud_ref<=~baud_ref;end
  else osc_phase<=osc_phase+3686400;
 end
 wire [7:0] pit_data;
 wire [1:0] pit_out;
 KF8253 baud_timer(.clock(clk),.reset(reset),.chip_select_n(~(selected && address[3:2]==1)),
  .read_enable_n(read_n),.write_enable_n(write_n),.address(address[1:0]),.data_bus_in(din),.data_bus_out(pit_data),
  .counter_0_clock(baud_ref),.counter_1_clock(baud_ref),.counter_2_clock(baud_ref),
  .counter_0_gate(1'b1),.counter_1_gate(1'b1),.counter_2_gate(1'b1),
  .counter_0_out(pit_out[0]),.counter_1_out(pit_out[1]),.counter_2_out());
 reg [1:0] pit_prev=0;
 always @(posedge clk)pit_prev<=pit_out;
 wire [1:0] baud_ce=pit_out & ~pit_prev;
 wire [7:0] a_data,b_data,a_vector,b_vector;
 wire [2:0] a_pending,b_pending;
 wire a_reti,b_reti,a_reset,b_reset;
 wire [1:0] rx_special;
 reg [5:0] in_service=0;
 wire [5:0] pending={b_pending[0],b_pending[1],b_pending[2],a_pending[0],a_pending[1],a_pending[2]};
 // Priority: A receive, A transmit, A external, B receive, B transmit, B external.
 integer i; reg [2:0] winner;reg found;
 always @* begin
  winner=7;found=0;
  for(integer j=0;j<6;j=j+1)begin
   if(!found)begin
    if(in_service[j])found=1;
    else if(pending[j])begin winner=j;found=1;end
   end
  end
 end
 assign irq=winner!=7;
 reg [2:0] code;
 always @*begin
  case(winner)
   0:code=rx_special[0]?7:6;1:code=4;2:code=5;
   3:code=rx_special[1]?3:2;4:code=0;5:code=1;default:code=3;
  endcase
 end
 wire [7:0] irq_vector = b_status_vector ? {b_vector[7:4],code,b_vector[0]} : b_vector;
 wire b_status_vector;
 always @(posedge clk) begin
  if(reset)in_service<=0;
  else if(a_reti||b_reti)begin
   reg done;done=0;
   for(integer j=0;j<6;j=j+1)if(!done && in_service[j])begin in_service[j]<=0;done=1;end
  end else if(rd && address[3:2]==2 && winner!=7)in_service[winner]<=1;
  if(a_reset)in_service[2:0]<=0;
  if(b_reset)in_service[5:3]<=0;
 end
 junior_sio_channel #(.CHANNEL_A(1)) channel_a(
  .clk(clk),.reset(reset),.baud_ce(baud_ce[0]),.read_strobe(rd && address[3:1]==0),
  .write_strobe(wr && address[3:1]==0),.control(address[0]),.din(write_data),.dout(a_data),
  .rx(rx[0]),.tx(tx[0]),.cts_n(cts_n[0]),.dcd_n(dcd_n[0]),.rts_n(rts_n[0]),.dtr_n(dtr_n[0]),
  .pending(a_pending),.any_pending(|pending),.irq_vector(irq_vector),.vector(a_vector),
  .status_vector(),.reti(a_reti),.channel_reset(a_reset),.rx_special(rx_special[0]));
 junior_sio_channel channel_b(
  .clk(clk),.reset(reset),.baud_ce(baud_ce[1]),.read_strobe(rd && address[3:1]==1),
  .write_strobe(wr && address[3:1]==1),.control(address[0]),.din(write_data),.dout(b_data),
  .rx(rx[1]),.tx(tx[1]),.cts_n(cts_n[1]),.dcd_n(dcd_n[1]),.rts_n(rts_n[1]),.dtr_n(dtr_n[1]),
  .pending(b_pending),.any_pending(|pending),.irq_vector(irq_vector),.vector(b_vector),
  .status_vector(b_status_vector),.reti(b_reti),.channel_reset(b_reset),.rx_special(rx_special[1]));
 always @*begin
  case(address[3:2])
   0:dout=address[1]?b_data:a_data;
   1:dout=pit_data;
   2:dout=irq_vector;
   3:dout={7'b0,~dsr_n[0]};
  endcase
 end
endmodule

// Register and asynchronous line engine for one Z80-SIO channel.
// WR0-7, RR0-2, 3-byte RX FIFO with per-character errors, double-buffered TX,
// x1/x16/x32/x64 clocks, 5/6/7/8 bits, parity, 1/1.5/2 stops, break and IRQs.
module junior_sio_channel #(parameter CHANNEL_A=0)(
 input clk,reset,baud_ce,read_strobe,write_strobe,control,input [7:0] din,
 output reg [7:0] dout,input rx,cts_n,dcd_n,output tx,rts_n,dtr_n,
 output [2:0] pending,input any_pending,input [7:0] irq_vector,
 output [7:0] vector,output status_vector,output reti,channel_reset,rx_special);
 reg [7:0] wr[0:7]; reg [2:0] ptr=0;
 reg [1:0] rx_sync=3,cts_sync=3,dcd_sync=3;
 reg cts_prev=1,dcd_prev=1;
 always @(posedge clk) begin rx_sync<={rx_sync[0],rx};cts_sync<={cts_sync[0],cts_n};dcd_sync<={dcd_sync[0],dcd_n};cts_prev<=cts_sync[1];dcd_prev<=dcd_sync[1];end
 wire cmd=write_strobe && control && ptr==0;
 assign channel_reset=cmd && din[5:3]==3;
 assign reti=cmd && din[5:3]==7;
 wire reset_ext=cmd && din[5:3]==2;
 wire reset_tx=cmd && din[5:3]==5;
 wire reset_error=cmd && din[5:3]==6;
 wire int_next=cmd && din[5:3]==4;
 wire clr=reset||channel_reset;
 assign vector=wr[2];assign status_vector=wr[1][2];
 assign dtr_n=~wr[5][7];
 assign rts_n=~wr[5][1];
 wire [6:0] divisor=wr[4][7:6]==0?7'd1:wr[4][7:6]==1?7'd16:wr[4][7:6]==2?7'd32:7'd64;
 function automatic [3:0] bits_per_char(input [1:0] v);
  case(v)0:bits_per_char=5;1:bits_per_char=7;2:bits_per_char=6;3:bits_per_char=8;endcase
 endfunction
 wire [3:0] tx_bits=bits_per_char(wr[5][6:5]);
 wire [3:0] rx_bits=bits_per_char(wr[3][7:6]);
 reg [7:0] tx_buf=0;
 reg tx_full=0,tx_active=0;
 reg [11:0] tx_shift=12'hfff;
 reg [3:0] tx_left=0;
 reg [7:0] tx_count=0;
 reg tx_ip=0,ext_ip=0,rx_first_armed=1;
 reg [7:0] rx_fifo[0:2];reg [2:0] err_fifo[0:2];
 reg [1:0] rx_head=0,rx_tail=0,rx_used=0;
 reg overrun=0,break_latch=0;
 reg rx_active=0;reg [3:0] rx_pos=0;reg [7:0] rx_shift=0;reg [7:0] rx_count=0;reg rx_parity=0;
 reg rx_pe=0;
 wire pop=read_strobe && !control && rx_used!=0;
 wire take_tx=write_strobe && !control;
 wire rx_enabled=wr[3][0] && (!wr[3][5] || !dcd_sync[1]);
 wire tx_enabled=wr[5][3] && (!wr[3][5] || !cts_sync[1]);
 wire rx_end=baud_ce && rx_active && rx_count==0 && rx_pos==rx_bits+1+wr[4][0];
 wire [7:0] rx_mask=(9'd1<<rx_bits)-1;
 wire rx_push=rx_end;
 wire [2:0] rx_err={~rx_sync[1],1'b0,rx_pe};
 assign rx_special=overrun || (rx_used!=0 && |err_fifo[rx_head]);
 assign pending[2]=wr[1][4:3]!=0 && rx_used!=0 && (wr[1][4] || rx_first_armed || rx_special);
 assign pending[1]=wr[1][1] && tx_ip;
 assign pending[0]=wr[1][0] && ext_ip;
 assign tx=wr[5][4]?1'b0:(tx_active?tx_shift[0]:1'b1);
 always @* begin
  if(!control)dout=rx_used!=0?rx_fifo[rx_head]:8'h00;
  else case(ptr)
   0:dout={break_latch,1'b0,~cts_sync[1],1'b0,~dcd_sync[1],~tx_full,(CHANNEL_A?any_pending:1'b0),(rx_used!=0)};
   1:dout={1'b0,(rx_used!=0?err_fifo[rx_head][2]:1'b0),overrun,(rx_used!=0?err_fifo[rx_head][0]:1'b0),3'b000,(~tx_full && !tx_active)};
   2:dout=irq_vector;
   default:dout=8'h00;
  endcase
 end
 always @(posedge clk)begin
  if(clr)begin
   for(integer k=0;k<8;k=k+1)wr[k]<=0;
   ptr<=0;tx_full<=0;tx_active<=0;tx_shift<=12'hfff;tx_left<=0;tx_count<=0;
   tx_ip<=0;ext_ip<=0;rx_first_armed<=1;rx_head<=0;rx_tail<=0;rx_used<=0;
   overrun<=0;break_latch<=0;rx_active<=0;rx_count<=0;rx_pos<=0;rx_pe<=0;rx_parity<=0;
  end else begin
   if(write_strobe && control)begin
    if(ptr!=0)begin wr[ptr]<=din;ptr<=0;end
    else begin wr[0]<=din;ptr<=din[2:0];end
   end
   if(read_strobe && control)ptr<=0;
   if(reset_ext)begin ext_ip<=0;break_latch<=0;end
   if(reset_tx)tx_ip<=0;
   if(reset_error)begin overrun<=0;if(rx_used!=0)err_fifo[rx_head]<=0;end
   if(int_next)rx_first_armed<=1;
   if(wr[1][0] && ((cts_sync[1]!=cts_prev)||(dcd_sync[1]!=dcd_prev)))ext_ip<=1;
   if(pop)begin rx_head<=rx_head==2?0:rx_head+1'b1;rx_first_armed<=0;end
   if(rx_push)begin
    if(rx_used<3 || pop)begin
     rx_fifo[rx_tail]<=rx_shift&rx_mask;err_fifo[rx_tail]<=rx_err;rx_tail<=rx_tail==2?0:rx_tail+1'b1;
    end else overrun<=1;
    if(!rx_sync[1] && rx_shift==0)begin break_latch<=1;ext_ip<=1;end
   end
   case({(rx_push && (rx_used<3||pop)),pop})
    2'b10:rx_used<=rx_used+1'b1;2'b01:rx_used<=rx_used-1'b1;default:;
   endcase
   if(take_tx)begin tx_buf<=din;tx_full<=1;tx_ip<=0;end
   if(baud_ce)begin
    if(!tx_active && tx_full && tx_enabled)begin
     reg [11:0] frame;reg parity;
     frame=12'hfff;frame[0]=0;parity=~wr[4][1];
     for(integer k=0;k<8;k=k+1)if(k<tx_bits)begin frame[k+1]=tx_buf[k];parity=parity^tx_buf[k];end
     if(wr[4][0])frame[tx_bits+1]=parity;
     tx_shift<=frame;tx_left<=tx_bits+2+wr[4][0];tx_count<=divisor-1'b1;
     tx_active<=1;tx_full<=take_tx;tx_ip<=!take_tx;
    end else if(tx_active)begin
     if(tx_count!=0)tx_count<=tx_count-1'b1;
     else if(tx_left==1)begin tx_active<=0;tx_shift<=12'hfff;end
     else begin
      tx_shift<={1'b1,tx_shift[11:1]};tx_left<=tx_left-1'b1;
      // Final stop interval can be 1, 1.5 or 2 bit times.
      if(tx_left==2 && wr[4][3:2]==2)tx_count<=divisor+(divisor>>1)-1'b1;
      else if(tx_left==2 && wr[4][3:2]==3)tx_count<={divisor,1'b0}-1'b1;
      else tx_count<=divisor-1'b1;
     end
    end
    if(!rx_active && rx_enabled && !rx_sync[1])begin
     rx_active<=1;rx_pos<=0;rx_count<=divisor>1?(divisor>>1)-1'b1:0;rx_pe<=0;rx_parity<=0;
    end else if(rx_active)begin
     if(!rx_enabled)rx_active<=0;
     else if(rx_count!=0)rx_count<=rx_count-1'b1;
     else begin
      rx_count<=divisor-1'b1;rx_pos<=rx_pos+1'b1;
      if(rx_pos==0)begin
       if(rx_sync[1])rx_active<=0;
      end else if(rx_pos<=rx_bits)begin
       rx_shift[rx_pos-1'b1]<=rx_sync[1];rx_parity<=rx_parity^rx_sync[1];
      end else if(wr[4][0] && rx_pos==rx_bits+1)rx_pe<=rx_sync[1]!=(rx_parity^~wr[4][1]);
      else rx_active<=0;
     end
    end
   end
  end
 end
endmodule
