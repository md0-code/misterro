// SPDX-License-Identifier: GPL-3.0-or-later
module cip01_bus_case #(parameter STEP=1)(input clk,reset,cold,video_reset, input check_now);
    wire [3:0] rgb; wire beeper,mic;
    cip01_core #(.ROM_FILE("build/bus.hex"),.CLOCK_STEP(STEP)) dut (
        .clk(clk),.reset(reset),.cold_reset(cold),.video_reset(video_reset),.keys_n(40'hfffffffbff),.ear(1'b1),
        .rom_wr(1'b0),.rom_addr(11'd0),.rom_data(8'd0),.rgb(rgb),.beeper(beeper),.mic(mic));
    always @(posedge check_now) begin
        if(dut.ram[0]!==8'h5a || dut.vram[0]!==8'h5a) $fatal(1,"64 KiB RAM mapping failed STEP=%d",STEP);
        if(dut.ram[1]!==8'hf3 || dut.rom[0]!==8'hf3) $fatal(1,"Bootstrap overlay/protection failed");
        if(dut.ram[2]!==8'hfe || dut.ram[3]!==8'hff) $fatal(1,"Keyboard/EAR/A6 port decoding failed");
        if(dut.ram[4]!==8'h5a || dut.ram[5]!==8'ha6 || dut.ram[6]!==8'hf3) $fatal(1,"EE bank switching or EPROM mirroring failed: %h %h %h",dut.ram[4],dut.ram[5],dut.ram[6]);
        if(dut.boot_rom!==0) $fatal(1,"BASIC RAM not selected");
        if(dut.border!==5 || !beeper || !mic) $fatal(1,"FE outputs failed");
    end
endmodule
module cip01_bus_tb;
    reg clk=0,reset=1,cold=1,video_reset=1,check_now=0;
    always #5 clk=~clk;
    cip01_bus_case #(.STEP(1)) hardware(clk,reset,cold,video_reset,check_now);
    cip01_bus_case #(.STEP(8)) simulation(clk,reset,cold,video_reset,check_now);
    initial begin
        repeat(128) @(negedge clk);cold=0;video_reset=0;
        repeat(128) @(negedge clk);
        if(hardware.dut.video_x==447) $fatal(1,"Video stopped while CPU reset");
        reset=0;repeat(100000) @(negedge clk);check_now=1;@(negedge clk);check_now=0;
        reset=1;repeat(128) @(negedge clk);
        if(hardware.dut.boot_rom || simulation.dut.boot_rom) $fatal(1,"Warm reset lost loaded BASIC");
        cold=1;repeat(128) @(negedge clk);
        if(!hardware.dut.boot_rom || !simulation.dut.boot_rom) $fatal(1,"Cold reset did not restore EPROM");
        $display("PASS: RAM under ROM, mirrored 2K EPROM, EE switching, FE keyboard/audio, warm/cold reset; both clock configurations");$finish;
    end
endmodule
