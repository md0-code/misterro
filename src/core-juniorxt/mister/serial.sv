    wire junior_selected = junior_cfg[0] && ~address_enable_n && address[15:4] == 12'h025;
    wire [7:0] junior_data;
    wire junior_irq;
    wire [1:0] junior_tx,junior_rts,junior_dtr;
    junior_serial junior_sio (
        .clk(clock), .reset(reset), .selected(junior_selected),
        .address(address[3:0]), .read_n(io_read_n), .write_n(io_write_n),
        .din(internal_data_bus), .dout(junior_data), .irq(junior_irq),
        .rx({junior_b_rx,uart2_rx}), .tx(junior_tx), .cts_n({junior_b_cts,uart2_cts_n}),
        .dcd_n({junior_b_dcd,uart2_dcd_n}), .dsr_n({junior_b_dsr,uart2_dsr_n}),
        .rts_n(junior_rts), .dtr_n(junior_dtr)
    );
    // MiSTer's serial bridge: SIO channel A, or COM2 of the PC/XT adapter.
    assign uart2_tx = junior_cfg[0] ? junior_tx[0] : junior_cfg[2] ? pc2_tx : 1'b1;
    assign uart2_rts_n = junior_cfg[0] ? junior_rts[0] : junior_cfg[2] ? pc2_rts_n : 1'b1;
    assign uart2_dtr_n = junior_cfg[0] ? junior_dtr[0] : junior_cfg[2] ? pc2_dtr_n : 1'b1;

    assign junior_b_tx=junior_tx[1]; assign junior_b_rts=junior_rts[1]; assign junior_b_dtr=junior_dtr[1];
