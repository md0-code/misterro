// SPDX-License-Identifier: GPL-3.0-or-later
// Pulse playback through EAR, using the pinned MiSTer tape implementation.
module cip01_tape #(parameter ADDR_BITS = 18, parameter DYNAMIC_MODE48 = 0) (
    input wire clk, reset, ce,
    input wire mode48k,
    input wire download, wr,
    input wire [26:0] address,
    input wire [7:0] data,
    input wire [1:0] mode,
    input wire pause, prev, next,
    output wire audio, active, available,
    output reg overflow = 0
);
    reg [7:0] buffer[0:(1<<ADDR_BITS)-1];
    reg [7:0] read_q;
    wire [24:0] read_address;
    wire rd;
    reg rd_en = 0, was_download = 0, ready = 0;
    reg [24:0] length = 0;
    reg [1:0] saved_mode = 0;
    reg [1:0] start_count = 0;
    always @(posedge clk) begin
        rd_en <= ~rd_en;
        was_download <= download;
        if (reset) begin ready <= 0; overflow <= 0; length <= 0; start_count <= 0; end
        else begin
            if (ce && start_count != 0) start_count <= start_count - 1'b1;
            if (download && !was_download) begin ready <= 0; overflow <= 0; length <= 0; saved_mode <= mode; start_count <= 0; end
            if (download && wr) begin
                if (address < (1<<ADDR_BITS)) begin
                    buffer[address[ADDR_BITS-1:0]] <= data;
                    length <= address[24:0] + 1'b1;
                end else overflow <= 1;
            end
            if (!download && was_download) begin
                ready <= !overflow && length != 0;
                start_count <= !overflow && length != 0 ? 2'd3 : 2'd0;
            end
        end
        if (rd) read_q <= buffer[read_address[ADDR_BITS-1:0]];
    end
    tape player (
        .clk_sys(clk), .ce(ce), .mode48k(DYNAMIC_MODE48 ? mode48k : 1'b1), .turbo(1'b0),
        .byte_wait(1'b0), .byte_ready(), .dout(),
        .pause(pause || start_count == 2), .prev(prev), .next(next), .active(active), .available(available),
        .tape_ready(ready && !download && !reset), .tape_mode(saved_mode), .tape_size(length),
        .stdload(1'b0), .loader(1'b0), .req_hdr(1'b0), .audio_out(audio),
        .rd_en(rd_en), .rd(rd), .addr(read_address), .din(read_q)
    );
endmodule
