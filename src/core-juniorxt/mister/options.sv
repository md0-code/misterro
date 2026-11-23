    // JUNIOR options. Boards follow the menu at once; reset to let the BIOS see them.
    wire [1:0] junior_display = status[109:108];              // 0 CGA80, 1 CGA40, 2 MDA, 3 none
    wire [1:0] junior_board   = status[111:110];              // 0 SIO + printer, 1 COM1, 2 COM1 + COM2, 3 none
    wire [2:0] junior_ram     = status[107:105];              // 640, 256, 192, 128, 64 KiB
    wire [3:0] junior_ram_blocks = (junior_ram == 3'd0) ? 4'd10 : (junior_ram == 3'd1) ? 4'd4 :
                                   (junior_ram == 3'd2) ? 4'd3  : (junior_ram == 3'd3) ? 4'd2 : 4'd1;
    wire [1:0] junior_ram_sw  = (junior_ram_blocks >= 4'd4) ? 2'b11 : (junior_ram_blocks[1:0] - 2'd1);
    wire [1:0] junior_display_sw = (junior_display == 2'd0) ? 2'b10 : (junior_display == 2'd1) ? 2'b01 :
                                   (junior_display == 2'd2) ? 2'b11 : 2'b00;
    wire       junior_mda     = (junior_display == 2'd2);
    wire       junior_cga     = ~junior_display[1];
    wire       junior_winchester = status[113];
    // 0 SIO + printer, 1 COM1, 2 COM2, 3 game adapter, 4 Winchester, 6:5 CGA monitor, 7 monochrome coupler
    wire [15:0] junior_cfg = {8'd0, junior_mda, status[115:114], junior_winchester, status[112],
                              junior_board == 2'd2, junior_board == 2'd1 || junior_board == 2'd2, junior_board == 2'd0};
