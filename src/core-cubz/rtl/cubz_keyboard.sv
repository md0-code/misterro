// SPDX-License-Identifier: GPL-3.0-or-later
// PS/2 to the original nine-interrogation, open-collector keyboard link.
module cubz_keyboard #(parameter SYS_HZ=40000000)(input wire clk,reset,input wire [10:0] ps2_key,
 input wire interrogate,output wire data_in,clock_in,output reg overflow);
 reg old_event,shift_l,shift_r,ctrl,caps,old_interrogate;
 reg [7:0] fifo[0:31]; reg [5:0] wp,rp;
 reg [3:0] bitpos;reg [7:0] serial;reg response;
 reg [12:0] busy;
 reg repeating,caps_pressed;reg [8:0] repeat_scan;reg [7:0] repeat_char;reg [24:0] repeat_count;
 wire shift=shift_l|shift_r;
 reg [7:0] keycode;
 always @* begin
  keycode=0;
  case(ps2_key[7:0])
   8'h1c:keycode="a";8'h32:keycode="b";8'h21:keycode="c";8'h23:keycode="d";
   8'h24:keycode="e";8'h2b:keycode="f";8'h34:keycode="g";8'h33:keycode="h";
   8'h43:keycode="i";8'h3b:keycode="j";8'h42:keycode="k";8'h4b:keycode="l";
   8'h3a:keycode="m";8'h31:keycode="n";8'h44:keycode="o";8'h4d:keycode="p";
   8'h15:keycode="q";8'h2d:keycode="r";8'h1b:keycode="s";8'h2c:keycode="t";
   8'h3c:keycode="u";8'h2a:keycode="v";8'h1d:keycode="w";8'h22:keycode="x";
   8'h35:keycode="y";8'h1a:keycode="z";
   8'h16:keycode=shift?"!":"1";8'h1e:keycode=shift?"@":"2";
   8'h26:keycode=shift?"#":"3";8'h25:keycode=shift?"$":"4";
   8'h2e:keycode=shift?"%":"5";8'h36:keycode=shift?"^":"6";
   8'h3d:keycode=shift?"&":"7";8'h3e:keycode=shift?"*":"8";
   8'h46:keycode=shift?"(":"9";8'h45:keycode=shift?")":"0";
   8'h4e:keycode=shift?"_":"-";8'h55:keycode=shift?"+":"=";
   8'h54:keycode=shift?"{":"[";8'h5b:keycode=shift?"}":"]";
   8'h5d:keycode=shift?"|":8'h5c;8'h4c:keycode=shift?":":";";
   8'h52:keycode=shift?8'h22:8'h27;8'h41:keycode=shift?"<":",";
   8'h49:keycode=shift?">":".";8'h4a:keycode=shift?"?":"/";
   8'h0e:keycode=shift?"~":"`";
   8'h29:keycode=32;8'h5a:keycode=13;8'h66:keycode=8;8'h0d:keycode=9;
   8'h76:keycode=27;8'h71:keycode=127;
   default:;
  endcase
  if(keycode>="a" && keycode<="z") begin
   if(ctrl)keycode=keycode-8'h60;
   else if(shift^caps)keycode=keycode-8'h20;
  end
 end
 assign data_in=interrogate?1'b0:response;
 assign clock_in=busy==0;
 always @(posedge clk) begin
  old_event<=ps2_key[10];old_interrogate<=interrogate;
  if(reset)begin
   old_event<=ps2_key[10];shift_l<=0;shift_r<=0;ctrl<=0;caps<=0;
   wp<=0;rp<=0;bitpos<=0;serial<=0;response<=1;busy<=0;overflow<=0;old_interrogate<=0;repeating<=0;caps_pressed<=0;repeat_scan<=0;repeat_char<=0;repeat_count<=0;
  end else begin
   if(busy!=0)busy<=busy-1'b1;
   if(repeating)begin
    if(repeat_count!=0)repeat_count<=repeat_count-1'b1;
    else if(old_event==ps2_key[10])begin
     repeat_count<=SYS_HZ/10;
     if(wp-rp<32)begin fifo[wp[4:0]]<=repeat_char;wp<=wp+1'b1;busy<=SYS_HZ/10000;end
     else overflow<=1;
    end
   end
   if(old_event!=ps2_key[10])begin
    if(!ps2_key[9] && ps2_key[8:0]==repeat_scan)repeating<=0;
    case(ps2_key[7:0])
     8'h12:shift_l<=ps2_key[9];8'h59:shift_r<=ps2_key[9];8'h14:ctrl<=ps2_key[9];
     8'h58:begin caps_pressed<=ps2_key[9];if(ps2_key[9] && !caps_pressed)caps<=!caps;end
     default:if(ps2_key[9] && keycode!=0 && (!repeating || repeat_scan!=ps2_key[8:0])) begin
      repeating<=1;repeat_scan<=ps2_key[8:0];repeat_char<=keycode;repeat_count<=SYS_HZ*4/10;
      if(wp-rp<32)begin fifo[wp[4:0]]<=keycode;wp<=wp+1'b1;busy<=SYS_HZ/10000;end
      else overflow<=1;
     end
    endcase
   end
   if(old_interrogate && !interrogate)begin
    if(bitpos==0)begin
     if(wp!=rp && busy==0)begin serial<=fifo[rp[4:0]];bitpos<=1;response<=0;end
     else response<=1;
    end else begin
     response<=serial[0];serial<={1'b1,serial[7:1]};
     if(bitpos==8)begin bitpos<=0;rp<=rp+1'b1;end else bitpos<=bitpos+1'b1;
    end
   end
  end
 end
endmodule
