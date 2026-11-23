"""Prepare a reproducible JUNIOR-XT specialization without editing the pinned vendor."""
from project_paths import ROOT,DOCS
from validate_quartus import source_hashes
from prepare_assets import main as assets
import shutil,json,subprocess,re
UP=ROOT/'vendor/pcxt';OUT=ROOT/'build/quartus-JUNIORXT'
def replace(s,old,new,count=1):
 if s.count(old)!=count:raise ValueError('Upstream patch no longer matches: '+old[:90])
 return s.replace(old,new)
def main():
 assets();OUT.mkdir(parents=True,exist_ok=True)
 dep=json.loads((DOCS/'dependencies.lock.json').read_text())
 if (UP/'.git').exists() and subprocess.check_output(['git','rev-parse','HEAD'],cwd=UP,text=True).strip()!=dep['pcxt']['commit']:raise ValueError('Dependency revision changed')
 for folder in ['sys','rtl','platform','profiles','scripts','vendor']:
  shutil.copytree(UP/folder,OUT/folder,dirs_exist_ok=True)
 for name in ['PCXT.sv','SYSTEM.sdc','PCXT.qsf','files.qip']:
  shutil.copyfile(UP/name,OUT/name)
 for p in (ROOT/'rtl').glob('*.sv'):shutil.copyfile(p,OUT/'rtl'/p.name)
 (OUT/'config.tcl').write_text((ROOT/'mister/config.tcl').read_text())
 s=(OUT/'PCXT.sv').read_text()
 start=s.index('    localparam CONF_STR = {');end=s.index('    wire forced_scandoubler;',start)
 s=s[:start]+(ROOT/'mister/menu.sv').read_text()+'\n'+s[end:]
 s=replace(s,'    wire [127:0] status;','    wire [127:0] status;\n'+(ROOT/'mister/options.sv').read_text())
 for name,value in [('hgc_first_osd  ','junior_mda'),('cga_absent_osd ','~junior_cga'),('hgc_absent_osd ','~junior_mda')]:
  s,n=re.subn(r'(wire        '+name+r' = )L_EGA \? status\[\d+\] : status\[\d+\];',r'\g<1>'+value+';',s)
  if n!=1:raise ValueError('Upstream patch no longer matches: '+name)
 s=replace(s,"wire  [3:0] pcjr_ram_size = HAS_PCJR ? pcjr_ram_size_r : 4'd8;","wire  [3:0] pcjr_ram_size = junior_ram_blocks; // 64 KiB blocks of RAM")
 s=replace(s,"wire a000h = `ENABLE_A000_UMB ? (~a000_off_osd & ~xtctl[6] & ~pcjr_video_mode) : 1'b0;","wire a000h = junior_winchester; // repurposed: the Winchester ROM is in the C8000 socket")
 s=replace(s,"(`ENABLE_HGC ? (`ENABLE_CGA ? (swap_video & ~tandy_video_mode) : (`ENABLE_TANDY_VIDEO ? 1'b0 : 1'b1)) : 1'b0);","junior_mda;")
 s=replace(s,"wire [5:0] sw_base_cga = `ENABLE_HGC ? (hgc_mode ? 6'b111101 : 6'b101101) : 6'b101101;","wire [5:0] sw_base_cga = {junior_display_sw, junior_ram_sw, 2'b01}; // SW6-5 display, SW4-3 RAM banks, SW2 no 8087, SW1")
 s=replace(s,"wire [1:0] hgc_rgb_sel = `ENABLE_HGC ? 2'b10 : 2'b00;","wire [1:0] hgc_rgb_sel = 2'b00; // green monochrome monitor")
 # No splash picture: the screen stays dark until the BIOS is loaded.
 s=replace(s,'.splashscreen                       (splashscreen),',".splashscreen                       (1'b0),")
 s=replace(s,'splash_vid_sync1  <= splashscreen;',"splash_vid_sync1  <= 1'b0;")
 s=replace(s,'assign USER_OUT = user_io_mt32 ? mt32_user_out : 7\'h7F;',"assign USER_OUT = {2'b11,junior_b_dtr,1'b1,junior_b_rts,junior_b_tx,1'b1};")
 s=replace(s,'wire uart_tx, uart_rts, uart_dtr;','wire uart_tx, uart_rts, uart_dtr; wire junior_b_tx,junior_b_rts,junior_b_dtr;')
 s=replace(s,'.uart2_rx                           (uart_rx),', '.junior_b_rx(USER_IN[0]), .junior_b_cts(USER_IN[3]), .junior_b_dcd(USER_IN[6]), .junior_b_dsr(USER_IN[5]),\n        .junior_b_tx(junior_b_tx), .junior_b_rts(junior_b_rts), .junior_b_dtr(junior_b_dtr), .junior_cfg(junior_cfg),\n        .uart2_rx                           (uart_rx),')
 s=replace(s,'wire        cpu_type_8086_osd = status[63] & ~pcjr_chosen;','wire        cpu_type_8086_osd = ~status[63]; // JUNIOR defaults to the native 8086')
 s=replace(s,"splash_off <= (status[104:103] == 2'd3);","splash_off <= 1'b1; // original JUNIOR POST appears immediately")
 (OUT/'PCXT.sv').write_text(s)
 # Original board has no RAM/EMS/XTIDE in the unpopulated C0000-EFFFF window.
 p=OUT/'rtl/mem/mem_map.sv';s=p.read_text();s=replace(s,'& ~pcjr_no_ram & ~pcjr_no_cart;','& ~pcjr_no_ram & ~pcjr_no_cart & ~junior_no_ram & ~(seg_cde & ~junior_rom);')
 # RAM ends after pcjr_ram_size blocks of 64 KiB. The C8000 socket (16 KiB) holds the Winchester
 # ROM (enable_a000h, stored behind the BIOS in the Tandy slot) or a loaded option ROM (slot 2).
 s=replace(s,"wire seg_ec00 = (address[19:14] == 6'b111011);","wire seg_ec00 = (address[19:14] == 6'b110010);\n    wire junior_rom = seg_ec00 && (enable_a000h || ec00_loaded);\n    wire junior_no_ram = (address[19:16] < 4'hA) && (address[19:16] >= pcjr_ram_size);")
 s=replace(s,"~(~enable_a000h & (address[19:16] == 4'hA))","~(address[19:16] == 4'hA)")
 s=replace(s,'& ~ems_hit & ~ec00_loaded &','& ~ems_hit & ~(ec00_loaded | enable_a000h) &')
 s=replace(s,"phys    = PHYS_ROM_BANK + {5'd0, ROM_EC00[19:14], address[13:0]};","phys    = PHYS_ROM_BANK + (enable_a000h ? {5'd0, ROM_TANDY_BIOS[19:16], 2'b00, address[13:0]} : {5'd0, ROM_EC00[19:14], address[13:0]});");s=replace(s,"PHYS_CGA + {11'd0, address[13:0]}","PHYS_CGA + {10'd0, address[14:0]}")
 p.write_text(s)
 # boot.rom is the 64 KiB BIOS followed by the 16 KiB Winchester ROM.
 p=OUT/'rtl/mem/rom_loader.sv';s=p.read_text()
 s=replace(s,"wire sel_ec00  = (ioctl_index == 8'd2);","wire sel_ec00  = (ioctl_index == 8'd2);\n    wire sel_hdd   = (ioctl_index[5:0] == 6'd0) && (ioctl_addr[24:14] == 11'd4);")
 s=replace(s,'wire selected  = sel_pcxt |','wire selected  = sel_hdd | sel_pcxt |')
 s=replace(s,"+ (sel_ec00  ? {5'd0, ROM_EC00[19:14], ioctl_addr[13:0]} :","+ (sel_hdd   ? {5'd0, ROM_TANDY_BIOS[19:16], 2'b00, ioctl_addr[13:0]} :\n                        sel_ec00  ? {5'd0, ROM_EC00[19:14], ioctl_addr[13:0]} :")
 p.write_text(s)
 # The uPD765 reads the sector it is asked for whatever EOT says (EOT only ends a multi-sector transfer):
 # a nine-sector disk is read a sector at a time under the BIOS's eight-sector table, as on the Junior.
 p=OUT/'rtl/common/floppy.v';s=p.read_text()
 s=replace(s,' || command[31:24] > command[15:8]);',');')
 p.write_text(s)
 # Only CPU cycles may use the 8086 word path; DMA is always eight bits.
 for name in ['Chipset.sv','Peripherals.sv']:
  p=OUT/'rtl/KFPC-XT/HDL'/name;s=p.read_text()
  s=replace(s,'input   logic           clk_uart,','input logic junior_b_rx,junior_b_cts,junior_b_dcd,junior_b_dsr, input logic [15:0] junior_cfg,\n        output logic junior_b_tx,junior_b_rts,junior_b_dtr,\n        input   logic           clk_uart,')
  if name=='Chipset.sv':s=replace(s,'.clk_uart                           (clk_uart),','.junior_b_rx(junior_b_rx), .junior_b_cts(junior_b_cts), .junior_b_dcd(junior_b_dcd), .junior_b_dsr(junior_b_dsr),\n        .junior_b_tx(junior_b_tx), .junior_b_rts(junior_b_rts), .junior_b_dtr(junior_b_dtr), .junior_cfg(junior_cfg),\n        .clk_uart                           (clk_uart),')
  p.write_text(s)
 p=OUT/'rtl/KFPC-XT/HDL/Chipset.sv';s=p.read_text()
 s=replace(s,'.word_read_request                  (word_read_request),','.word_read_request                  (word_read_request && !address_enable_n),')
 s=replace(s,'.word_write_request                 (word_write_request),','.word_write_request                 (word_write_request && !address_enable_n),')
 s=replace(s,'    READY u_READY',"""    // The original serial adapter inserts one 8086 wait state (210 ns).
    wire junior_io_cycle = !address_enable_n && address[15:4]==12'h025 && (!io_read_n || !io_write_n);
    reg [3:0] junior_wait_count=0;
    always @(posedge clock) begin
        if(reset || !junior_io_cycle)junior_wait_count<=0;
        else if(junior_wait_count<11)junior_wait_count<=junior_wait_count+1'b1;
    end
    wire junior_io_ready = !junior_io_cycle || junior_wait_count>=11;
    READY u_READY""")
 s=replace(s,'io_channel_ready & memory_access_ready','io_channel_ready & junior_io_ready & memory_access_ready')
 p.write_text(s)
 # The two 8250 ports are absent on JUNIOR. Its native SIO board is at 250h.
 p=OUT/'rtl/KFPC-XT/HDL/Peripherals.sv';s=p.read_text()
 s=replace(s,'wire    joystick_select         = (',"wire    joystick_select         = junior_cfg[3] && (")
 s=replace(s,'wire    xtctl_chip_select       = (',"wire    xtctl_chip_select       = 1'b0 && (")
 s=replace(s,'wire    uart_chip_select        = (',"wire pc2_tx,pc2_rts_n,pc2_dtr_n;\n    wire    uart_chip_select        = junior_cfg[1] && (")
 s=replace(s,'wire    uart2_chip_select       = (',"wire    uart2_chip_select       = junior_cfg[2] && (")
 # Printer port: 378h on the serial and parallel adapter, 3BCh on the monochrome coupler. Fixed disk at 300h.
 s=replace(s,"address[15:1] == (16'h0378 >> 1)); // 0x378 ... 0x379","((junior_cfg[0] && address[15:1] == (16'h0378 >> 1)) || (junior_cfg[7] && address[15:1] == (16'h03BC >> 1))));")
 s=replace(s,"address[15:0] == 16'h037A); // 0x37A","((junior_cfg[0] && address[15:0] == 16'h037A) || (junior_cfg[7] && address[15:0] == 16'h03BE)));")
 s=replace(s,"wire    ide0_chip_select_n      = ~(iorq &&","wire    ide0_chip_select_n      = ~(junior_cfg[4] && iorq &&")
 s=replace(s,"(`ENABLE_HGC ? (`ENABLE_CGA ? (swap_video & ~tandy_video_en) : ~tandy_video_en) : 1'b0);","video_output; // one display coupler, chosen in the menu")
 s=replace(s,'.composite(composite_cga),','.composite(composite_cga), .monitor(junior_cfg[6:5]),')
 anchor='    // Timing of the readings may need to be reviewed.'
 s=replace(s,anchor,(ROOT/'mister/serial.sv').read_text()+'\n'+anchor)
 s=replace(s,'pcjr_en ? uart2_interrupt : uart_interrupt,','junior_cfg[0] ? junior_irq : (junior_cfg[1] & uart_interrupt),')
 s=replace(s,'pcjr_en ? uart_interrupt : uart2_interrupt,','junior_cfg[2] & uart2_interrupt,')
 s=replace(s,'else if ((uart_chip_select) && (~io_read_n))',"else if (junior_selected && (~io_read_n)) begin data_bus_out_from_chipset <= 1'b1; data_bus_out <= junior_data; end\n        else if ((uart_chip_select) && (~io_read_n))")
 # MiSTer's serial bridge is SIO channel A or COM2 (mister/serial.sv).
 s=replace(s,'.tx                (uart2_tx),','.tx                (pc2_tx),')
 s=replace(s,'.rts_n             (uart2_rts_n),','.rts_n             (pc2_rts_n),')
 s=replace(s,'.dtr_n             (uart2_dtr_n),','.dtr_n             (pc2_dtr_n),')
 p.write_text(s)
 p=OUT/'rtl/video/cga.v';s=p.read_text()
 s=replace(s,": (`ENABLE_TANDY_VIDEO && tandy_video) ? (grph_mode ? row_addr[1] : 1'b0) : 1'b0;",": (`ENABLE_TANDY_VIDEO && tandy_video) ? (grph_mode ? row_addr[1] : 1'b0) : crtc_addr[13];")
 s=replace(s,": (`ENABLE_TANDY_VIDEO && tandy_video) ? (grph_mode ? row_addr_next[1] : 1'b0) : 1'b0;",": (`ENABLE_TANDY_VIDEO && tandy_video) ? (grph_mode ? row_addr_next[1] : 1'b0) : crtc_addr_next[13];")
 p.write_text(s)
 # CGA monitors from the card's output stages (schematic sheet 10): RGBI connector, RGB jacks, composite jack.
 p=OUT/'rtl/video/cga_vgaport.v';s=p.read_text()
 s=replace(s,'    input  wire       composite,','    input  wire       composite,\n    input  wire [1:0] monitor,')
 s=replace(s,'color_out <= rgbi_color(video);','color_out <= junior_color(monitor, video);')
 s=replace(s,'    function [5:0] clamp6;',(ROOT/'mister/monitor.sv').read_text()+'\n    function [5:0] clamp6;')
 p.write_text(s)
 shutil.copyfile(ROOT/'assets/hgc.hex',OUT/'rtl/video/hgc.hex')
 # Both font banks contain the original 256 x 8 JUNIOR EPROM.
 shutil.copyfile(ROOT/'assets/cga.hex',OUT/'rtl/video/cga.hex')
 q=(OUT/'PCXT.qsf').read_text();q=re.sub(r'set_global_assignment -name NUM_PARALLEL_PROCESSORS .*','',q)
 q+='\nset_global_assignment -name NUM_PARALLEL_PROCESSORS 8\n'
 (OUT/'JUNIORXT.qsf').write_text(q);(OUT/'JUNIORXT.qpf').write_text('QUARTUS_VERSION = "17.0"\nPROJECT_REVISION = "JUNIORXT"\n')
 with (OUT/'files.qip').open('a') as f:
  for p in sorted((ROOT/'rtl').glob('*.sv')):f.write('\nset_global_assignment -name SYSTEMVERILOG_FILE rtl/'+p.name+'\n')
 (OUT/'inputs.json').write_text(json.dumps({'model':'JUNIOR-XT','project_sources':source_hashes(),'upstream_commit':dep['pcxt']['commit'],'quartus_image':dep['quartus_image']},indent=2)+'\n')
if __name__=='__main__':main()
