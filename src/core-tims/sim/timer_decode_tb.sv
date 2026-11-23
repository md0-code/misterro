// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
module timer_decode_tb;
 rp_i8253 dut(.clk(1'b0),.reset(1'b1),.wr(1'b0),.rd(1'b0),.address(2'd0),.din(8'd0),.clocks(3'd0),.gates(3'd0),.dout(),.out());
 integer value,expected_binary,expected_decimal;
 initial begin
  for(value=0;value<65536;value=value+1)begin
   expected_binary=value==0?65536:value;
   expected_decimal=value==0?10000:((value>>12)&15)*1000+((value>>8)&15)*100+((value>>4)&15)*10+(value&15);
   if(dut.decode(value,0)!=expected_binary||dut.decode(value,1)!=expected_decimal)$fatal(1,"8253 decoder mismatch %h",value);
   if(dut.decode_half(value,0)!=(expected_binary+1)/2||dut.decode_half(value,1)!=(expected_decimal+1)/2)$fatal(1,"8253 half-period mismatch %h",value);
  end
  $display("PASS all 65536 binary and BCD reload values and rounded half-periods");$finish;
 end
endmodule
