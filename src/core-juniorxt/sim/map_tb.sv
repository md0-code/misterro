`timescale 1ns/1ps
module map_tb;
 import sdram_pkg::*;
 reg [19:0] address;wire selected,protect,phys2_valid;wire [24:0] phys,phys2;wire [1:0] vclass;
 reg winchester=0;reg [3:0] blocks=4'd10;
 logic [6:0] banks[0:3];
 mem_map dut(.address(address),.map_ems(banks),.ems_b1(1'b0),.ems_b2(1'b0),.ems_b3(1'b0),.ems_b4(1'b0),.enable_a000h(winchester),.bios_protect_flag(2'b11),.ec00_loaded(1'b0),.en_cga(1'b1),.en_hgc(1'b0),.hgc_page(1'b0),.tandy_video(1'b0),.tandy_block(3'd0),.tandy_cpu_page(3'd0),.pcjr(1'b0),.pcjr_32k(1'b0),.pcjr_ram_size(blocks),.cart1_seg(8'd0),.cart1_len(17'd0),.cart2_seg(8'd0),.cart2_len(17'd0),.select(selected),.phys(phys),.protect(protect),.vclass(vclass),.phys2(phys2),.phys2_valid(phys2_valid));
 task check(input [19:0] a,input sel,input [24:0] p,input ro,input [1:0] cls);
 begin address=a;#1;if(selected!==sel || (sel && (phys!==p||protect!==ro||vclass!==cls||phys2_valid)))$fatal(1,"bad Junior memory decode %05x -> %07x sel=%b protect=%b class=%d",a,phys,selected,protect,vclass);end endtask
 initial begin
 for(integer i=0;i<4;i++)banks[i]=0;
 check(20'h00000,1,25'h0000000,0,0);check(20'h3ffff,1,25'h003ffff,0,0);
 check(20'h40000,1,25'h0040000,0,0);check(20'h9ffff,1,25'h009ffff,0,0);
 check(20'ha0000,0,0,0,0);check(20'haffff,0,0,0,0);check(20'hb0000,0,0,0,0);check(20'hb7fff,0,0,0,0);
 check(20'hb8000,1,25'h0850000,0,1);check(20'hbbfff,1,25'h0853fff,0,1);
 check(20'hbc000,1,25'h0854000,0,1);check(20'hbffff,1,25'h0857fff,0,1);
 check(20'hc0000,0,0,0,0);check(20'hd0000,0,0,0,0);check(20'hec000,0,0,0,0);check(20'heffff,0,0,0,0);
 check(20'hf0000,1,25'h0100000,1,0);check(20'hfffff,1,25'h010ffff,1,0);
 check(20'hc8000,0,0,0,0);winchester=1;check(20'hc8000,1,25'h0110000,1,0);check(20'hcbfff,1,25'h0113fff,1,0);check(20'hcc000,0,0,0,0);
 blocks=4'd4;check(20'h3ffff,1,25'h003ffff,0,0);check(20'h40000,0,0,0,0);
 $display("RESULT: PASS Junior 640K RAM, true 32K CGA, empty expansion windows, C8000 socket, 256K limit and ROM protection");$finish;
 end
endmodule
