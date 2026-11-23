// SPDX-License-Identifier: GPL-3.0-or-later
module hc_expansion_bus_tb #(parameter MODEL=4);
 reg clk=0,reset=1,wr=0;reg [15:0] address=0;reg [7:0] byte_in=0;
 reg peer=0,peer_used=0;integer wait_ticks=0;reg [15:0] wait_pc=0;
 wire serial_tx,serial_cts;wire [7:0] result;reg [15:0] peek=0;wire [15:0] pc;wire [9:0] sound;
 reg [7:0] firmware[0:65535];integer i,audio_edges;reg [9:0] prior_sound;
 always #5 clk=~clk;
 hc_family_core dut(.clk(clk),.reset(reset),.video_reset(reset),.model_select(3'(MODEL)),.interface_enable(MODEL!=4),.ay_enable(1'b1),.boot_cpm(1'b0),
 .keys_n(40'hffffffffff),.joystick(5'd21),.ear(1'b1),.network_rx(peer),.serial_tx(serial_tx),.serial_cts(serial_cts),.psg_audio(sound),
 .rom_wr(wr),.rom_addr(address),.rom_data(byte_in),.img_mounted(2'd0),.img_size(32'd0),.img_wp(1'b1),
 .sd_ack(1'b0),.sd_buff_addr(9'd0),.sd_buff_dout(8'd0),.sd_buff_wr(1'b0),.serial_rx(1'b0),.serial_ready(1'b1),
 .peek_address(peek),.peek_ram(result),.debug_pc(pc));
 always @(negedge clk)begin
  if(MODEL<3 && !reset)begin
   if(dut.iow && dut.a[7:0]==8'hef && dut.d==0 && !peer_used)begin peer=1;peer_used=1;end
   if(dut.network_wait)begin
    wait_ticks=wait_ticks+1;
    if(wait_ticks==80)wait_pc=pc;
    if(wait_ticks>160 && pc!=wait_pc)$fatal(1,"Network WAIT did not hold the CPU");
    if(wait_ticks==1000)peer=0;
   end
   if(dut.serial==8'h31 && dut.network==0 && (!serial_tx || serial_cts))$fatal(1,"UART stop/ready polarity");
  end
 end
 initial begin
  $readmemh("build/expansion-bus-firmware.hex",firmware);
  repeat(4)@(negedge clk);
  for(i=0;i<65536;i=i+1)begin wr=1;address=i;byte_in=firmware[i];@(negedge clk);end
  wr=0;reset=0;peek=16'h90ff;
  repeat(200000)begin @(negedge clk);if(result==8'h5a)begin
   if(MODEL==4)begin
   for(i=0;i<8;i=i+1)begin peek=16'h9000+i;#1;if(result!=(i==0?8'h6e:8'h40+i))$fatal(1,"128K bank alias %d -> %h",i,result);end
   if(dut.screen[0]!=8'h45 || dut.screen[16'h4000]!=8'h47)$fatal(1,"RAM bank 0 corrupted screen 7");
   peek=16'h9008;#1;if(result!=8'h47 || dut.paging!=8'h3f)$fatal(1,"Paging lock or ROM/screen selection failed");
   peek=16'h9009;#1;if(result!=15)$fatal(1,"AY register read failed %h",result);
   audio_edges=0;prior_sound=sound;
   repeat(20000)begin @(negedge clk);if(sound!=prior_sound)audio_edges=audio_edges+1;prior_sound=sound;end
   if(audio_edges<4)$fatal(1,"AY tone did not reach the audio output");
   if(dut.rom_select || dut.ram_address[16:14]!=2)$fatal(1,"Fixed RAM page changed");
   $display("PASS: native Z80 exercises all eight RAM banks, ROM/screen select, paging lock and AY");
   end else if(MODEL==5)begin
    for(i=0;i<6;i=i+1)begin peek=16'h9000+i;#1;
     case(i)
      0:if(result!=8'hbb)$fatal(1,"HC2000 ROM bank %h",result);
      1:if(result!=8'h66)$fatal(1,"HC2000 bottom RAM %h",result);
      2:if(result!=8'hcc)$fatal(1,"HC2000 top ROM %h",result);
      3:if(result!=8'h22)$fatal(1,"HC2000 CP/M alias %h",result);
      4:if(result!=8'h11)$fatal(1,"HC2000 alias release %h",result);
      5:if(result!=7)$fatal(1,"HC2000 config lock %h",result);
     endcase
    end
    $display("PASS: native HC2000 ROM banks, bottom RAM, top ROM, CP/M alias and config lock");
   end else begin
    for(i=0;i<11;i=i+1)begin peek=16'h9000+i;#1;
     case(i)
      0:if(result!=8'h55)$fatal(1,"IF1 RST8 trap or RAM mirror %h",result);
      1:if(result!=8'h77)$fatal(1,"IF1 1708 trap %h",result);
      2,4:if(result!=8'hf3)$fatal(1,"IF1 ROMCS release %h",result);
      3:if(result!=(MODEL==0?8'hf3:8'h66))$fatal(1,"IF1 CP/M low RAM %h",result);
      5:if(result!=8'hff)$fatal(1,"IF1 serial RX %h",result);
      6:if(!result[0] || !result[3])$fatal(1,"IF1 network or ready %h",result);
      7:if(result[0])$fatal(1,"IF1 network release %h",result);
      8:if(result[0])$fatal(1,"IF1 motor sense %h",result);
      9:if(!result[7])$fatal(1,"IF1 FDC RQM %h",result);
      10:if(result!=21)$fatal(1,"Kempston joystick %h",result);
     endcase
    end
    peek=16'h900b;#1;
    if(!peer_used || wait_ticks<1000 || result!=8'h6c)$fatal(1,"Network WAIT did not resume after peer release");
    if(dut.selected!=2)$fatal(1,"IF1 drive B select");
    $display("PASS: HC%0d native IF1 paging, RAM, CP/M, serial, network, motor, 8272 and joystick",MODEL);
   end
   $finish;
  end end
  $fatal(1,"Expansion bus program failed PC=%h",pc);
 end
endmodule
