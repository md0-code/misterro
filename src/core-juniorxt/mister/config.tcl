# MGL sets the public name/folder to JUNIORXT; PCXT selects the existing HPS disk driver.
# FEPER JUNIOR-XT: CGA or monochrome coupler, speaker, 64-640 KiB. No PCjr/Tandy/EGA/ISA audio.
set_global_assignment -name VERILOG_MACRO {CORE_NAME="PCXT"}
foreach {macro value} {SYSTEM_VARIANT_TANDY 0 ROM_VARIANT_TANDY 0 ENABLE_TANDY_VIDEO 0 ENABLE_TANDY_AUDIO 0 ENABLE_TANDY_KBD 0 ENABLE_PCJR 0 ENABLE_CGA 1 ENABLE_HGC 1 ENABLE_EGA 0 ENABLE_EMS 0 ENABLE_A000_UMB 0 ENABLE_UMB 0 ENABLE_OPL2 0 ENABLE_CMS 0 ENABLE_SB 0 ENABLE_MIDI 0} {
 set_global_assignment -name VERILOG_MACRO "${macro}=${value}"
}
set_global_assignment -name SEED 5

# The SDRAM controller must reach every SDRAM DQ I/O register on a global clock.
set_instance_assignment -name GLOBAL_SIGNAL "GLOBAL CLOCK" -to {emu:emu|pll_system:pll_system_inst|pll_system_0002:pll_system_inst|altera_pll:altera_pll_i|outclk_wire[2]}
