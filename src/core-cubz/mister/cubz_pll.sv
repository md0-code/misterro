// SPDX-License-Identifier: GPL-3.0-or-later
module cubz_pll(input wire refclk,rst,output wire clk,locked);
 // Match the pinned MiSTer framework's machine-clock hierarchy so its
 // existing asynchronous clock groups apply to the 40 MHz domain.
 cubz_pll_impl pll_inst(.refclk(refclk),.rst(rst),.clk(clk),.locked(locked));
endmodule
module cubz_pll_impl(input wire refclk,rst,output wire clk,locked);
 altera_pll #(.reference_clock_frequency("50.0 MHz"),.operation_mode("direct"),.number_of_clocks(1),
 .output_clock_frequency0("40.000000 MHz"),.phase_shift0("0 ps"),.duty_cycle0(50),.pll_type("General"),.pll_subtype("General"))
 altera_pll_i(.refclk(refclk),.rst(rst),.outclk(clk),.locked(locked),.fbclk(1'b0),.fboutclk());
endmodule
