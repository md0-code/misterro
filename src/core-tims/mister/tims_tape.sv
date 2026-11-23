// SPDX-License-Identifier: GPL-3.0-or-later
// Pulse playback through EAR, using the pinned MiSTer tape implementation.
module tims_tape #(parameter ADDR_BITS = 18) (
    input wire clk, reset, ce,mode48k,
    input wire download, wr,
    input wire [26:0] address,
    input wire [7:0] data,
    input wire [1:0] mode,
    input wire pause, prev, next,
    output wire audio, active, available,
    output reg overflow = 0
);
    localparam WORDS=((1<<ADDR_BITS)*8+9)/10;
    
    reg [17:0] pending=0;reg [3:0] bits=0;
    reg [ADDR_BITS-1:0] write_word=0;
    wire [9:0] low_q,high_q;reg [3:0] offset_q;
    // Six three-bit radix stages keep every divide/remainder input to six bits.
    // The complete packed RAM read takes nine system clocks, below one tape CE.
    wire [17:0] byte_index=read_address[ADDR_BITS-1:0];
    reg [2:0] q0=0,r0=0;reg [14:0] t0=0;
    reg [5:0] q1=0;reg [2:0] r1=0;reg [11:0] t1=0;
    reg [8:0] q2=0,t2=0;reg [2:0] r2=0;
    reg [11:0] q3=0;reg [5:0] t3=0;reg [2:0] r3=0;
    reg [14:0] q4=0;reg [2:0] r4=0,t4=0;
    wire [5:0] d1={r0,t0[14:12]},d2={r1,t1[11:9]},d3={r2,t2[8:6]},d4={r3,t3[5:3]},d5={r4,t4};
    wire [2:0] div1=d1/6'd5,div2=d2/6'd5,div3=d3/6'd5,div4=d4/6'd5;
    wire [2:0] last_q=d5/6'd5,last_r=d5%6'd5;
    wire [1:0] last_word=last_r<2?2'd0:last_r-1'b1;
    reg [ADDR_BITS-1:0] word_address=0;reg [3:0] bit_offset=0;
    reg [17:0] tag1=0,tag2=0,tag3=0,tag4=0,tag5=0,tag6=0,tag7=0,tag8=0,tag9=0;
    reg [19:0] read_pair=0;reg [3:0] pair_offset=0;reg memory_phase=0;
    wire rd_en=tag9!=byte_index||memory_phase;
    always @(posedge clk)begin
        q0<=byte_index[17:15]/3'd5;r0<=byte_index[17:15]%3'd5;t0<=byte_index[14:0];
        q1<={q0,div1};r1<=d1%6'd5;t1<=t0[11:0];
        q2<={q1,div2};r2<=d2%6'd5;t2<=t1[8:0];
        q3<={q2,div3};r3<=d3%6'd5;t3<=t2[5:0];
        q4<={q3,div4};r4<=d4%6'd5;t4<=t3[2:0];
        word_address<={q4[12:0],last_q,last_word};
        case(last_r)
            0:bit_offset<=0;1:bit_offset<=8;2:bit_offset<=6;3:bit_offset<=4;4:bit_offset<=2;
            default:bit_offset<=0;
        endcase
        tag1<=byte_index;tag2<=tag1;tag3<=tag2;tag4<=tag3;tag5<=tag4;tag6<=tag5;tag7<=tag6;tag8<=tag7;tag9<=tag8;
        read_pair<={high_q,low_q};pair_offset<=offset_q;read_q<=read_pair>>pair_offset;
        memory_phase<=~memory_phase;
    end
    wire [17:0] combined=pending | ({10'd0,data} << bits);
    reg [7:0] read_q;
    wire [24:0] read_address;
    wire rd;
    reg was_download = 0, ready = 0;
    reg [24:0] length = 0;
    reg [1:0] saved_mode = 0;
    reg [1:0] start_count = 0;
    always @(posedge clk) begin
        was_download <= download;
        if (reset) begin ready <= 0; overflow <= 0; length <= 0; start_count <= 0; end
        else begin
            if (ce && start_count != 0) start_count <= start_count - 1'b1;
            if (download && !was_download) begin ready <= 0; overflow <= 0; length <= 0; saved_mode <= mode; start_count <= 0; pending<=0;bits<=0;write_word<=0; end
            if (download && wr) begin
                if (address < (1<<ADDR_BITS)) begin
                    if(bits>=2)begin write_word<=write_word+1'b1;pending<=combined>>10;bits<=bits-2'd2;end
                    else begin pending<=combined;bits<=bits+4'd8;end
                    length <= address[24:0] + 1'b1;
                end else overflow <= 1;
            end
            if (!download && was_download) begin
                
                ready <= !overflow && length != 0;
                start_count <= !overflow && length != 0 ? 2'd3 : 2'd0;
            end
        end
        offset_q<=bit_offset;
    end
    wire packed_write=(download && wr && address<(1<<ADDR_BITS) && bits>=2) || (!download && was_download && bits!=0);
    wire [ADDR_BITS-1:0] port_a_address=packed_write?write_word:word_address;
    wire [9:0] packed_data=download?combined[9:0]:pending[9:0];
    rp_tape_ram #(.WORDS(WORDS),.ADDR_BITS(ADDR_BITS)) storage(.clk(clk),.write(packed_write),
      .address_a(port_a_address),.data(packed_data),.q_a(low_q),.address_b(word_address+1'b1),.q_b(high_q));
    tape player (
        .clk_sys(clk), .ce(ce), .mode48k(mode48k), .turbo(1'b0),
        .byte_wait(1'b0), .byte_ready(), .dout(),
        .pause(pause || start_count == 2), .prev(prev), .next(next), .active(active), .available(available),
        .tape_ready(ready && !download && !reset), .tape_mode(saved_mode), .tape_size(length),
        .stdload(1'b0), .loader(1'b0), .req_hdr(1'b0), .audio_out(audio),
        .rd_en(rd_en), .rd(rd), .addr(read_address), .din(read_q)
    );
endmodule
