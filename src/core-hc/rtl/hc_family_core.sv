// SPDX-License-Identifier: GPL-3.0-or-later
// Shared Z80, RAM and disk hardware for all six HC family profiles.
module hc_family_core #(parameter FAST_DISK=0)(
 input wire clk,reset,video_reset,input wire [2:0] model_select,input wire interface_enable,ay_enable,boot_cpm,input wire [4:0] joystick,input wire network_rx,output wire network_tx,output wire [9:0] psg_audio,input wire [39:0] keys_n,input wire ear,
 input wire rom_wr,input wire [15:0] rom_addr,input wire [7:0] rom_data,
 input wire [1:0] img_mounted,input wire img_wp,input wire [31:0] img_size,
 output wire [31:0] sd_lba,output wire [1:0] sd_rd,sd_wr,input wire sd_ack,
 input wire [8:0] sd_buff_addr,input wire [7:0] sd_buff_dout,output wire [7:0] sd_buff_din,input wire sd_buff_wr,
 input wire serial_rx,serial_ready,output wire serial_tx,serial_cts,
 output wire ce_pixel,ce_tape,tape_48k,output wire [2:0] rgb,output wire bright,
 output wire hs,vs,hblank,vblank,output reg beeper,mic,
 output wire [9:0] video_x,output wire [8:0] video_y,
 output wire [15:0] debug_pc,debug_addr,output wire [7:0] debug_data,debug_in,
 output wire [7:0] debug_char,output wire debug_fetch,
 output wire debug_mem_wr,debug_io_wr,debug_cpu_p,debug_stall,
 output wire [5:0] debug_command,input wire [15:0] peek_address,
 output wire [7:0] peek_ram,peek_vram
);

 wire is88=model_select==3,is128=model_select==4,is2000=model_select==5;
 wire is85=model_select==0;
 wire expanded=!is88 && (interface_enable || is2000);
 wire configurable=model_select==1 || model_select==2 || is128 || is2000;
 wire cpm_firmware=configurable && expanded && configuration[0];
 wire banked128=is128 && !cpm_firmware;
 reg [5:0] phase=0;reg [2:0] fdc_phase=0;
 always @(posedge clk)if(video_reset)begin phase<=0;fdc_phase<=0;end
 else begin phase<=phase+1'b1;fdc_phase<=fdc_phase==6?0:fdc_phase+1'b1;end
 assign ce_tape=phase[3:0]==15;
 wire [15:0] a;wire [7:0] d;reg [7:0] di;
 wire mreq_n,iorq_n,rd_n,wr_n,m1_n,rfsh_n;wire [211:0] registers;
 // Lossless 256-byte page dictionary. The host uploads table + original bytes.
 reg [7:0] page_table[0:1023];reg [7:0] rom[0:64511];
 reg [7:0] page_q,rom_q,ram_q,interface_q,video_q,attribute_q;reg rom_valid=0;
 reg [7:0] ram[0:131071],screen[0:32767],attributes[0:2047],interface_ram[0:1023];
 reg [5:0] command=0;reg shadow=0,phantom=0,cpm=0;
 reg [7:0] paging=0,configuration=0,floppy=0,serial=8'hff,network=8'hff;
 wire io=!iorq_n && m1_n;
 wire fetch=!mreq_n && !m1_n && !rd_n;
 wire entry_fetch=fetch && (!is128 || paging[4] || cpm_firmware) && (a[15:3]==13'h001 || a[15:3]==13'h2e1);
 wire if_active=expanded && !is88 && (phantom || entry_fetch) && !(configurable && configuration[1]);
 wire if_select=if_active && a[15:14]==0;
 wire if_ram=if_select && a[13] && a[11] && (!is85 || !a[12]);
 wire rom_select=is88?(a[15:14]==0 && !command[0]):
  if_select?!if_ram:configurable?(configuration[1] ? a[15:13]==7 : a[15:14]==0):a[15:14]==0;
 wire video_select=is88 && (command[3] || (!command[5] && a[15:14]==1));
 wire lock_write=is88 && a[15:14]==0 && command[1] && !shadow;
 reg [16:0] ram_address;reg [17:0] rom_address;
 always @*begin
  case(a[15:14])
   0:ram_address={3'd3,a[13:0]};
   1:ram_address={3'd5,a[13:0]};
   2:ram_address={3'd2,a[13:0]};
   3:ram_address={banked128?paging[2:0]:3'd0,a[13:0]};
  endcase
  if(is88)ram_address=video_select?{3'd5,a[13:0]}:{1'b0,(shadow && a[15:14]==0)?{2'b01,a[13:0]}:a};
  if(configurable && cpm && a[15:13]==6)ram_address[13]=1;
  rom_address={4'd0,a[13:0]}+(is85?18'd0:model_select==1?18'd16384:18'd32768);
  if(is88)rom_address=18'd49152+{7'd0,a[10:0]};
  if(is128)rom_address=18'd51200+{3'd0,paging[4],a[13:0]};
  if(is2000)rom_address=18'd83968+{3'd0,configuration[0],a[13:0]};
  if(cpm_firmware)rom_address=(is2000?18'd100352:18'd143360)+{4'd0,a[13:0]};
  if(if_select)rom_address=(is85?18'd116736:18'd126976)+{4'd0,a[13:0]};
 end
 wire [13:0] old_video_address,bitmap_address,attribute_address;
 wire display_page=banked128?paging[3]:configurable?configuration[3]:1'b0;
 wire [14:0] display_address=is88?{1'b0,bitmap_address}:{display_page,old_video_address};
 wire memory_write=!reset && !mreq_n && !wr_n && rfsh_n;
 wire ram_write=memory_write && !rom_select && !if_ram && !lock_write;
 always @(posedge clk)begin
  if(rom_wr)begin
   if(rom_addr<1024)page_table[rom_addr[9:0]]<=rom_data;
   else if({1'b0,rom_addr}<17'd65536)rom[rom_addr-1024]<=rom_data;
  end
  page_q<=page_table[rom_address[17:8]];
  rom_q<=rom[{page_q,rom_address[7:0]}];rom_valid<=page_q<252;ram_q<=ram[ram_address];interface_q<=interface_ram[a[9:0]];
  video_q<=screen[display_address];
  attribute_q<=attributes[{attribute_address[13],attribute_address[9:0]}];
  if(memory_write && if_ram)interface_ram[a[9:0]]<=d;
  if(ram_write)begin
   ram[ram_address]<=d;
   if(ram_address[16:14]==5 || ram_address[16:14]==7 || (configurable && !banked128 && ram_address[16:14]==0))
    screen[{ram_address[16:14]!=5,ram_address[13:0]}]<=d;
   if(is88 && ram_address[16:14]==5 && ram_address[12:10]==6)
    attributes[{ram_address[13],ram_address[9:0]}]<=d;
  end
 end
 // Use a single read port on the screen mirror for both raster generators.
 // HC-88 reads attributes separately; its bitmap uses the same mirror port.
 wire [7:0] raster_data=video_q;
 wire fe_select=io && !a[0] && (is88?(a[7] && a[6]):is85?a[6]:a[7]);
 wire disk_select=expanded && io && (a[7:0]==8'h85 || a[7:0]==8'h87);
 wire native_disk_select=is88 && io && a[7] && a[6] && a[0] && !a[5];
 wire disk_control=expanded && io && a[7:2]==1 && a[0];
 wire native_control=is88 && io && a[7] && !a[4] && !a[3];
 wire ef_select=io && (is88?(a[7] && !a[4] && a[3]):a[7:0]==8'hef);
 wire f7_select=io && (is88?(a[7] && a[4] && !a[3]):a[7:0]==8'hf7);
 reg old_io_write=0,old_fetch=0;reg [15:0] io_address;reg [7:0] io_data;
 wire iow=io && !wr_n;wire write_done=old_io_write && !iow;
 reg [2:0] border=0;reg [26:0] motor_ticks=0;wire motor=motor_ticks!=0;
 reg network_wait=0;
 wire network_active=network_rx || network_tx;
 wire serial_mode=is88?network[0]:serial[0];
 wire serial_data=is88?serial[0]:network[0];
 assign network_tx=(expanded || is88) && !serial_mode && !serial_data;
 always @(posedge clk)begin
  old_io_write<=iow;old_fetch<=fetch;
  if(iow)begin io_address<=a;io_data<=d;end
  if(reset)begin
   command<=0;shadow<=0;phantom<=0;cpm<=0;paging<=0;configuration<=(configurable && expanded && (boot_cpm || (is128 && !keys_n[0] && !keys_n[35])))?8'd1:8'd0;floppy<=0;
   serial<=is88?8'hff:8'hfe;network<=is88?8'h00:8'hff;border<=0;beeper<=0;mic<=0;motor_ticks<=0;network_wait<=0;
  end else begin
   if(motor_ticks!=0)motor_ticks<=motor_ticks-1'b1;
   if(!network_active)network_wait<=0;
   if(fetch && !old_fetch)begin
    if(is88 && command[0])begin
     if(entry_fetch)shadow<=1;else if(a[15:3]==13'h0e0)shadow<=0;
    end
    if(expanded && !is88 && entry_fetch)phantom<=1;
   end
   // The 0700 opcode itself still comes from the interface; M1's trailing edge releases ROMCS.
   if(!fetch && old_fetch && debug_addr_saved[15:3]==13'h0e0)phantom<=0;
   if(write_done)begin
    if(is88 && io_address[7] && !io_address[6] && io_address[0])begin command<=io_data[5:0];if(!io_data[0])shadow<=0;end
    if(!io_address[0] && (is88?(io_address[7] && io_address[6]):is85?io_address[6]:io_address[7]))begin border<=io_data[2:0];mic<=io_data[3];beeper<=io_data[4];end
    if((is88 && io_address[7] && !io_address[4] && !io_address[3]) || (expanded && io_address[7:2]==1 && io_address[0]))begin
     floppy<=io_data;if(io_data[3])motor_ticks<=27'd95200000;
    end
    if((is88 && io_address[7] && !io_address[4] && io_address[3]) || (expanded && io_address[7:0]==8'hef))begin
     serial<=io_data;if(!is88 && !io_data[5] && network_active)network_wait<=1;
    end
    if((is88 && io_address[7] && io_address[4] && !io_address[3]) || (expanded && io_address[7:0]==8'hf7))begin network<=io_data;if(is88 && !io_data[5] && network_active)network_wait<=1;end
    if(is128 && !paging[5] && !io_address[15] && !io_address[1])paging<=io_data;
    if(configurable && !configuration[2] && io_address[7:0]==8'h7e)configuration<=io_data;
    if(expanded && io_address[7:0]==8'hc5)cpm<=0;
    if(expanded && io_address[7:0]==8'hc7)cpm<=1;
   end
  end
 end
 reg [15:0] debug_addr_saved;
 always @(posedge clk)if(fetch)debug_addr_saved<=a;
 reg [4:0] keyboard;integer row;
 always @*begin keyboard=31;for(row=0;row<8;row=row+1)if(!a[8+row])keyboard=keyboard & keys_n[row*5+:5];end
 wire video_access=!mreq_n && (is88?video_select:a[15:14]==1);
 wire clock_allowed=!(is85 || is88) || !video_access || !phase[5];
 wire cpu_p=phase[3:0]==15 && clock_allowed,cpu_n=phase[3:0]==7 && clock_allowed;
 reg [1:0] mounted=0;
 always @(posedge clk)if(video_reset)mounted<=0;
 else begin if(img_mounted[0])mounted[0]<=img_size!=0;if(img_mounted[1])mounted[1]<=img_size!=0;end
 wire [1:0] selected={floppy[2],floppy[1]};wire [7:0] disk_data;
 hc88_u765 #(.CYCLES(4000)) disk(.clk_sys(clk),.ce(fdc_phase==6),.reset(reset || !floppy[4]),
 .tc(floppy[0]),.drq(),.irq(),.ready(mounted & selected),.motor({2{motor}} & selected),.available(mounted & selected),.fast(FAST_DISK!=0),
 .a0(a[1]),.nRD(!((native_disk_select || disk_select) && !rd_n)),.nWR(!((native_disk_select || disk_select) && !wr_n)),.din(d),.dout(disk_data),
 .img_mounted(img_mounted),.img_wp(img_wp),.img_size(img_size),.sd_lba(sd_lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(sd_ack),
 .sd_buff_addr(sd_buff_addr),.sd_buff_dout(sd_buff_dout),.sd_buff_din(sd_buff_din),.sd_buff_wr(sd_buff_wr));
 // AY-3-8912: built into the HC-128 (xxFD with A15 high and A1 low); on the other Spectrum-map models it is the
 // expansion-connector sound board, which decodes the whole low byte FD to stay clear of the HC's own ports.
 wire ay_select=ay_enable && !is88 && io && a[15] && (banked128?!a[1]:a[7:0]==8'hfd);
 wire [7:0] ay_data,channel_a,channel_b,channel_c;
 HC_AY sound(.CLK(clk),.CE(phase[4:0]==31),.RESET(reset || is88 || !ay_enable),
 .BDIR(ay_select && !wr_n),.BC(a[14]),.DI(d),.DO(ay_data),
 .CHANNEL_A(channel_a),.CHANNEL_B(channel_b),.CHANNEL_C(channel_c),.LEVEL_A(),.LEVEL_B(),.LEVEL_C(),
 .SEL(1'b0),.MODE(1'b1),.ACTIVE(),.IOA_in(8'hff),.IOA_out(),.IOB_in(8'hff),.IOB_out());
 assign psg_audio=ay_enable && !is88?{2'd0,channel_a}+{2'd0,channel_b}+{2'd0,channel_c}:10'd0;
 always @*begin
  di=8'hff;
  if(!mreq_n)di=if_ram?interface_q:rom_select?((if_select && is85 && a>=16'h2800)?8'hff:(rom_valid?rom_q:8'hff)):ram_q;
  else if(io && !rd_n)begin
   if(fe_select)di={1'b1,ear,1'b1,keyboard};
   if(native_disk_select || disk_select)di=disk_data;
   if((expanded || is88) && ef_select)begin di[3]=serial_ready;if(!is88)di[0]=network_active;end
   if((expanded || is88) && f7_select)begin di[7]=!serial_rx;di[0]=is88?network_active:1'b1;end
   if(native_control || disk_control)di[0]=!motor;
   if(configurable && a[7:0]==8'h7e)di=configuration;
   if(ay_select && a[14])di=ay_data;
   if(a[7:0]==8'h1f)di={3'd0,joystick};
  end
 end
 wire interrupt_active=video_y==248 && (is88 && command[4]?video_x<128:video_x<64);
 T80pa cpu(.RESET_n(!reset),.CLK(clk),.CEN_p(cpu_p),.CEN_n(cpu_n),.WAIT_n(!network_wait),
 .INT_n(!interrupt_active),.NMI_n(1'b1),.BUSRQ_n(1'b1),
 .M1_n(m1_n),.MREQ_n(mreq_n),.IORQ_n(iorq_n),.RD_n(rd_n),.WR_n(wr_n),.RFSH_n(rfsh_n),.HALT_n(),.BUSAK_n(),
 .OUT0(1'b0),.A(a),.DI(di),.DO(d),.R800_mode(1'b0),.REG(registers),.DIRSet(1'b0),.DIR(212'd0));
 wire old_ce=phase[2:0]==7;wire [2:0] old_rgb,new_rgb;wire old_bright,new_bright;
 wire old_hs,old_vs,old_hb,old_vb,new_hs,new_vs,new_hb,new_vb,new_ce;
 wire [8:0] old_x,old_y,new_y;wire [9:0] new_x;
 hc85_video #(.DYNAMIC_BRIGHT(1)) legacy_video(.clk(clk),.reset(video_reset),.ce_pixel(old_ce),.border(border),.bright_enable(!is85),
 .ram_addr(old_video_address),.ram_data(raster_data),.rgb(old_rgb),.bright(old_bright),.hs(old_hs),.vs(old_vs),.hblank(old_hb),.vblank(old_vb),.x(old_x),.y(old_y),.flash_count());
 hc88_video native_video(.clk(clk),.reset(video_reset),.dot(phase[1:0]==3),.hires(command[4]),.border(border),
 .bitmap_address(bitmap_address),.attribute_address(attribute_address),.bitmap(raster_data),.attribute(attribute_q),
 .ce_pixel(new_ce),.rgb(new_rgb),.bright(new_bright),.hs(new_hs),.vs(new_vs),.hblank(new_hb),.vblank(new_vb),.x(new_x),.y(new_y));
 assign ce_pixel=is88?new_ce:old_ce;assign rgb=is88?new_rgb:old_rgb;assign bright=is88?new_bright:old_bright;
 assign hs=is88?new_hs:old_hs;assign vs=is88?new_vs:old_vs;assign hblank=is88?new_hb:old_hb;assign vblank=is88?new_vb:old_vb;
 assign video_x=is88?new_x:{1'b0,old_x};assign video_y=is88?new_y:old_y;
 assign serial_tx=(expanded || is88) && serial_mode?!serial_data:1'b1;assign serial_cts=(expanded || is88)?~serial[4]:1'b1;
 assign debug_pc=registers[79:64];assign debug_addr=a;assign debug_data=d;assign debug_in=di;
 assign debug_mem_wr=!mreq_n && !wr_n;assign debug_io_wr=iow;assign debug_cpu_p=cpu_p;assign debug_stall=video_access && !clock_allowed;
 assign debug_command=is88?command:{5'd0,phantom};
 assign tape_48k=!is128 || paging[5] || cpm_firmware;assign debug_char=registers[87:80];assign debug_fetch=fetch;
 `ifdef VERILATOR
 assign peek_ram=ram[is88?{1'b0,peek_address}:peek_address[15:14]==0?{3'd3,peek_address[13:0]}:peek_address[15:14]==1?{3'd5,peek_address[13:0]}:peek_address[15:14]==2?{3'd2,peek_address[13:0]}:{banked128?paging[2:0]:3'd0,peek_address[13:0]}];
 assign peek_vram=ram[{3'd5,peek_address[13:0]}];
 `else
 assign peek_ram=0;assign peek_vram=0;
 `endif
endmodule
