// SPDX-License-Identifier: GPL-3.0-or-later
module emu (
    `include "sys/emu_ports.vh"
);
    wire clk_sys, locked;
    pll pll (.refclk(CLK_50M), .rst(1'b0), .outclk_0(), .outclk_1(clk_sys), .locked(locked));
    wire [127:0] status;
    wire [10:0] ps2_key;
    wire [31:0] joy0, joy1;
    wire [1:0] buttons;
    wire forced_scandoubler;
    wire [21:0] gamma_bus;
    wire ioctl_download, ioctl_wr;
    wire [26:0] ioctl_addr;
    wire [15:0] ioctl_index;
    wire [7:0] ioctl_dout;
    localparam CONF_STR = {
        "CIP01;;",
        "F0,ROM,Load 2K Bootstrap;",
        "F2,TAPCSWTZXPZX,Load Tape (max 256 KiB);",
        "T[3],Tape Play/Pause;",
        "T[4],Previous Tape Block;",
        "T[5],Next Tape Block;",
        "-;",
        "O[1],Aspect Ratio,Original,Full Screen;",
        "O[2],Tape Sound,On,Off;",
        "-;",
        "R[0],Reset to Monitor;",
        "J,Fire;",
        "V,v0.1"
    };
    hps_io #(.CONF_STR(CONF_STR)) hps_io (
        .clk_sys(clk_sys), .HPS_BUS(HPS_BUS), .status(status),
        .buttons(buttons), .forced_scandoubler(forced_scandoubler),
        .ps2_key(ps2_key), .joystick_0(joy0), .joystick_1(joy1),
        .gamma_bus(gamma_bus), .ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr),
        .ioctl_addr(ioctl_addr), .ioctl_index(ioctl_index), .ioctl_dout(ioctl_dout), .ioctl_wait(1'b0),
        .sd_rd(1'b0), .sd_wr(1'b0), .sd_lba('{32'd0}), .sd_blk_cnt('{6'd0}), .sd_buff_din('{8'd0})
    );
    wire rom_download = ioctl_download && ioctl_index[5:0] == 0;
    wire tape_download = ioctl_download && ioctl_index[5:0] == 2;
    reg old_rom_download = 0, rom_loaded = 0, rom_overflow = 0;
    reg [14:0] rom_length = 0;
    always @(posedge clk_sys) begin
        old_rom_download <= rom_download;
        if (RESET) begin rom_loaded <= 0; rom_length <= 0; rom_overflow <= 0; end
        else begin
            if (rom_download && !old_rom_download) begin rom_loaded <= 0; rom_length <= 0; rom_overflow <= 0; end
            if (rom_download && ioctl_wr) begin
                if (ioctl_addr < 2048) rom_length <= ioctl_addr[14:0]+1'b1;
                else rom_overflow <= 1;
            end
            if (!rom_download && old_rom_download) rom_loaded <= rom_length == 2048 && !rom_overflow;
        end
    end
    wire [39:0] keys_n;
    wire key_pause, key_prev, key_next, key_reset;
    cip01_keyboard keyboard (.clk(clk_sys), .reset(RESET), .ps2_key(ps2_key),
        .joy0(joy0), .joy1(joy1), .keys_n(keys_n), .tape_pause(key_pause),
        .tape_prev(key_prev), .tape_next(key_next), .warm_reset(key_reset));
    // Tape BASIC can modify its own entry bytes. User reset must recover the monitor.
    wire cold_reset = RESET || !locked || !rom_loaded || rom_download || status[0] || buttons[1] || key_reset;
    wire reset = cold_reset;
    wire [3:0] rgb;
    wire pixel, hs, vs, hb, vb, beeper, mic, ce_tape;
    wire tape_audio, tape_active, tape_available, tape_overflow;
    cip01_core machine (
        .clk(clk_sys), .reset(reset), .cold_reset(cold_reset), .video_reset(RESET || !locked), .monitor_rom(1'b1), .keys_n(keys_n), .ear(tape_audio),
        .rom_wr(rom_download && ioctl_wr && ioctl_addr < 2048),
        .rom_addr(ioctl_addr[10:0]), .rom_data(ioctl_dout),
        .ce_pixel(pixel), .ce_tape(ce_tape), .rgb(rgb), .hs(hs), .vs(vs),
        .hblank(hb), .vblank(vb), .beeper(beeper), .mic(mic),
        .video_x(), .video_y(), .debug_pc(), .debug_addr(), .debug_data(),
        .debug_mem_wr(), .debug_io_wr(), .debug_cpu_p(), .debug_stall(), .boot_rom());
    cip01_tape cassette (.clk(clk_sys), .reset(RESET), .ce(ce_tape),
        .download(tape_download), .wr(ioctl_wr), .address(ioctl_addr), .data(ioctl_dout),
        .mode(ioctl_index[7:6]), .pause(key_pause || status[3]),
        .prev(key_prev || status[4]), .next(key_next || status[5]),
        .audio(tape_audio), .active(tape_active), .available(tape_available), .overflow(tape_overflow));
    assign CLK_VIDEO = clk_sys;
    video_mixer #(.LINE_LENGTH(352), .GAMMA(1)) mixer (
        .CLK_VIDEO(clk_sys), .CE_PIXEL(CE_PIXEL), .ce_pix(pixel),
        .scandoubler(forced_scandoubler), .hq2x(1'b0), .gamma_bus(gamma_bus),
        .R(rgb[1] ? (rgb[3] ? 8'hff : 8'hcd) : 8'h00),
        .G(rgb[2] ? (rgb[3] ? 8'hff : 8'hcd) : 8'h00),
        .B(rgb[0] ? (rgb[3] ? 8'hff : 8'hcd) : 8'h00),
        .HSync(!hs), .VSync(!vs), .HBlank(hb), .VBlank(vb),
        .HDMI_FREEZE(1'b0), .freeze_sync(),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_DE(VGA_DE));
    assign VIDEO_ARX = status[1] ? 13'd0 : 13'd4;
    assign VIDEO_ARY = status[1] ? 13'd0 : 13'd3;
    // Preserve the original MIC waveform so SAVE can be recorded from audio out.
    assign AUDIO_L = {2'b00, beeper, mic, (!status[2] && tape_active && tape_audio), 11'd0};
    assign AUDIO_R = AUDIO_L;
    assign AUDIO_S = 0;
    assign AUDIO_MIX = 0;
    assign LED_USER = ioctl_download || tape_active;
    assign LED_POWER = tape_overflow || rom_overflow ? 2'b11 : 2'b00;
    assign LED_DISK = 0;
    assign BUTTONS = 0;
    assign VGA_F1 = 0;
    assign VGA_SL = 0;
    assign VGA_SCALER = 0;
    assign VGA_DISABLE = 0;
    assign HDMI_FREEZE = 0;
    assign HDMI_BLACKOUT = 0;
    assign HDMI_BOB_DEINT = 0;
    assign USER_OUT = '1;
    assign {UART_RTS, UART_TXD, UART_DTR} = 0;
    assign ADC_BUS = 'z;
    assign {SD_SCK, SD_MOSI, SD_CS} = 'z;
    assign DDRAM_CLK = clk_sys;
    assign DDRAM_BURSTCNT = 0;
    assign DDRAM_ADDR = 0;
    assign DDRAM_RD = 0;
    assign DDRAM_DIN = 0;
    assign DDRAM_BE = 0;
    assign DDRAM_WE = 0;
    assign SDRAM_CLK = 0;
    assign SDRAM_CKE = 0;
    assign SDRAM_A = 0;
    assign SDRAM_BA = 0;
    assign SDRAM_DQ = 'z;
    assign {SDRAM_DQML, SDRAM_DQMH, SDRAM_nCS, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nWE} = '1;
endmodule
