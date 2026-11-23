// SPDX-License-Identifier: GPL-3.0-or-later
module machine_core(
 `include "rp_machine_ports.vh"
);
 rp_native_machine #(.PRAE(1)) machine(.*);
endmodule
