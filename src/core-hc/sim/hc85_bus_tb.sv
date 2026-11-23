// SPDX-License-Identifier: GPL-3.0-or-later
// Execute Z80 instructions through the actual core, including attempted ROM writes.
module hc85_bus_tb #(parameter MODEL=85,parameter DYNAMIC=0,parameter ROM_FILE="build/bus.hex");
    reg clk=0, reset=1, video_reset=1;
    always #5 clk=~clk;
    wire [2:0] rgb;
    wire beeper,mic;
    integer trace_count=0,stalls=0;
    always @(posedge clk) if(!reset && dut.debug_stall) stalls=stalls+1;
    always @(negedge clk) if($test$plusargs("trace") && !reset && dut.cpu_p && trace_count<80) begin
        $display("CPU pc=%h addr=%h in=%h out=%h mreq=%b rd=%b wr=%b IR=%h addrsel=%h",dut.debug_pc,dut.addr,dut.cpu_in,dut.cpu_out,dut.mreq_n,dut.rd_n,dut.wr_n,dut.cpu.u0_component.ir,dut.cpu.u0_component.set_addr_to);
        trace_count=trace_count+1;
    end
    hc85_core #(.MODEL(MODEL),.DYNAMIC_MODEL(DYNAMIC),.ROM_FILE(ROM_FILE)) dut (
        .clk(clk), .reset(reset), .video_reset(video_reset), .model_select(MODEL==85 ? 2'd0 : MODEL==90 ? 2'd1 : 2'd2), .keys_n(40'hfffffffbff), .ear(1'b1),
        .rom_wr(1'b0), .rom_addr({(DYNAMIC ? 16 : 14){1'b0}}), .rom_data(8'd0),
        .ce_pixel(), .ce_tape(), .rgb(rgb), .hs(), .vs(), .hblank(), .vblank(),
        .beeper(beeper), .mic(mic), .video_x(), .video_y(),
        .debug_pc(), .debug_addr(), .debug_data(), .debug_mem_wr(), .debug_io_wr(),
        .debug_cpu_p(), .debug_stall());
    initial begin
        repeat(128) @(negedge clk);
        video_reset=0;
        repeat(128) @(negedge clk);
        if(dut.video_x==447) $fatal(1,"Video timing stopped while CPU waited for ROM");
        reset=0;
        repeat(100000) @(negedge clk);
        if(dut.ram[0] !== 8'h5a || dut.vram[0] !== 8'h5a) $fatal(1,"RAM banks not independently writable: %h %h PC=%h",dut.ram[0],dut.vram[0],dut.debug_pc);
        if(dut.ram[1] !== 8'hf3 || dut.rom[0] !== 8'hf3) $fatal(1,"CPU write modified ROM");
        if(dut.ram[2] !== 8'hfe) $fatal(1,"Keyboard/EAR read wrong: %h",dut.ram[2]);
        if(dut.ram[3] !== (MODEL==85 ? 8'hff : 8'hfe)) $fatal(1,"A6-low port decode wrong");
        if(dut.ram[4] !== (MODEL==85 ? 8'hfe : 8'hff)) $fatal(1,"A7-low port decode wrong");
        if(dut.border !== (MODEL==85 ? 3'd2 : 3'd4) || beeper !== 1'b0 || mic !== 1'b0) $fatal(1,"Border/beeper/MIC output wrong");
        if(MODEL!=85 && stalls!=0) $fatal(1,"Later HC clock was stopped during RAM access");
        if(MODEL==85 && stalls==0) $fatal(1,"HC85 arbitration was lost");
        $display("PASS: CPU memory map, ROM protection, HC port decode, keyboard/EAR, beeper/MIC");
        $finish;
    end
endmodule
