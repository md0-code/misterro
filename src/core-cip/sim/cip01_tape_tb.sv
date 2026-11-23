// SPDX-License-Identifier: GPL-3.0-or-later
module cip01_tape_tb;
    reg clk=0,reset=1,download=0,wr=0,pause=0,prev=0,next=0;
    reg [26:0] address=0;
    reg [7:0] data=0;
    reg [3:0] divider=0;
    wire ce=divider==15;
    always #5 clk=~clk;
    always @(posedge clk) divider<=divider+1'b1;
    wire audio,active,available,overflow;
    cip01_tape #(.ADDR_BITS(8)) dut (.clk(clk),.reset(reset),.ce(ce),
        .download(download),.wr(wr),.address(address),.data(data),.mode(2'd0),
        .pause(pause),.prev(prev),.next(next),.audio(audio),.active(active),
        .available(available),.overflow(overflow));
    task write_byte(input integer addr,input reg [7:0] value);
        begin @(negedge clk);address=addr;data=value;wr=1;end
    endtask
    integer n,edges=0;
    reg last_audio;
    initial begin
        repeat(32) @(negedge clk);
        reset=0;download=1;
        repeat(2) @(negedge clk);
        write_byte(0,2);write_byte(1,0);write_byte(2,8'hff);write_byte(3,8'hff);
        @(negedge clk);wr=0;download=0;
        repeat(256) @(negedge clk);
        if(!active || !available || overflow) $fatal(1,"Tape did not autoplay");
        last_audio=audio;
        for(n=0;n<200000;n=n+1) begin
            @(negedge clk);
            if(last_audio!=audio) edges=edges+1;
            last_audio=audio;
        end
        if(edges<4) $fatal(1,"Cassette pilot pulses missing");
        pause=1;repeat(32) @(negedge clk);pause=0;
        repeat(32) @(negedge clk);
        if(active) $fatal(1,"Tape pause failed");
        last_audio=audio;
        repeat(40000) begin @(negedge clk);if(audio!=last_audio) $fatal(1,"Paused tape changed EAR");end
        pause=1;repeat(32) @(negedge clk);pause=0;
        repeat(32) @(negedge clk);
        if(!active) $fatal(1,"Tape resume failed");
        prev=1;repeat(32) @(negedge clk);prev=0;
        repeat(64) @(negedge clk);
        if(!active) $fatal(1,"Previous-block playback failed");
        next=1;repeat(32) @(negedge clk);next=0;
        repeat(2000) @(negedge clk);
        if(available) $fatal(1,"Next block failed to reach tape end");
        download=1;repeat(2) @(negedge clk);
        write_byte(256,8'h00);
        @(negedge clk);wr=0;download=0;
        repeat(256) @(negedge clk);
        if(!overflow || active || available) $fatal(1,"Oversized tape was not rejected");
        $display("PASS: cassette autoplay, EAR pulses, pause/resume, previous/next and overflow rejection");
        $finish;
    end
endmodule
