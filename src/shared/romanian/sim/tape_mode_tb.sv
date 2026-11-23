// SPDX-License-Identifier: GPL-3.0-or-later
module tape_mode_tb #(parameter MODE48=1);
 reg clk=0,reset=1,download=0,wr=0;reg [26:0] address=0;reg [7:0] data=0;
 reg [3:0] phase=0;wire audio;reg old_audio=0,count_edges=0;integer edges=0,i;
 reg [7:0] image[0:25]='{8'h5a,8'h58,8'h54,8'h61,8'h70,8'h65,8'h21,8'h1a,8'h01,8'h14,
  8'h2a,0,0,0,0,8'h20,8'h64,0,8'h12,8'hd0,8'h07,8'h08,0,8'h20,0,0};
 always #5 clk=~clk;
 always @(posedge clk)begin phase<=phase+1'b1;old_audio<=audio;if(!reset && count_edges && old_audio!=audio)edges<=edges+1;end
 rp_tape #(.ADDR_BITS(8)) dut(.clk(clk),.reset(reset),.ce(phase==15),.mode48k(MODE48!=0),
 .download(download),.wr(wr),.address(address),.data(data),.mode(2'd2),.pause(1'b0),.prev(1'b0),.next(1'b0),.audio(audio),.active(),.available(),.overflow());
 initial begin
  repeat(4)@(negedge clk);reset=0;download=1;repeat(3)@(negedge clk);
  for(i=0;i<26;i=i+1)begin wr=1;address=i;data=image[i];@(negedge clk);end
  wr=0;download=0;repeat(4480000)@(negedge clk);count_edges=1;repeat(10000000)@(negedge clk);
  if(MODE48 && edges!=0)$fatal(1,"48K mode ignored TZX stop48");
  if(!MODE48 && edges<6)$fatal(1,"128K mode incorrectly stopped TZX playback");
  $display("PASS: TZX stop48 honors mode %0d (audio edges %0d)",MODE48,edges);$finish;
 end
endmodule
