derive_pll_clocks
derive_clock_uncertainty
# HPS configuration changes are asynchronous to the machine clock.
set_false_path -from {*|hps_io|status[*]}
