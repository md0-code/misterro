// SPDX-License-Identifier: GPL-3.0-or-later
// CIP-04 printer and serial ports, as its firmware drives them (+3 system ROMs):
//   0FFD write: printer data; 0FFD read bit 0: printer busy; 1FFD bit 4: strobe, active low.
//   AY register 14: bit 3 serial TXD, bit 2 CTS out, bit 7 RXD in, bit 6 DTR in.
// On MiSTer's UART pins: the serial port as it is, or each printed byte at 115200 8N1.
module cip04_ports #(parameter DIVIDER=972)(
 input wire clk,reset,enable,input wire [15:0] addr,input wire [7:0] din,input wire io_wr,psg_we,strobe_n,
 input wire printer_mode,uart_rxd,uart_cts,output wire uart_txd,uart_rts,
 output wire printer_sel,printer_busy,ay14_sel,output wire [7:0] ay14_in);
 assign printer_sel=enable && !addr[1] && addr[15:12]==0;
 reg [7:0] data,r14;reg [3:0] select;reg old_strobe;
 reg [9:0] frame;reg [3:0] left;reg [9:0] count;
 wire sending=left!=0;
 always @(posedge clk)begin
  old_strobe<=strobe_n;
  if(reset)begin data<=0;r14<=8'hff;select<=0;frame<=10'h3ff;left<=0;count<=0;old_strobe<=1;end
  else begin
   if(io_wr && printer_sel)data<=din;
   if(enable && psg_we)begin if(addr[14])select<=din[3:0];else if(select==14)r14<=din;end
   if(sending)begin
    if(count!=0)count<=count-1'b1;
    else begin frame<={1'b1,frame[9:1]};left<=left-1'b1;count<=DIVIDER-1;end
   end else if(printer_mode && old_strobe && !strobe_n)begin frame<={1'b1,data,1'b0};left<=10;count<=DIVIDER-1;end
  end
 end
 assign printer_busy=!printer_mode || sending;
 assign uart_txd=printer_mode?frame[0]:r14[3];
 assign uart_rts=printer_mode?1'b0:r14[2];
 assign ay14_sel=enable && select==14;
 assign ay14_in={printer_mode?1'b1:uart_rxd,printer_mode?1'b0:uart_cts,r14[5:0]};
endmodule
