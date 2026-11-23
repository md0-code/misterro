// SPDX-License-Identifier: GPL-3.0-or-later
// Pulse playback through EAR, using the pinned MiSTer tape implementation.
module hc85_tape #(parameter ADDR_BITS = 18) (
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
    // Divide the byte index into groups of five. Each registered quotient
    // stage has at most nine input bits; no wide divider sits on a RAM address.
    wire [17:0] byte_index=read_address[ADDR_BITS-1:0];
    reg [5:0] quotient0=0;reg [2:0] remainder0=0;reg [11:0] tail0=0;
    reg [11:0] quotient1=0;reg [2:0] remainder1=0;reg [5:0] tail1=0;
    wire [8:0] middle={remainder0,tail0[11:6]};
    wire [8:0] bottom={remainder1,tail1};
    wire [5:0] middle_quotient=middle/5;
    wire [5:0] last_quotient=bottom/5;
    wire [2:0] last_remainder=bottom%5;
    wire [1:0] last_word=last_remainder<2?2'd0:last_remainder-1'b1;
    reg [ADDR_BITS-1:0] word_address=0;reg [3:0] bit_offset=0;
    reg [17:0] tag1=0,tag2=0,tag3=0,tag4=0,tag5=0,tag6=0;
    reg [19:0] read_pair=0;reg [3:0] pair_offset=0;
    reg memory_phase=0;
    wire rd_en=tag6!=byte_index || memory_phase;
    always @(posedge clk)begin
        quotient0<=byte_index[17:12]/5;remainder0<=byte_index[17:12]%5;tail0<=byte_index[11:0];tag1<=byte_index;
        quotient1<={quotient0,middle_quotient};remainder1<=middle%5;tail1<=tail0[5:0];tag2<=tag1;
        word_address<={quotient1[9:0],last_quotient,last_word};
        case(last_remainder)
            0:bit_offset<=0;1:bit_offset<=8;2:bit_offset<=6;3:bit_offset<=4;4:bit_offset<=2;
            default:bit_offset<=0;
        endcase
        tag3<=tag2;tag4<=tag3;tag5<=tag4;tag6<=tag5;
        read_pair<={high_q,low_q};pair_offset<=offset_q;read_q<=read_pair >> pair_offset;
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
    hc_tape_ram #(.WORDS(WORDS),.ADDR_BITS(ADDR_BITS)) storage(.clk(clk),.write(packed_write),
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

module hc_tape_ram #(parameter WORDS=209716,ADDR_BITS=18)(
 input wire clk,write,input wire [ADDR_BITS-1:0] address_a,address_b,input wire [9:0] data,
 output reg [9:0] q_a,q_b
);
 (* ramstyle="M10K", max_depth=1024 *) reg [9:0] memory[0:WORDS-1];
 always @(posedge clk)begin
  if(write)begin memory[address_a]<=data;q_a<=data;end
  else q_a<=memory[address_a];
 end
 always @(posedge clk)q_b<=memory[address_b];
endmodule
