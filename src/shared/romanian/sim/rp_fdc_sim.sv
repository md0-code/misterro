// SPDX-License-Identifier: GPL-3.0-or-later
module rp_fdc_sim(input wire clk,reset,tc,a0,nRD,nWR,input wire [7:0] din,output wire [7:0] dout,
 input wire [3:0] drive_8inch,input wire [3:0] img_mounted,input wire img_wp,input wire [31:0] img_size,
 output wire [31:0] sd_lba,output wire [3:0] sd_rd,sd_wr,input wire sd_ack,
 input wire [8:0] sd_buff_addr,input wire [7:0] sd_buff_dout,output wire [7:0] sd_buff_din,input wire sd_buff_wr);
 rp_u765 #(.CYCLES(20)) dut(.clk_sys(clk),.ce(1'b1),.reset(reset),.tc(tc),.drq(),.irq(),.ready(4'b1111),.motor(4'b1111),.available(4'b1111),.drive_8inch(drive_8inch),.fast(1'b1),
 .a0(a0),.nRD(nRD),.nWR(nWR),.din(din),.dout(dout),.img_mounted(img_mounted),.img_wp(img_wp),.img_size(img_size),
 .sd_lba(sd_lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(sd_ack),.sd_buff_addr(sd_buff_addr),.sd_buff_dout(sd_buff_dout),.sd_buff_din(sd_buff_din),.sd_buff_wr(sd_buff_wr));
endmodule
