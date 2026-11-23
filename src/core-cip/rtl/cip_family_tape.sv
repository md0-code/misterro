// SPDX-License-Identifier: GPL-3.0-or-later
// Host writes at 112 MHz; the original cassette engine runs at 56 MHz.
// Ready crosses through two registers after mode/length and buffer data settle.
module cip_family_tape #(parameter ADDR_BITS=18, parameter PLAYER_DIVIDER=16) (
 input wire clk,player_clk,reset,
 input wire mode48k,download,wr,
 input wire [26:0] address,
 input wire [7:0] data,
 input wire [1:0] mode,
 input wire pause,prev,next,
 output wire audio,active,available,
 output reg overflow=0
);
 reg[7:0] buffer[0:(1<<ADDR_BITS)-1];
 reg[7:0] read_q;
 wire[24:0] read_address;
 wire rd;
 reg was_download=0,ready=0;
 reg[24:0] length=0;
 reg[1:0] saved_mode=0;
 always @(posedge clk)begin
  was_download<=download;
  if(reset)begin ready<=0;overflow<=0;length<=0;end
  else begin
   if(download&&!was_download)begin ready<=0;overflow<=0;length<=0;saved_mode<=mode;end
   if(download&&wr)begin
    if(address<(1<<ADDR_BITS))begin buffer[address[ADDR_BITS-1:0]]<=data;length<=address[24:0]+1'b1;end
    else overflow<=1;
   end
   if(!download&&was_download)ready<=!overflow&&length!=0;
  end
 end
 localparam DIV_BITS=PLAYER_DIVIDER>1?$clog2(PLAYER_DIVIDER):1;
 reg[DIV_BITS-1:0] divider=0;
 wire ce=divider==PLAYER_DIVIDER-1;
 reg rd_en=0;
 reg[1:0] ready_sync=0;
 reg[3:0] controls_meta=0,controls_sync=0;
 reg previous_ready=0;
 reg[1:0] start_count=0;
 wire play_ready=ready_sync[1];
 reg[1:0] reset_sync=2'b11;
 reg[24:0] player_length=0;
 reg[1:0] player_mode=0;
 wire player_reset=reset_sync[1];
 always @(posedge player_clk)begin
  reset_sync<={reset_sync[0],reset};
  // Metadata is held stable before the synchronized ready edge and remains
  // local to the player throughout playback, including its RAM read enable.
  if(!play_ready)begin player_length<=length;player_mode<=saved_mode;end
  if(player_reset)begin divider<=0;ready_sync<=0;start_count<=0;previous_ready<=0;end
  else begin
   divider<=ce?0:divider+1'b1;
   ready_sync<={ready_sync[0],ready&&!download};
   previous_ready<=play_ready;
   if(!play_ready)start_count<=0;
   else if(!previous_ready)start_count<=3;
   else if(ce&&start_count!=0)start_count<=start_count-1'b1;
  end
  controls_meta<={mode48k,pause,prev,next};controls_sync<=controls_meta;
  rd_en<=~rd_en;
  if(rd)read_q<=buffer[read_address[ADDR_BITS-1:0]];
 end
 tape player(.clk_sys(player_clk),.ce(ce),.mode48k(controls_sync[3]),.turbo(1'b0),
  .byte_wait(1'b0),.byte_ready(),.dout(),.pause(controls_sync[2]||start_count==2),
  .prev(controls_sync[1]),.next(controls_sync[0]),.active(active),.available(available),
  .tape_ready(play_ready&&!player_reset),.tape_mode(player_mode),.tape_size(player_length),
  .stdload(1'b0),.loader(1'b0),.req_hdr(1'b0),.audio_out(audio),
  .rd_en(rd_en),.rd(rd),.addr(read_address),.din(read_q));
endmodule
