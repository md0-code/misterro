// Headless CPU/chipset integration. Host models external RAM, media and PS/2 pins only.
module junior_sim #(parameter SPEED=0, IS8086=1)(
 input clk_chip,clk100,clk28,clk57,reset_cpu,reset_sdram,
 input [15:0] cfg, input [3:0] ram_blocks, input [1:0] display, // menu options, as mister/options.sv
 output mem_start,mem_we, output [23:0] mem_addr, output [1:0] mem_len,
 output [63:0] mem_wdata, output [7:0] mem_wbe, input mem_busy,mem_done,
 input [63:0] mem_rdata,input [7:0] fx_cga_vram_d,fx_hgc_vram_d,
 output [4:0] fx_hgc_phase, output [13:0] fx_hgc_cur_word,
 output [4:0] fx_cga_phase, output [13:0] fx_cga_cur_word,
 input ps2_clock,ps2_data, input [15:0] mgmt_address,mgmt_writedata,
 input mgmt_read,mgmt_write,output [15:0] mgmt_readdata, output [1:0] fdd_request, output [2:0] ide_request,
 output [19:0] bus_address, output io_write_n,io_read_n,
 output [7:0] port_b, output [15:0] reg_cx,reg_si, output [7:0] bus_data, output [19:0] pc_fetch,output [2:0] cpu_status,
 output [5:0] red,green,blue, output hsync,vsync,hblank,vblank
);
wire [1:0] fdd_present;
wire [1:0] ram_sw=(ram_blocks>=4'd4)?2'b11:(ram_blocks[1:0]-2'd1);
wire [1:0] display_sw=(display==2'd0)?2'b10:(display==2'd1)?2'b01:(display==2'd2)?2'b11:2'b00;
wire [7:0] switches={1'b0,fdd_present[1],display_sw,ram_sw,2'b01};
wire [7:0] port_c={4'b0000,(port_b[3] ? switches[7:4] : switches[3:0])};
    wire        cpu_ce_posedge, cpu_ce_negedge, cpu_ce_negedge_next, peripheral_ce, clk_cpu;
    wire        cycle_accrate, shift_read_timing, biu_done;
    wire [7:0]  clock_cycle_counter_division_ratio, clock_cycle_counter_decrement_value;
    wire [1:0]  ram_read_wait_cycle, ram_write_wait_cycle;
    logic [1:0] clk_select = 2'b00;
    wire  [1:0] clk_select_next = 2'(SPEED);

    always @(posedge clk_chip, posedge reset_cpu)
        if (reset_cpu) clk_select <= 2'b00;
        else if (biu_done) clk_select <= clk_select_next;

    XT_CE_Generator u_ce (
        .clock(clk_chip), .reset(reset_cpu),
        .clk_select_load(biu_done), .clk_select(clk_select_next),
        .cpu_clk_pin(clk_cpu), .cpu_ce_posedge(cpu_ce_posedge), .cpu_ce_negedge(cpu_ce_negedge),
        .cpu_ce_negedge_next(cpu_ce_negedge_next), .peripheral_ce(peripheral_ce), .cycle_accrate(cycle_accrate),
        .clock_cycle_counter_division_ratio(clock_cycle_counter_division_ratio),
        .clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
        .shift_read_timing(shift_read_timing),
        .ram_read_wait_cycle(ram_read_wait_cycle), .ram_write_wait_cycle(ram_write_wait_cycle)
    );

    wire [19:0] cpu_ad_out;
    logic [19:0] cpu_address = 20'd0;
    wire [7:0]  cpu_data_bus, data_bus;
    wire [15:0] data_bus_word, cpu_data_bus_word;
    wire        word_read_possible, word_read_request, word_write_request;
    wire        processor_ready, interrupt_to_cpu, address_latch_enable, address_direction, lock_n;
    wire [2:0]  processor_status;
    wire [3:0]  dma_acknowledge_n;
    wire [2:0]  SEGMENT;
    wire        s6_3_mux;

    always @(posedge clk_chip) if (address_latch_enable) cpu_address <= cpu_ad_out;

    // memory port <-> bridge
    
    

    // video fetch
    wire        fx_cga_hres, fx_hgc_grph, fx_hgc_page;
    wire [13:0] fx_cga_next_word, fx_hgc_next_word;
    wire serial_loop;

    CHIPSET #(.clk_rate(28'd50000000), .ROM_TANDY(1'b0)) u_chipset (
        .clock(clk_chip), .cpu_ce_posedge(cpu_ce_posedge), .cpu_ce_negedge(cpu_ce_negedge),
        .cpu_ce_negedge_next(cpu_ce_negedge_next),
        .clk_sys(clk_chip), .peripheral_ce(peripheral_ce), .clk_select(clk_select),
        .reset(reset_cpu), .sdram_reset(reset_sdram),
        .cpu_address(cpu_address), .cpu_data_bus(cpu_data_bus), .processor_status(processor_status),
        .processor_lock_n(lock_n), .processor_ready(processor_ready), .interrupt_to_cpu(interrupt_to_cpu),
        .VGA_R(red), .VGA_G(green), .VGA_B(blue), .VGA_HSYNC(hsync), .VGA_VSYNC(vsync), .VGA_HBlank(hblank), .VGA_VBlank(vblank), .splashscreen(1'b0), .composite(1'b0), .video_reset(reset_cpu), .video_output(display==2'd2),
        .clk_vga_cga(clk28), .enable_cga(1'b1), .clk_vga_hgc(clk57), .enable_hgc(1'b1), .hgc_rgb(2'b00), .junior_cfg(cfg), .pcjr_ram_size(ram_blocks),
        .address_ext(20'hFFFFF), .ext_access_request(1'b0),
        .address_direction(address_direction), .data_bus(data_bus),
        .word_read_request(word_read_request), .word_write_request(word_write_request),
        .data_bus_word_in(cpu_data_bus_word), .data_bus_word(data_bus_word),
        .word_read_possible(word_read_possible), .data_bus_ext(8'hFF),
        .address_latch_enable(address_latch_enable), .address(bus_address), .io_write_n(io_write_n), .io_read_n(io_read_n),
        .io_channel_check(1'b0), .io_channel_ready(1'b1), .interrupt_request(8'd0),
        .io_read_n_ext(1'b1), .io_write_n_ext(1'b1), .memory_read_n_ext(1'b1), .memory_write_n_ext(1'b1),
        .dma_request(4'd0), .dma_acknowledge_n(dma_acknowledge_n),
        .port_b_out(port_b), .port_b_in(port_b), .port_c_in(port_c),
        .ps2_clock(ps2_clock), .ps2_data(ps2_data), .ps2_mouseclk_in(1'b1), .ps2_mousedat_in(1'b1),
        .joy_opts(5'd0), .joy0(14'd0), .joy1(14'd0), .joya0(16'd0), .joya1(16'd0),
        .opl2_io(2'b11), .cms_en(1'b0), .tandy_video(1'b0), .pcjr(1'b0),
        // The CGA family only: no EGA card, no Sound Blaster, Tandy sound and MPU-401 as before
        .ega_active(1'b0), .sb_en(1'b0), .sb_irq7(1'b0), .tandy_en(1'b0), .mpu401_enabled(1'b0),
        .umb_enabled(1'b0), .ega_monitor_profile(2'b00),
        .sdram_clk(1'b0), .vid_ack(1'b0), .vid_rvalid(1'b0), .vid_rlast(1'b0), .vid_rdata(16'd0),
        .snoop_valid(1'b0), .snoop_addr(24'd0), .snoop_len(2'd0), .snoop_wdata(64'd0), .snoop_wbe(8'd0),
        .xtegactl_status_effective(40'd0), .xtegactl_status_osd_match(18'd0),
        .id_video_card(2'd1),
        .junior_b_rx(1'b1),.junior_b_cts(1'b1),.junior_b_dcd(1'b1),.junior_b_dsr(1'b1),.clk_uart(1'b0), .uart2_rx(serial_loop),.uart2_tx(serial_loop),.uart2_cts_n(1'b0),.uart2_dcd_n(1'b0),.uart2_dsr_n(1'b0),
        .clk_midi(1'b0), .midi_rx(1'b1),
        .mem_start(mem_start), .mem_we(mem_we), .mem_addr(mem_addr), .mem_len(mem_len),
        .mem_wdata(mem_wdata), .mem_wbe(mem_wbe), .mem_busy(mem_busy), .mem_done(mem_done),
        .mem_rdata(mem_rdata), .mem_flush(1'b0), .ec00_loaded(1'b0),
        .ems_enabled(1'b0), .ems_address(2'b00), .bios_protect_flag(3'b011),
        .use_mmc(2'b00), .spi_miso(1'b0),
        .mgmt_address(mgmt_address), .mgmt_read(mgmt_read), .mgmt_write(mgmt_write), .mgmt_writedata(mgmt_writedata), .mgmt_readdata(mgmt_readdata), .fdd_request(fdd_request), .ide0_request(ide_request), .fdd_present(fdd_present),
        .floppy_wp(2'b00), .enable_a000h(cfg[4]),
        .wait_count_clk_en(cpu_ce_negedge),
        .ram_read_wait_cycle(ram_read_wait_cycle), .ram_write_wait_cycle(ram_write_wait_cycle),
        .cga_hw(~display[1]), .cga_scandouble_en(1'b0), .hercules_hw(display==2'd2),
        .crt_h_offset(4'd0), .crt_v_offset(3'd0), .vsync_width_osd(3'd0), .hsync_width_osd(3'd0),
        .cga_frame_stack_rebuild(1'b0),
        .fx_cga_vram_d(fx_cga_vram_d), .fx_cga_phase(fx_cga_phase), .fx_cga_hres(fx_cga_hres),
        .fx_cga_cur_word(fx_cga_cur_word), .fx_cga_next_word(fx_cga_next_word),
        .fx_hgc_vram_d(fx_hgc_vram_d), .fx_hgc_phase(fx_hgc_phase), .fx_hgc_grph(fx_hgc_grph),
        .fx_hgc_page(fx_hgc_page), .fx_hgc_cur_word(fx_hgc_cur_word), .fx_hgc_next_word(fx_hgc_next_word)
    );

    i8088 cpu (
        .CORE_CLK(clk100), .CLK(clk_cpu), .RESET(reset_cpu), .READY(processor_ready),
        .NMI(1'b0), .INTR(interrupt_to_cpu),
        .ad_out(cpu_ad_out), .dout(cpu_data_bus), .din(data_bus),
        .lock_n(lock_n), .s6_3_mux(s6_3_mux), .s2_s0_out(processor_status), .SEGMENT(SEGMENT),
        .biu_done(biu_done), .cycle_accrate(cycle_accrate),
        .clock_cycle_counter_division_ratio(clock_cycle_counter_division_ratio),
        .clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
        .shift_read_timing(shift_read_timing),
        .is8086(IS8086 != 0), .fake286_flags(1'b0),
        .word_read_request(word_read_request), .word_write_request(word_write_request),
        .data_bus_word_out(cpu_data_bus_word), .data_bus_word(data_bus_word),
        .word_access_possible(word_read_possible)
    );

assign reg_cx=cpu.u_eu_core.eu_register_cx;assign reg_si=cpu.u_eu_core.eu_register_si;assign bus_data=cpu_data_bus;assign pc_fetch=cpu_ad_out;assign cpu_status=processor_status;
endmodule
