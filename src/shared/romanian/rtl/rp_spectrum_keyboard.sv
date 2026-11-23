// SPDX-License-Identifier: GPL-3.0-or-later
// MiSTer PS/2 events to the HC-85 8 x 5 matrix (schematic sheet 8).
module rp_spectrum_keyboard (
    input wire clk, reset,
    input wire [10:0] ps2_key,
    input wire [31:0] joy0, joy1,
    output reg [39:0] keys_n,
    output wire tape_pause, tape_prev, tape_next, warm_reset
);
    reg [511:0] pressed = 0;
    reg last_toggle = 0;
    always @(posedge clk) begin
        last_toggle <= ps2_key[10];
        if (reset) pressed <= 0;
        else if (last_toggle != ps2_key[10]) pressed[ps2_key[8:0]] <= ps2_key[9];
    end
    reg [39:0] k;
    wire pc_shift = pressed[9'h012] || pressed[9'h059];
    always @* begin
        k = 0;
        // Bits in each row follow D0 through D4 at the CPU port.
        k[ 0] = pc_shift;       k[ 1] = pressed[9'h01a]; // CS Z X C V
        k[ 2] = pressed[9'h022]; k[ 3] = pressed[9'h021]; k[ 4] = pressed[9'h02a];
        k[ 5] = pressed[9'h01c]; k[ 6] = pressed[9'h01b]; // A S D F G
        k[ 7] = pressed[9'h023]; k[ 8] = pressed[9'h02b]; k[ 9] = pressed[9'h034];
        k[10] = pressed[9'h015]; k[11] = pressed[9'h01d]; // Q W E R T
        k[12] = pressed[9'h024]; k[13] = pressed[9'h02d]; k[14] = pressed[9'h02c];
        k[15] = pressed[9'h016]; k[16] = pressed[9'h01e]; // 1 2 3 4 5
        k[17] = pressed[9'h026]; k[18] = pressed[9'h025]; k[19] = pressed[9'h02e];
        k[20] = pressed[9'h045]; k[21] = pressed[9'h046]; // 0 9 8 7 6
        k[22] = pressed[9'h03e]; k[23] = pressed[9'h03d]; k[24] = pressed[9'h036];
        k[25] = pressed[9'h04d]; k[26] = pressed[9'h044]; // P O I U Y
        k[27] = pressed[9'h043]; k[28] = pressed[9'h03c]; k[29] = pressed[9'h035];
        k[30] = pressed[9'h05a]; k[31] = pressed[9'h04b]; // ENTER L K J H
        k[32] = pressed[9'h042]; k[33] = pressed[9'h03b]; k[34] = pressed[9'h033];
        k[35] = pressed[9'h029]; // SPACE SS M N B
        k[36] = pressed[9'h014] || pressed[9'h114] || pressed[9'h011] || pressed[9'h111];
        k[37] = pressed[9'h03a]; k[38] = pressed[9'h031]; k[39] = pressed[9'h032];
        if (pressed[9'h066]) begin k[0]=1; k[20]=1; end // delete
        if (pressed[9'h16b]) begin k[0]=1; k[19]=1; end // left
        if (pressed[9'h172]) begin k[0]=1; k[24]=1; end // down
        if (pressed[9'h175]) begin k[0]=1; k[23]=1; end // up
        if (pressed[9'h174]) begin k[0]=1; k[22]=1; end // right
        if (pressed[9'h076]) begin k[0]=1; k[35]=1; end // break
        if (pressed[9'h049]) begin k[0]=0; k[36]=1; k[37]=1; end // period
        if (pressed[9'h041]) begin k[0]=0; k[36]=1; k[38]=1; end // comma
        if (pressed[9'h052]) begin k[0]=0; k[36]=1; if(pc_shift) k[25]=1; else k[23]=1; end
        if (pressed[9'h04c]) begin k[0]=0; k[36]=1; if(pc_shift) k[1]=1; else k[26]=1; end
        if (pressed[9'h04e]) begin k[0]=0; k[36]=1; if(pc_shift) k[20]=1; else k[33]=1; end
        if (pressed[9'h055]) begin k[0]=0; k[36]=1; if(pc_shift) k[32]=1; else k[31]=1; end
        if (pressed[9'h04a]) begin k[0]=0; k[36]=1; if(pc_shift) k[3]=1; else k[4]=1; end
        // HC-85's two Sinclair joystick sockets are wired into the matrix.
        k[15] = k[15] | joy0[1]; k[16] = k[16] | joy0[0];
        k[17] = k[17] | joy0[2]; k[18] = k[18] | joy0[3]; k[19] = k[19] | joy0[4];
        k[24] = k[24] | joy1[1]; k[23] = k[23] | joy1[0];
        k[22] = k[22] | joy1[2]; k[21] = k[21] | joy1[3]; k[20] = k[20] | joy1[4];
        keys_n = ~k;
    end
    assign tape_pause = pressed[9'h005]; // F1
    assign tape_prev = pressed[9'h006];  // F2
    assign tape_next = pressed[9'h004];  // F3
    assign warm_reset = pressed[9'h078]; // F11
endmodule
