// SPDX-License-Identifier: GPL-3.0-or-later
module rp_native_keyboard #(parameter PRAE=0)(input wire [511:0] pressed,output reg [63:0] matrix_n,output wire [2:0] modifiers_n);
 wire pc_shift=pressed[9'h012]||pressed[9'h059];
 assign modifiers_n=~{pressed[9'h058],pressed[9'h014]||pressed[9'h114],pressed[9'h012]||pressed[9'h059]};
 always @*begin matrix_n=64'hffffffffffffffff;
 if(PRAE)begin
 matrix_n[0]=!pressed[9'h016];
 matrix_n[8]=!pressed[9'h01e];
 matrix_n[16]=!pressed[9'h015];
 matrix_n[24]=!pressed[9'h01d];
 matrix_n[32]=!(pressed[9'h014]||pressed[9'h114]);
 matrix_n[40]=!pressed[9'h01c];
 matrix_n[48]=!pressed[9'h01a];
 matrix_n[56]=!(pressed[9'h012]||pressed[9'h059]);
 matrix_n[1]=!pressed[9'h026];
 matrix_n[9]=!pressed[9'h025];
 matrix_n[17]=!pressed[9'h024];
 matrix_n[25]=!pressed[9'h02d];
 matrix_n[33]=!pressed[9'h01b];
 matrix_n[41]=!pressed[9'h023];
 matrix_n[49]=!pressed[9'h021];
 matrix_n[57]=!pressed[9'h022];
 matrix_n[2]=!pressed[9'h02e];
 matrix_n[10]=!pressed[9'h036];
 matrix_n[18]=!pressed[9'h02c];
 matrix_n[26]=!pressed[9'h035];
 matrix_n[34]=!pressed[9'h02b];
 matrix_n[42]=!pressed[9'h034];
 matrix_n[50]=!pressed[9'h032];
 matrix_n[58]=!pressed[9'h02a];
 matrix_n[3]=!pressed[9'h03d];
 matrix_n[11]=!pressed[9'h03e];
 matrix_n[19]=!pressed[9'h03c];
 matrix_n[27]=!pressed[9'h043];
 matrix_n[35]=!pressed[9'h033];
 matrix_n[43]=!pressed[9'h03b];
 matrix_n[51]=!pressed[9'h03a];
 matrix_n[59]=!pressed[9'h031];
 matrix_n[4]=!pressed[9'h046];
 matrix_n[12]=!pressed[9'h045];
 matrix_n[20]=!pressed[9'h044];
 matrix_n[28]=!pressed[9'h04d];
 matrix_n[36]=!pressed[9'h042];
 matrix_n[44]=!pressed[9'h04b];
 matrix_n[52]=!pressed[9'h05a];
 matrix_n[60]=!pressed[9'h029];
 if(pressed[9'h052])begin matrix_n[56]=0;matrix_n[pc_shift?42:44]=0;end
 if(pressed[9'h055])begin matrix_n[56]=0;matrix_n[pc_shift?19:27]=0;end
 if(pressed[9'h04e])begin matrix_n[56]=0;matrix_n[pc_shift?26:26]=0;end
 if(pressed[9'h041])begin matrix_n[56]=0;matrix_n[pc_shift?35:36]=0;end
 if(pressed[9'h049])begin matrix_n[56]=0;matrix_n[pc_shift?43:51]=0;end
 if(pressed[9'h04a])begin matrix_n[56]=0;matrix_n[pc_shift?50:59]=0;end
 if(pressed[9'h04c])begin matrix_n[56]=0;matrix_n[pc_shift?20:28]=0;end
 if(pressed[9'h066])begin matrix_n[32]=0;matrix_n[35]=0;end
 if(pressed[9'h171])begin matrix_n[56]=0;matrix_n[12]=0;end
 if(pressed[9'h076])begin matrix_n[56]=0;matrix_n[17]=0;end
end else begin
 matrix_n[1]=!pressed[9'h016];
 matrix_n[2]=!pressed[9'h01e];
 matrix_n[3]=!pressed[9'h026];
 matrix_n[4]=!pressed[9'h025];
 matrix_n[5]=!pressed[9'h02e];
 matrix_n[6]=!pressed[9'h036];
 matrix_n[7]=!pressed[9'h03d];
 matrix_n[8]=!pressed[9'h03e];
 matrix_n[9]=!pressed[9'h046];
 matrix_n[10]=!pressed[9'h045];
 matrix_n[11]=!pressed[9'h04e];
 matrix_n[12]=!pressed[9'h055];
 matrix_n[13]=!pressed[9'h066];
 matrix_n[17]=!pressed[9'h015];
 matrix_n[18]=!pressed[9'h01d];
 matrix_n[19]=!pressed[9'h024];
 matrix_n[20]=!pressed[9'h02d];
 matrix_n[21]=!pressed[9'h02c];
 matrix_n[22]=!pressed[9'h035];
 matrix_n[23]=!pressed[9'h03c];
 matrix_n[24]=!pressed[9'h043];
 matrix_n[25]=!pressed[9'h044];
 matrix_n[26]=!pressed[9'h04d];
 matrix_n[27]=!pressed[9'h054];
 matrix_n[28]=!pressed[9'h05d];
 matrix_n[30]=!pressed[9'h171];
 matrix_n[32]=!pressed[9'h01c];
 matrix_n[33]=!pressed[9'h01b];
 matrix_n[34]=!pressed[9'h023];
 matrix_n[35]=!pressed[9'h02b];
 matrix_n[36]=!pressed[9'h034];
 matrix_n[37]=!pressed[9'h033];
 matrix_n[38]=!pressed[9'h03b];
 matrix_n[39]=!pressed[9'h042];
 matrix_n[40]=!pressed[9'h04b];
 matrix_n[41]=!pressed[9'h04c];
 matrix_n[42]=!pressed[9'h052];
 matrix_n[43]=!pressed[9'h076];
 matrix_n[44]=!pressed[9'h05a];
 matrix_n[48]=!pressed[9'h01a];
 matrix_n[49]=!pressed[9'h022];
 matrix_n[50]=!pressed[9'h021];
 matrix_n[51]=!pressed[9'h02a];
 matrix_n[52]=!pressed[9'h032];
 matrix_n[53]=!pressed[9'h031];
 matrix_n[54]=!pressed[9'h03a];
 matrix_n[55]=!pressed[9'h041];
 matrix_n[56]=!pressed[9'h049];
 matrix_n[57]=!pressed[9'h04a];
 matrix_n[59]=!pressed[9'h029];
 matrix_n[0]=!pressed[9'h00d];
end
 end
endmodule
