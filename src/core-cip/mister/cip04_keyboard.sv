// SPDX-License-Identifier: GPL-3.0-or-later
// Adapter from the project's matrix keyboard to the pinned +3 platform.
module keyboard(input wire reset,clk_sys,input wire [10:0] ps2_key,
    input wire recreated_zx,ghosting,input wire [15:0] addr,output reg [4:0] key_data,
    output reg [11:1] Fn=0,output reg [2:0] mod=0);
    wire [39:0] keys_n;
    cip01_keyboard matrix(.clk(clk_sys),.reset(reset),.ps2_key(ps2_key),.joy0(32'd0),.joy1(32'd0),
        .keys_n(keys_n),.tape_pause(),.tape_prev(),.tape_next(),.warm_reset());
    reg toggle=0;reg left_shift=0,right_shift=0,ctrl=0,alt=0;
    always @(posedge clk_sys) begin
        toggle<=ps2_key[10];
        if(reset) begin Fn<=0;left_shift<=0;right_shift<=0;ctrl<=0;alt<=0;end
        else if(toggle!=ps2_key[10]) begin
            case(ps2_key[7:0])
                8'h05:Fn[1]<=ps2_key[9];8'h06:Fn[2]<=ps2_key[9];8'h04:Fn[3]<=ps2_key[9];
                8'h0c:Fn[4]<=ps2_key[9];8'h03:Fn[5]<=ps2_key[9];8'h0b:Fn[6]<=ps2_key[9];
                8'h83:Fn[7]<=ps2_key[9];8'h0a:Fn[8]<=ps2_key[9];8'h01:Fn[9]<=ps2_key[9];
                8'h09:Fn[10]<=ps2_key[9];8'h78:Fn[11]<=ps2_key[9];
                8'h12:left_shift<=ps2_key[9];8'h59:right_shift<=ps2_key[9];
                8'h14:ctrl<=ps2_key[9];8'h11:alt<=ps2_key[9];
            endcase
        end
        mod<={alt,ctrl,left_shift|right_shift};
    end
    integer row;
    always @* begin
        key_data=5'b11111;
        for(row=0;row<8;row=row+1) if(!addr[8+row])key_data=key_data & keys_n[row*5 +: 5];
    end
endmodule
