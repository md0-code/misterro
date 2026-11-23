# Native T80 data state commits on CEN_p once per 32 clk_sys edges.
# DIRSet is tied low; NMI/BUSRQ are constants. Allow only TWO edges for paths
# wholly inside the CEN-gated T80 state/register file. Keep CPU inputs, bus
# outputs, divider enables, RAM, reset recovery and every other path at one edge.
set native_state [get_keepers {emu|family_machine|cpu|u0|*}]
set_multicycle_path -from $native_state -to $native_state -setup 2
set_multicycle_path -from $native_state -to $native_state -hold 1
