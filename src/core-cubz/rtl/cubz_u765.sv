// CUB Z derivative: DMA DRQ/TC and optional interrupt output. See docs/hardware.md.
// ====================================================================
//
//  NEC u765 FDC
//
//  Copyright (C) 2017 Gyorgy Szombathelyi <gyurco@freemail.hu>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

//TODO:
//GAP, CRC generation
//WRITE DELETE should write the Deleted Address Mark to the SectorInfo
//SCAN commands
//real FORMAT (but this would require squeezing/expanding the image file)

//for accurate head stepping rate, set CYCLES to cycles/ms
//8MHz = 4000 (default)
//SPECCY_SPEEDLOCK_HACK: auto mess-up weak sector on C0H0S2
module cubz_u765 #(parameter CYCLES = 20'd4000, SPECCY_SPEEDLOCK_HACK = 0)
(
	input            clk_sys,   // sys clock
	input            ce,        // chip enable
	input            tc,
	output           drq,
	output           irq,
	input            reset,	    // reset
	input      [1:0] ready,     // disk is inserted in MiST(er)
	input      [1:0] motor,     // drive motor
	input      [1:0] available, // drive available (fake ready signal for SENSE DRIVE command)
	input            fast,      // "Fast" mode - immediate seek and sector read/write
	input            a0,
	input            nRD,       // i/o read
	input            nWR,       // i/o write
	input      [7:0] din,       // i/o data in
	output     [7:0] dout,      // i/o data out

	input      [1:0] img_mounted, // signaling that new image has been mounted
	input            img_wp,      // write protect. latched at img_mounted
	input     [31:0] img_size,    // size of image in bytes
	output reg [31:0] sd_lba,
	output reg [1:0] sd_rd,
	output reg [1:0] sd_wr,
	input            sd_ack,
	input      [8:0] sd_buff_addr,
	input      [7:0] sd_buff_dout,
	output     [7:0] sd_buff_din,
	input            sd_buff_wr
);

//localparam OVERRUN_TIMEOUT = 26'd35000000;
localparam OVERRUN_TIMEOUT = CYCLES * 8'd10;
localparam [31:0] TRACK_TIME = CYCLES*8'd200;

// Compile-time division table: exact original rotation periods without a
// long combinational divider in the 40 MHz datapath. Sector counts are bytes.
function automatic [31:0] sector_period(input [7:0] sectors);
 begin
  case(sectors)
   8'd1: sector_period = TRACK_TIME / 32'd1;
   8'd2: sector_period = TRACK_TIME / 32'd2;
   8'd3: sector_period = TRACK_TIME / 32'd3;
   8'd4: sector_period = TRACK_TIME / 32'd4;
   8'd5: sector_period = TRACK_TIME / 32'd5;
   8'd6: sector_period = TRACK_TIME / 32'd6;
   8'd7: sector_period = TRACK_TIME / 32'd7;
   8'd8: sector_period = TRACK_TIME / 32'd8;
   8'd9: sector_period = TRACK_TIME / 32'd9;
   8'd10: sector_period = TRACK_TIME / 32'd10;
   8'd11: sector_period = TRACK_TIME / 32'd11;
   8'd12: sector_period = TRACK_TIME / 32'd12;
   8'd13: sector_period = TRACK_TIME / 32'd13;
   8'd14: sector_period = TRACK_TIME / 32'd14;
   8'd15: sector_period = TRACK_TIME / 32'd15;
   8'd16: sector_period = TRACK_TIME / 32'd16;
   8'd17: sector_period = TRACK_TIME / 32'd17;
   8'd18: sector_period = TRACK_TIME / 32'd18;
   8'd19: sector_period = TRACK_TIME / 32'd19;
   8'd20: sector_period = TRACK_TIME / 32'd20;
   8'd21: sector_period = TRACK_TIME / 32'd21;
   8'd22: sector_period = TRACK_TIME / 32'd22;
   8'd23: sector_period = TRACK_TIME / 32'd23;
   8'd24: sector_period = TRACK_TIME / 32'd24;
   8'd25: sector_period = TRACK_TIME / 32'd25;
   8'd26: sector_period = TRACK_TIME / 32'd26;
   8'd27: sector_period = TRACK_TIME / 32'd27;
   8'd28: sector_period = TRACK_TIME / 32'd28;
   8'd29: sector_period = TRACK_TIME / 32'd29;
   8'd30: sector_period = TRACK_TIME / 32'd30;
   8'd31: sector_period = TRACK_TIME / 32'd31;
   8'd32: sector_period = TRACK_TIME / 32'd32;
   8'd33: sector_period = TRACK_TIME / 32'd33;
   8'd34: sector_period = TRACK_TIME / 32'd34;
   8'd35: sector_period = TRACK_TIME / 32'd35;
   8'd36: sector_period = TRACK_TIME / 32'd36;
   8'd37: sector_period = TRACK_TIME / 32'd37;
   8'd38: sector_period = TRACK_TIME / 32'd38;
   8'd39: sector_period = TRACK_TIME / 32'd39;
   8'd40: sector_period = TRACK_TIME / 32'd40;
   8'd41: sector_period = TRACK_TIME / 32'd41;
   8'd42: sector_period = TRACK_TIME / 32'd42;
   8'd43: sector_period = TRACK_TIME / 32'd43;
   8'd44: sector_period = TRACK_TIME / 32'd44;
   8'd45: sector_period = TRACK_TIME / 32'd45;
   8'd46: sector_period = TRACK_TIME / 32'd46;
   8'd47: sector_period = TRACK_TIME / 32'd47;
   8'd48: sector_period = TRACK_TIME / 32'd48;
   8'd49: sector_period = TRACK_TIME / 32'd49;
   8'd50: sector_period = TRACK_TIME / 32'd50;
   8'd51: sector_period = TRACK_TIME / 32'd51;
   8'd52: sector_period = TRACK_TIME / 32'd52;
   8'd53: sector_period = TRACK_TIME / 32'd53;
   8'd54: sector_period = TRACK_TIME / 32'd54;
   8'd55: sector_period = TRACK_TIME / 32'd55;
   8'd56: sector_period = TRACK_TIME / 32'd56;
   8'd57: sector_period = TRACK_TIME / 32'd57;
   8'd58: sector_period = TRACK_TIME / 32'd58;
   8'd59: sector_period = TRACK_TIME / 32'd59;
   8'd60: sector_period = TRACK_TIME / 32'd60;
   8'd61: sector_period = TRACK_TIME / 32'd61;
   8'd62: sector_period = TRACK_TIME / 32'd62;
   8'd63: sector_period = TRACK_TIME / 32'd63;
   8'd64: sector_period = TRACK_TIME / 32'd64;
   8'd65: sector_period = TRACK_TIME / 32'd65;
   8'd66: sector_period = TRACK_TIME / 32'd66;
   8'd67: sector_period = TRACK_TIME / 32'd67;
   8'd68: sector_period = TRACK_TIME / 32'd68;
   8'd69: sector_period = TRACK_TIME / 32'd69;
   8'd70: sector_period = TRACK_TIME / 32'd70;
   8'd71: sector_period = TRACK_TIME / 32'd71;
   8'd72: sector_period = TRACK_TIME / 32'd72;
   8'd73: sector_period = TRACK_TIME / 32'd73;
   8'd74: sector_period = TRACK_TIME / 32'd74;
   8'd75: sector_period = TRACK_TIME / 32'd75;
   8'd76: sector_period = TRACK_TIME / 32'd76;
   8'd77: sector_period = TRACK_TIME / 32'd77;
   8'd78: sector_period = TRACK_TIME / 32'd78;
   8'd79: sector_period = TRACK_TIME / 32'd79;
   8'd80: sector_period = TRACK_TIME / 32'd80;
   8'd81: sector_period = TRACK_TIME / 32'd81;
   8'd82: sector_period = TRACK_TIME / 32'd82;
   8'd83: sector_period = TRACK_TIME / 32'd83;
   8'd84: sector_period = TRACK_TIME / 32'd84;
   8'd85: sector_period = TRACK_TIME / 32'd85;
   8'd86: sector_period = TRACK_TIME / 32'd86;
   8'd87: sector_period = TRACK_TIME / 32'd87;
   8'd88: sector_period = TRACK_TIME / 32'd88;
   8'd89: sector_period = TRACK_TIME / 32'd89;
   8'd90: sector_period = TRACK_TIME / 32'd90;
   8'd91: sector_period = TRACK_TIME / 32'd91;
   8'd92: sector_period = TRACK_TIME / 32'd92;
   8'd93: sector_period = TRACK_TIME / 32'd93;
   8'd94: sector_period = TRACK_TIME / 32'd94;
   8'd95: sector_period = TRACK_TIME / 32'd95;
   8'd96: sector_period = TRACK_TIME / 32'd96;
   8'd97: sector_period = TRACK_TIME / 32'd97;
   8'd98: sector_period = TRACK_TIME / 32'd98;
   8'd99: sector_period = TRACK_TIME / 32'd99;
   8'd100: sector_period = TRACK_TIME / 32'd100;
   8'd101: sector_period = TRACK_TIME / 32'd101;
   8'd102: sector_period = TRACK_TIME / 32'd102;
   8'd103: sector_period = TRACK_TIME / 32'd103;
   8'd104: sector_period = TRACK_TIME / 32'd104;
   8'd105: sector_period = TRACK_TIME / 32'd105;
   8'd106: sector_period = TRACK_TIME / 32'd106;
   8'd107: sector_period = TRACK_TIME / 32'd107;
   8'd108: sector_period = TRACK_TIME / 32'd108;
   8'd109: sector_period = TRACK_TIME / 32'd109;
   8'd110: sector_period = TRACK_TIME / 32'd110;
   8'd111: sector_period = TRACK_TIME / 32'd111;
   8'd112: sector_period = TRACK_TIME / 32'd112;
   8'd113: sector_period = TRACK_TIME / 32'd113;
   8'd114: sector_period = TRACK_TIME / 32'd114;
   8'd115: sector_period = TRACK_TIME / 32'd115;
   8'd116: sector_period = TRACK_TIME / 32'd116;
   8'd117: sector_period = TRACK_TIME / 32'd117;
   8'd118: sector_period = TRACK_TIME / 32'd118;
   8'd119: sector_period = TRACK_TIME / 32'd119;
   8'd120: sector_period = TRACK_TIME / 32'd120;
   8'd121: sector_period = TRACK_TIME / 32'd121;
   8'd122: sector_period = TRACK_TIME / 32'd122;
   8'd123: sector_period = TRACK_TIME / 32'd123;
   8'd124: sector_period = TRACK_TIME / 32'd124;
   8'd125: sector_period = TRACK_TIME / 32'd125;
   8'd126: sector_period = TRACK_TIME / 32'd126;
   8'd127: sector_period = TRACK_TIME / 32'd127;
   8'd128: sector_period = TRACK_TIME / 32'd128;
   8'd129: sector_period = TRACK_TIME / 32'd129;
   8'd130: sector_period = TRACK_TIME / 32'd130;
   8'd131: sector_period = TRACK_TIME / 32'd131;
   8'd132: sector_period = TRACK_TIME / 32'd132;
   8'd133: sector_period = TRACK_TIME / 32'd133;
   8'd134: sector_period = TRACK_TIME / 32'd134;
   8'd135: sector_period = TRACK_TIME / 32'd135;
   8'd136: sector_period = TRACK_TIME / 32'd136;
   8'd137: sector_period = TRACK_TIME / 32'd137;
   8'd138: sector_period = TRACK_TIME / 32'd138;
   8'd139: sector_period = TRACK_TIME / 32'd139;
   8'd140: sector_period = TRACK_TIME / 32'd140;
   8'd141: sector_period = TRACK_TIME / 32'd141;
   8'd142: sector_period = TRACK_TIME / 32'd142;
   8'd143: sector_period = TRACK_TIME / 32'd143;
   8'd144: sector_period = TRACK_TIME / 32'd144;
   8'd145: sector_period = TRACK_TIME / 32'd145;
   8'd146: sector_period = TRACK_TIME / 32'd146;
   8'd147: sector_period = TRACK_TIME / 32'd147;
   8'd148: sector_period = TRACK_TIME / 32'd148;
   8'd149: sector_period = TRACK_TIME / 32'd149;
   8'd150: sector_period = TRACK_TIME / 32'd150;
   8'd151: sector_period = TRACK_TIME / 32'd151;
   8'd152: sector_period = TRACK_TIME / 32'd152;
   8'd153: sector_period = TRACK_TIME / 32'd153;
   8'd154: sector_period = TRACK_TIME / 32'd154;
   8'd155: sector_period = TRACK_TIME / 32'd155;
   8'd156: sector_period = TRACK_TIME / 32'd156;
   8'd157: sector_period = TRACK_TIME / 32'd157;
   8'd158: sector_period = TRACK_TIME / 32'd158;
   8'd159: sector_period = TRACK_TIME / 32'd159;
   8'd160: sector_period = TRACK_TIME / 32'd160;
   8'd161: sector_period = TRACK_TIME / 32'd161;
   8'd162: sector_period = TRACK_TIME / 32'd162;
   8'd163: sector_period = TRACK_TIME / 32'd163;
   8'd164: sector_period = TRACK_TIME / 32'd164;
   8'd165: sector_period = TRACK_TIME / 32'd165;
   8'd166: sector_period = TRACK_TIME / 32'd166;
   8'd167: sector_period = TRACK_TIME / 32'd167;
   8'd168: sector_period = TRACK_TIME / 32'd168;
   8'd169: sector_period = TRACK_TIME / 32'd169;
   8'd170: sector_period = TRACK_TIME / 32'd170;
   8'd171: sector_period = TRACK_TIME / 32'd171;
   8'd172: sector_period = TRACK_TIME / 32'd172;
   8'd173: sector_period = TRACK_TIME / 32'd173;
   8'd174: sector_period = TRACK_TIME / 32'd174;
   8'd175: sector_period = TRACK_TIME / 32'd175;
   8'd176: sector_period = TRACK_TIME / 32'd176;
   8'd177: sector_period = TRACK_TIME / 32'd177;
   8'd178: sector_period = TRACK_TIME / 32'd178;
   8'd179: sector_period = TRACK_TIME / 32'd179;
   8'd180: sector_period = TRACK_TIME / 32'd180;
   8'd181: sector_period = TRACK_TIME / 32'd181;
   8'd182: sector_period = TRACK_TIME / 32'd182;
   8'd183: sector_period = TRACK_TIME / 32'd183;
   8'd184: sector_period = TRACK_TIME / 32'd184;
   8'd185: sector_period = TRACK_TIME / 32'd185;
   8'd186: sector_period = TRACK_TIME / 32'd186;
   8'd187: sector_period = TRACK_TIME / 32'd187;
   8'd188: sector_period = TRACK_TIME / 32'd188;
   8'd189: sector_period = TRACK_TIME / 32'd189;
   8'd190: sector_period = TRACK_TIME / 32'd190;
   8'd191: sector_period = TRACK_TIME / 32'd191;
   8'd192: sector_period = TRACK_TIME / 32'd192;
   8'd193: sector_period = TRACK_TIME / 32'd193;
   8'd194: sector_period = TRACK_TIME / 32'd194;
   8'd195: sector_period = TRACK_TIME / 32'd195;
   8'd196: sector_period = TRACK_TIME / 32'd196;
   8'd197: sector_period = TRACK_TIME / 32'd197;
   8'd198: sector_period = TRACK_TIME / 32'd198;
   8'd199: sector_period = TRACK_TIME / 32'd199;
   8'd200: sector_period = TRACK_TIME / 32'd200;
   8'd201: sector_period = TRACK_TIME / 32'd201;
   8'd202: sector_period = TRACK_TIME / 32'd202;
   8'd203: sector_period = TRACK_TIME / 32'd203;
   8'd204: sector_period = TRACK_TIME / 32'd204;
   8'd205: sector_period = TRACK_TIME / 32'd205;
   8'd206: sector_period = TRACK_TIME / 32'd206;
   8'd207: sector_period = TRACK_TIME / 32'd207;
   8'd208: sector_period = TRACK_TIME / 32'd208;
   8'd209: sector_period = TRACK_TIME / 32'd209;
   8'd210: sector_period = TRACK_TIME / 32'd210;
   8'd211: sector_period = TRACK_TIME / 32'd211;
   8'd212: sector_period = TRACK_TIME / 32'd212;
   8'd213: sector_period = TRACK_TIME / 32'd213;
   8'd214: sector_period = TRACK_TIME / 32'd214;
   8'd215: sector_period = TRACK_TIME / 32'd215;
   8'd216: sector_period = TRACK_TIME / 32'd216;
   8'd217: sector_period = TRACK_TIME / 32'd217;
   8'd218: sector_period = TRACK_TIME / 32'd218;
   8'd219: sector_period = TRACK_TIME / 32'd219;
   8'd220: sector_period = TRACK_TIME / 32'd220;
   8'd221: sector_period = TRACK_TIME / 32'd221;
   8'd222: sector_period = TRACK_TIME / 32'd222;
   8'd223: sector_period = TRACK_TIME / 32'd223;
   8'd224: sector_period = TRACK_TIME / 32'd224;
   8'd225: sector_period = TRACK_TIME / 32'd225;
   8'd226: sector_period = TRACK_TIME / 32'd226;
   8'd227: sector_period = TRACK_TIME / 32'd227;
   8'd228: sector_period = TRACK_TIME / 32'd228;
   8'd229: sector_period = TRACK_TIME / 32'd229;
   8'd230: sector_period = TRACK_TIME / 32'd230;
   8'd231: sector_period = TRACK_TIME / 32'd231;
   8'd232: sector_period = TRACK_TIME / 32'd232;
   8'd233: sector_period = TRACK_TIME / 32'd233;
   8'd234: sector_period = TRACK_TIME / 32'd234;
   8'd235: sector_period = TRACK_TIME / 32'd235;
   8'd236: sector_period = TRACK_TIME / 32'd236;
   8'd237: sector_period = TRACK_TIME / 32'd237;
   8'd238: sector_period = TRACK_TIME / 32'd238;
   8'd239: sector_period = TRACK_TIME / 32'd239;
   8'd240: sector_period = TRACK_TIME / 32'd240;
   8'd241: sector_period = TRACK_TIME / 32'd241;
   8'd242: sector_period = TRACK_TIME / 32'd242;
   8'd243: sector_period = TRACK_TIME / 32'd243;
   8'd244: sector_period = TRACK_TIME / 32'd244;
   8'd245: sector_period = TRACK_TIME / 32'd245;
   8'd246: sector_period = TRACK_TIME / 32'd246;
   8'd247: sector_period = TRACK_TIME / 32'd247;
   8'd248: sector_period = TRACK_TIME / 32'd248;
   8'd249: sector_period = TRACK_TIME / 32'd249;
   8'd250: sector_period = TRACK_TIME / 32'd250;
   8'd251: sector_period = TRACK_TIME / 32'd251;
   8'd252: sector_period = TRACK_TIME / 32'd252;
   8'd253: sector_period = TRACK_TIME / 32'd253;
   8'd254: sector_period = TRACK_TIME / 32'd254;
   8'd255: sector_period = TRACK_TIME / 32'd255;
   default: sector_period = CYCLES;
  endcase
 end
endfunction


localparam UPD765_MAIN_D0B = 0;
localparam UPD765_MAIN_D1B = 1;
localparam UPD765_MAIN_D2B = 2;
localparam UPD765_MAIN_D3B = 3;
localparam UPD765_MAIN_CB  = 4;
localparam UPD765_MAIN_EXM = 5;
localparam UPD765_MAIN_DIO = 6;
localparam UPD765_MAIN_RQM = 7;

localparam UPD765_SD_BUFF_TRACKINFO = 1'd0;
localparam UPD765_SD_BUFF_SECTOR = 1'd1;

typedef enum
{
 COMMAND_IDLE,

 COMMAND_READ_TRACK,

 COMMAND_WRITE_DELETED_DATA,
 COMMAND_WRITE_DATA,

 COMMAND_READ_DELETED_DATA,
 COMMAND_READ_DATA,

 COMMAND_RW_DATA_EXEC,
 COMMAND_RW_DATA_EXEC1,
 COMMAND_RW_DATA_EXEC2,
 COMMAND_RW_DATA_EXEC3,
 COMMAND_RW_DATA_EXEC4,
 COMMAND_RW_DATA_EXEC5,
 COMMAND_RW_DATA_WAIT_SECTOR,
 COMMAND_RW_DATA_EXEC_WEAK,
 COMMAND_RW_DATA_EXEC6,
 COMMAND_RW_DATA_EXEC7,
 COMMAND_RW_DATA_EXEC8,

 COMMAND_READ_ID,
 COMMAND_READ_ID1,
 COMMAND_READ_ID2,
 COMMAND_READ_ID_EXEC1,
 COMMAND_READ_ID_WAIT_SECTOR,
 COMMAND_READ_ID_EXEC2,

 COMMAND_FORMAT_TRACK,
 COMMAND_FORMAT_TRACK1,
 COMMAND_FORMAT_TRACK2,
 COMMAND_FORMAT_TRACK3,
 COMMAND_FORMAT_TRACK4,
 COMMAND_FORMAT_TRACK5,
 COMMAND_FORMAT_TRACK6,
 COMMAND_FORMAT_TRACK7,
 COMMAND_FORMAT_TRACK8,

 COMMAND_SCAN_EQUAL,
 COMMAND_SCAN_LOW_OR_EQUAL,
 COMMAND_SCAN_HIGH_OR_EQUAL,

 COMMAND_RECALIBRATE,

 COMMAND_SENSE_INTERRUPT_STATUS,
 COMMAND_SENSE_INTERRUPT_STATUS1,
 COMMAND_SENSE_INTERRUPT_STATUS2,

 COMMAND_SPECIFY,
 COMMAND_SPECIFY_WR,

 COMMAND_SENSE_DRIVE_STATUS,
 COMMAND_SENSE_DRIVE_STATUS_RD,

 COMMAND_SEEK,
 COMMAND_SEEK_EXEC1,

 COMMAND_SETUP,

 COMMAND_READ_RESULTS,

 COMMAND_INVALID,
 COMMAND_INVALID1,

 COMMAND_RELOAD_TRACKINFO,
 COMMAND_RELOAD_TRACKINFO1,
 COMMAND_RELOAD_TRACKINFO2,
 COMMAND_RELOAD_TRACKINFO3

} state_t;


// sector/trackinfo buffers
reg    [7:0] buff_data_in, buff_data_out;
reg    [8:0] buff_addr;
reg          buff_wr, buff_wait;
reg          sd_buff_type;
reg          hds, ds0;

cubz_u765_dpram sbuf
(
	.clock(clk_sys),

	.address_a({ds0, sd_buff_type,hds,sd_buff_addr}),
	.data_a(sd_buff_dout),
	.wren_a(sd_buff_wr & sd_ack),
	.q_a(sd_buff_din),

	.address_b({ds0, sd_buff_type,hds,buff_addr}),
	.data_b(buff_data_out),
	.wren_b(buff_wr),
	.q_b(buff_data_in)
);

//track offset buffer
//single port buffer in RAM
logic [15:0] image_track_offsets[1024]; //offset of tracks * 256 * 2 drives
reg    [8:0] image_track_offsets_addr = 0;
reg          image_track_offsets_wr;
reg   [15:0] image_track_offsets_out, image_track_offsets_in;

always @(posedge clk_sys) begin
	if (image_track_offsets_wr) begin
		image_track_offsets[{ds0, image_track_offsets_addr}] <= image_track_offsets_out;
		image_track_offsets_in <= image_track_offsets_out;
	end else begin
		image_track_offsets_in <= image_track_offsets[{ds0, image_track_offsets_addr}];
	end
end

////

wire       rd = nWR & ~nRD;
wire       wr = ~nWR & nRD;
reg [7:0] i_total_sectors;

reg  [7:0] m_status;  //main status register
reg  [7:0] m_data;    //data register

// The upstream engine exposes programmed-I/O execution handshakes. An 8272
// in DMA mode keeps RQM/DIO/EXM clear on the CPU status port while DRQ
// independently requests bytes. Otherwise polling firmware steals DMA bytes.
wire dma_execution = m_status[UPD765_MAIN_EXM] || (state >= COMMAND_RW_DATA_EXEC && state <= COMMAND_RW_DATA_EXEC8);
assign dout = a0 ? m_data : dma_execution ? (m_status & 8'h1f) : m_status;

state_t state;
reg int_state[2];
reg dma_terminal;
assign drq = state == COMMAND_RW_DATA_EXEC6 && m_status[UPD765_MAIN_RQM] && m_status[UPD765_MAIN_EXM];
assign irq = state == COMMAND_READ_RESULTS || int_state[0] || int_state[1];
always @(posedge clk_sys) begin
 if(reset || state == COMMAND_IDLE) dma_terminal <= 0;
 else if(tc && ce && a0 && ((rd && !old_rd) || (wr && !old_wr))) dma_terminal <= 1;
end

   //prefix internal CE protected registers with i_, so it's easier to write constraints

	//per-drive data
	reg[31:0] image_size[2];
	reg       image_ready[2] = '{ 0, 0 };
	reg [7:0] image_tracks[2];
	reg       image_sides[2]; //1 side - 0, 2 sides - 1
	reg [1:0] image_wp;
	reg       image_trackinfo_dirty[2];
	reg       image_edsk[2]; //DSK - 0, EDSK - 1
	reg [1:0] image_scan_state[2] = '{ 0, 0 };
	reg [7:0] i_current_track_sectors[2][2];  //number of sectors on the current track /head/drive
	reg [7:0] i_current_sector_pos[2][2]; //sector where the head currently positioned
	reg[31:0] i_rpm_time[2][2] = '{'{CYCLES,CYCLES}, '{CYCLES,CYCLES}};
	reg[31:0] i_steptimer[2], i_rpm_timer[2][2];
	reg [3:0] i_step_state[2]; //counting cycles for steptimer

	reg [7:0] ncn[2]; //new cylinder number
	reg [7:0] pcn[2]; //present cylinder number
	reg [2:0] next_weak_sector[2];
	reg [1:0] seek_state[2];

	reg old_wr, old_rd;
	reg [7:0] i_track_size;
	reg [31:0] i_seek_pos;
	reg [7:0] i_sector_c, i_sector_h, i_sector_r, i_sector_n;
	reg [7:0] i_sector_st1, i_sector_st2;
	reg [15:0] i_sector_size;
	reg [7:0] i_current_sector;
	reg [2:0] i_weak_sector;
	reg [15:0] i_bytes_to_read;
	reg [2:0] i_substate;
	reg [1:0] old_mounted;
	reg [15:0] i_track_offset;
	reg [5:0] ack;
	reg sd_busy;
	reg [19:0] i_timeout;
	reg [7:0] i_head_timer;
	reg i_rtrack, i_write, i_rw_deleted;
	reg [7:0] status[4] = '{0, 0, 0, 0}; //st0-3
	state_t i_command;
   reg i_current_drive, i_scan_lock = 0;
	reg [3:0] i_srt; //stepping rate
//	reg [3:0] i_hut; //head unload time
//	reg [6:0] i_hlt; //head load time
	reg [7:0] i_c;
	reg [7:0] i_h;
	reg [7:0] i_r;
	reg [7:0] i_n;
	reg [7:0] i_eot;
	//reg [7:0] i_gpl;
	reg [7:0] i_dtl;
	reg [7:0] i_sc;
	//reg [7:0] i_d;
	reg i_bc; //bad cylinder
	reg old_hds;

	reg i_mt;
	//reg i_mfm;
	reg i_sk;

always @(posedge clk_sys) begin
	buff_wait <= 0;
	i_total_sectors = i_current_track_sectors[ds0][hds];

	//new image mounted
	for(int i=0;i<2;i++) begin 
		old_mounted[i] <= img_mounted[i];
		if(old_mounted[i] & ~img_mounted[i]) begin
			image_wp[i] <= img_wp;
			image_size[i] <= img_size;
			image_scan_state[i] <= |img_size; //hacky
			image_ready[i] <= 0;
			int_state[i] <= 0;
			seek_state[i] <= 0;
			next_weak_sector[i] <= 0;
			i_current_sector_pos[i] <= '{ 0, 0 };
		end
	end

	if (ce) begin
		i_current_drive <= ~i_current_drive;
	end

   //Process the image file
	if (ce) begin
		case (image_scan_state[i_current_drive])
			0: ;//no new image
			1: //read the first 512 byte
				if (~sd_busy & ~i_scan_lock & state == COMMAND_IDLE) begin
					sd_buff_type <= UPD765_SD_BUFF_SECTOR;
					i_scan_lock <= 1;
					ds0 <= i_current_drive;
					sd_rd[i_current_drive] <= 1;
					sd_lba <= 0;
					sd_busy <= 1;
					i_track_offset<= 16'h1; //offset 100h
					image_track_offsets_addr <= 0;
					buff_addr <= 0;
					buff_wait <= 1;
					image_scan_state[i_current_drive] <= 2;
				end
			2: //process the header
				if (~sd_busy & ~buff_wait) begin
					if (buff_addr == 0) begin
						if (buff_data_in == "E")
							image_edsk[i_current_drive] <= 1;
						else if (buff_data_in == "M")
							image_edsk[i_current_drive] <= 0;
						else begin
							image_ready[i_current_drive] <= 0;
							image_scan_state[i_current_drive] <= 0;
							i_scan_lock <= 0;
						end
					end else if (buff_addr == 9'h30) image_tracks[i_current_drive] <= buff_data_in;
					else if (buff_addr == 9'h31) image_sides[i_current_drive] <= buff_data_in[1];
					else if (buff_addr == 9'h33) i_track_size <= buff_data_in;
					else if (buff_addr >= 9'h34) begin
						if (image_track_offsets_addr[8:1] != image_tracks[i_current_drive]) begin
							image_track_offsets_wr <= 1;
							if (image_edsk[i_current_drive]) begin
								image_track_offsets_out <= buff_data_in ? i_track_offset : 16'd0;
								i_track_offset <= i_track_offset + buff_data_in;
							end else begin
								image_track_offsets_out <= i_track_offset;
								i_track_offset <= i_track_offset + i_track_size;
							end
							image_scan_state[i_current_drive] <= 3;
						end else begin
							image_ready[i_current_drive] <= 1;
							image_scan_state[i_current_drive] <= 0;
							image_trackinfo_dirty[i_current_drive] <= 1;
							i_scan_lock <= 0;
						end
					end
					buff_addr <= buff_addr + 1'd1;
					buff_wait <= 1;
				end
			3: begin
					image_track_offsets_wr <= 0;
					image_track_offsets_addr <= image_track_offsets_addr + { ~image_sides[i_current_drive], image_sides[i_current_drive] };
					image_scan_state[i_current_drive] <= 2;
				end
		endcase
	end

	//the FDC
   if (reset) begin
		m_status <= 8'h80;
		state <= COMMAND_IDLE;
		status[0] <= 0;
		status[1] <= 0;
		status[2] <= 0;
		ncn <= '{ 0, 0 };
		pcn <= '{ 0, 0 };
		int_state <= '{ 0, 0 };
		seek_state <= '{ 0, 0 };
		image_trackinfo_dirty <= '{ 1, 1 };
		{ ack, sd_busy } <= 0;
		sd_rd <= 0;
		sd_wr <= 0;
		image_track_offsets_wr <= 0;
		//restart "mounting" of image(s)
		if (image_scan_state[0]) image_scan_state[0] <= 1;
		if (image_scan_state[1]) image_scan_state[1] <= 1;
		i_scan_lock <= 0;
		i_srt <= 4;
	end else if (ce) begin

		ack <= {ack[4:0], sd_ack};
		if(ack[5:4] == 'b01)	begin
			sd_rd <= 0;
			sd_wr <= 0;
		end
		if(ack[5:4] == 'b10) sd_busy <= 0;

		old_wr <= wr;
		old_rd <= rd;

		//seek
		case(seek_state[i_current_drive])
			0: ;//no seek in progress
			1: if (pcn[i_current_drive] == ncn[i_current_drive]) begin
					int_state[i_current_drive] <= 1;
					seek_state[i_current_drive] <= 0;
				end else begin
					image_trackinfo_dirty[i_current_drive] <= 1;
					if (fast) begin
						pcn[i_current_drive] <= ncn[i_current_drive];
					end else begin
						if (pcn[i_current_drive] > ncn[i_current_drive]) pcn[i_current_drive] <= pcn[i_current_drive] - 1'd1;
						if (pcn[i_current_drive] < ncn[i_current_drive]) pcn[i_current_drive] <= pcn[i_current_drive] + 1'd1;
						i_step_state[i_current_drive] <= i_srt;
						i_steptimer[i_current_drive] <= CYCLES;
						seek_state[i_current_drive] <= 2;
					end
				end
			2: if(i_steptimer[i_current_drive]) begin
					i_steptimer[i_current_drive] <= i_steptimer[i_current_drive] - 1'd1;
				end else if (~&i_step_state[i_current_drive]) begin
					i_step_state[i_current_drive] <= i_step_state[i_current_drive] + 1'd1;
					i_steptimer[i_current_drive] <= CYCLES;
				end else begin
					seek_state[i_current_drive] <= 1;
				end
		endcase

		//disk rotation
		if (motor[i_current_drive] & ~image_trackinfo_dirty[i_current_drive]) begin
			for (int i=0; i<2 ;i++) begin
				if (i_rpm_timer[i_current_drive][i] >= i_rpm_time[i_current_drive][i]) begin
					i_current_sector_pos[i_current_drive][i] <=
					i_current_sector_pos[i_current_drive][i] == i_current_track_sectors[i_current_drive][i] - 1'd1 ?
						8'd0 : i_current_sector_pos[i_current_drive][i] + 1'd1;
					i_rpm_timer[i_current_drive][i] <= 0;
				end else begin
					i_rpm_timer[i_current_drive][i] <= i_rpm_timer[i_current_drive][i] + 1'd1;
				end
			end
		end

		m_status[UPD765_MAIN_D0B] <= |seek_state[0];
		m_status[UPD765_MAIN_D1B] <= |seek_state[1];
		m_status[UPD765_MAIN_CB] <= state != COMMAND_IDLE;

		case(state)
			COMMAND_IDLE:
			begin
				m_status[UPD765_MAIN_DIO] <= 0;
				m_status[UPD765_MAIN_RQM] <= !image_scan_state[0] & !image_scan_state[1];

				if (~old_wr & wr & a0 & !image_scan_state[0] & !image_scan_state[1]) begin
					i_mt <= din[7];
					//i_mfm <= din[6];
					i_sk <= din[5];

					i_substate <= 0;
					casex (din[7:0])
						8'bXXX_00110: state <= COMMAND_READ_DATA;
						8'bXXX_01100: state <= COMMAND_READ_DELETED_DATA;
						8'bXX0_00101: state <= COMMAND_WRITE_DATA;
						8'bXX0_01001: state <= COMMAND_WRITE_DELETED_DATA;
						8'b0XX_00010: state <= COMMAND_READ_TRACK;
						8'b0X0_01010: state <= COMMAND_READ_ID;
						8'b0X0_01101: state <= COMMAND_FORMAT_TRACK;
						8'bXXX_10001: state <= COMMAND_SCAN_EQUAL;
						8'bXXX_11001: state <= COMMAND_SCAN_LOW_OR_EQUAL;
						8'bXXX_11101: state <= COMMAND_SCAN_HIGH_OR_EQUAL;
						8'b000_00111: state <= COMMAND_RECALIBRATE;
						8'b000_01000: state <= COMMAND_SENSE_INTERRUPT_STATUS;
						8'b000_00011: state <= COMMAND_SPECIFY;
						8'b000_00100: state <= COMMAND_SENSE_DRIVE_STATUS;
						8'b000_01111: state <= COMMAND_SEEK;
						default: state <= COMMAND_INVALID;
					endcase
				end else if(~old_rd & rd & a0) begin
					m_data <= 8'hff;
				end
			end

			COMMAND_SENSE_INTERRUPT_STATUS:
			begin
				m_status[UPD765_MAIN_DIO] <= 1;
				state <= COMMAND_SENSE_INTERRUPT_STATUS1;
			end

			COMMAND_SENSE_INTERRUPT_STATUS1:
			if (~old_rd & rd & a0) begin
				if (int_state[0]) begin
					m_data <= ( ncn[0] == pcn[0] && ready[0] && image_ready[0] ) ? 8'h20 : 8'he8; //drive A: interrupt
					state <= COMMAND_SENSE_INTERRUPT_STATUS2;
				end else if (int_state[1]) begin
					m_data <= ( ncn[1] == pcn[1] && ready[1] && image_ready[1] ) ? 8'h21 : 8'he9; //drive B: interrupt
					state <= COMMAND_SENSE_INTERRUPT_STATUS2;
				end else begin
					m_data <= 8'h80;
					state <= COMMAND_IDLE;
				end;
			end

			COMMAND_SENSE_INTERRUPT_STATUS2:
			if (~old_rd & rd & a0) begin
				m_data <= int_state[0] ? pcn[0] : pcn[1];
				int_state[int_state[0] ? 0 : 1] <= 0;
				state <= COMMAND_IDLE;
			end

			COMMAND_SENSE_DRIVE_STATUS:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
					state <= COMMAND_SENSE_DRIVE_STATUS_RD;
					m_status[UPD765_MAIN_DIO] <= 1;
					ds0 <= din[0];
				end
			end

			COMMAND_SENSE_DRIVE_STATUS_RD:
			if (~old_rd & rd & a0) begin
				m_data <= { 1'b0,
							ready[ds0] & image_wp[ds0],         //write protected
							available[ds0],                     //ready
							image_ready[ds0] & !pcn[ds0],       //track 0
							image_ready[ds0] & image_sides[ds0],//two sides
							image_ready[ds0] & hds,             //head address
							1'b0,                               //us1
							ds0 };                              //us0
				state <= COMMAND_IDLE;
			end

			COMMAND_SPECIFY:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
//					i_hut <= din[3:0];
					i_srt <= din[7:4];
					state <= COMMAND_SPECIFY_WR;
				end
			end

			COMMAND_SPECIFY_WR:
			if (~old_wr & wr & a0) begin
//				i_hlt <= din[7:1];
				state <= COMMAND_IDLE;
			end

			COMMAND_RECALIBRATE:
			begin
				if (~old_wr & wr & a0) begin
					ds0 <= din[0];
					int_state[din[0]] <= 0;
					ncn[din[0]] <= 0;
					seek_state[din[0]] <= 1;
					state <= COMMAND_IDLE;
				end
			end

			COMMAND_SEEK:
			begin
				if (~old_wr & wr & a0) begin
					ds0 <= din[0];
					int_state[din[0]] <= 0;
					state <= COMMAND_SEEK_EXEC1;
				end
			end

			COMMAND_SEEK_EXEC1:
			if (~old_wr & wr & a0) begin
				ncn[ds0] <= din;
				if ((motor[ds0] && ready[ds0] && image_ready[ds0] && din<image_tracks[ds0]) || !din) begin
					seek_state[ds0] <= 1;
				end else begin
					//Seek error
					int_state[ds0] <= 1;
				end
				state <= COMMAND_IDLE;
			end

			COMMAND_READ_ID:
			begin
				int_state <= '{ 0, 0 };
				state <= COMMAND_READ_ID1;
			end

			COMMAND_READ_ID1:
			if (~old_wr & wr & a0) begin
				ds0 <= din[0];
				if (~motor[din[0]] | ~ready[din[0]] | ~image_ready[din[0]]) begin
					status[0] <= 8'h40;
					status[1] <= 8'b101;
					status[2] <= 0;
					state <= COMMAND_READ_RESULTS;
				end else	if (din[2] & ~image_sides[din[0]]) begin
					status[0] <= 8'h48; //no side B
					status[1] <= 0;
					status[2] <= 0;
					state <= COMMAND_READ_RESULTS;
				end else begin
					hds <= din[2];
					m_status[UPD765_MAIN_RQM] <= 0;
					i_command <= COMMAND_READ_ID2;
					state <= COMMAND_RELOAD_TRACKINFO;
				end
			end

			COMMAND_READ_ID2:
			begin
				image_track_offsets_addr <= { pcn[ds0], hds };
				buff_wait <= 1;
				state <= COMMAND_READ_ID_EXEC1;
			end

			COMMAND_READ_ID_EXEC1:
			if (~sd_busy & ~buff_wait) begin
				if (image_track_offsets_in) begin
					state <= COMMAND_READ_ID_WAIT_SECTOR;
				end else begin
					//empty track
					status[0] <= 8'h40;
					status[1] <= 8'b101;
					status[2] <= 0;
					state <= COMMAND_READ_RESULTS;
				end
			end

			COMMAND_READ_ID_WAIT_SECTOR:
			if (~sd_busy & ~buff_wait & (!i_rpm_timer[ds0][hds] | fast)) begin
				sd_buff_type <= UPD765_SD_BUFF_TRACKINFO;
				buff_addr <= { image_track_offsets_in[0], 8'h18 + (i_current_sector_pos[ds0][hds] << 3) }; //get the current sectorInfo
				buff_wait <= 1;
				state <= COMMAND_READ_ID_EXEC2;
			end

			COMMAND_READ_ID_EXEC2:
			if (~buff_wait) begin
				if (buff_addr[2:0] == 8'h00) i_sector_c <= buff_data_in;
				else if (buff_addr[2:0] == 8'h01) i_sector_h <= buff_data_in;
				else if (buff_addr[2:0] == 8'h02) i_sector_r <= buff_data_in;
				else if (buff_addr[2:0] == 8'h03) begin
					i_sector_n <= buff_data_in;
					status[0] <= 0;
					status[1] <= 0;
					status[2] <= 0;
					state <= COMMAND_READ_RESULTS;
				end
				buff_addr <= buff_addr + 1'd1;
				buff_wait <= 1;
			end

			COMMAND_READ_TRACK:
			begin
				int_state <= '{ 0, 0 };
				i_command <= COMMAND_RW_DATA_EXEC;
				state <= COMMAND_SETUP;
				{i_rtrack, i_write, i_rw_deleted} <= 3'b100;
			end

			COMMAND_WRITE_DATA:
			begin
				int_state <= '{ 0, 0 };
				i_command <= COMMAND_RW_DATA_EXEC;
				state <= COMMAND_SETUP;
				{i_rtrack, i_write, i_rw_deleted} <= 3'b010;
			end

			COMMAND_WRITE_DELETED_DATA:
			begin
				int_state <= '{ 0, 0 };
				i_command <= COMMAND_RW_DATA_EXEC;
				state <= COMMAND_SETUP;
				{i_rtrack, i_write, i_rw_deleted} <= 3'b011;
			end

			COMMAND_READ_DATA:
			begin
				int_state <= '{ 0, 0 };
				i_command <= COMMAND_RW_DATA_EXEC;
				state <= COMMAND_SETUP;
				{i_rtrack, i_write, i_rw_deleted} <= 3'b000;
			end

			COMMAND_READ_DELETED_DATA:
			begin
				int_state <= '{ 0, 0 };
				i_command <= COMMAND_RW_DATA_EXEC;
				state <= COMMAND_SETUP;
				{i_rtrack, i_write, i_rw_deleted} <= 3'b001;
			end

			COMMAND_RW_DATA_EXEC:
			if (i_write & image_wp[ds0]) begin
				status[0] <= 8'h40;
				status[1] <= 8'h02; //not writeable
				status[2] <= 0;
				state <= COMMAND_READ_RESULTS;
			end else begin
				m_status[UPD765_MAIN_RQM] <= 0;
				i_command <= COMMAND_RW_DATA_EXEC1;
				state <= COMMAND_RELOAD_TRACKINFO;
			end

			COMMAND_RW_DATA_EXEC1:
			begin
				m_status[UPD765_MAIN_DIO] <= ~i_write;
				if (i_rtrack) i_r <= 1;
				i_bc <= 1;
				// Read from the track stored at the last seek
				// even if different one is given in the command
				image_track_offsets_addr <= { pcn[ds0], hds };
				buff_wait <= 1;
				state <= COMMAND_RW_DATA_EXEC2;
			end

			COMMAND_RW_DATA_EXEC2:
			if (~sd_busy & ~buff_wait) begin
				i_current_sector <= 1'd1;
				sd_buff_type <= UPD765_SD_BUFF_TRACKINFO;
				i_seek_pos <= {image_track_offsets_in+1'd1,8'd0}; //TrackInfo+256bytes
				buff_addr <= {image_track_offsets_in[0], 8'h14}; //sector size
				buff_wait <= 1;
				state <= COMMAND_RW_DATA_EXEC3;
			end

			//process trackInfo + sectorInfo
			COMMAND_RW_DATA_EXEC3:
			if (~sd_busy & ~buff_wait) begin
				if (buff_addr[7:0] == 8'h14) begin
					if (!image_edsk[ds0]) i_sector_size <= 8'h80 << buff_data_in[2:0];
					buff_addr[7:0] <= 8'h18; //sector info list
					buff_wait <= 1;
				end else if (i_current_sector > i_total_sectors) begin
					m_status[UPD765_MAIN_EXM] <= 0;
					//sector not found or end of track
					status[0] <= i_rtrack ? 8'h00 : 8'h40;
					status[1] <= i_rtrack ? 8'h00 : 8'h04;
					status[2] <= i_rtrack | ~i_bc ? 8'h00 : (i_sector_c == 8'hff ? 8'h02 : 8'h10); //bad/wrong cylinder
					state <= COMMAND_READ_RESULTS;
				end else begin
					//process sector info list
					case (buff_addr[2:0])
						0: i_sector_c <= buff_data_in;
						1: i_sector_h <= buff_data_in;
						2: i_sector_r <= buff_data_in;
						3: i_sector_n <= buff_data_in;
						4: i_sector_st1 <= buff_data_in;
						5: i_sector_st2 <= buff_data_in;
						6: if (image_edsk[ds0]) i_sector_size[7:0] <= buff_data_in;
						7: begin
								if (image_edsk[ds0]) i_sector_size[15:8] <= buff_data_in;
								state <= COMMAND_RW_DATA_EXEC4;
							end
					endcase
					buff_addr <= buff_addr + 1'd1;
					buff_wait <= 1;
				end
			end

			//found the sector?
			COMMAND_RW_DATA_EXEC4:
			if ((i_rtrack && i_current_sector == i_r) ||
				(~i_rtrack && i_sector_c == i_c && i_sector_r == i_r && i_sector_h == i_h && (i_sector_n == i_n || !i_n))) begin
				//sector found in the sector info list
				if (i_sk & ~i_rtrack & (i_rw_deleted ^ i_sector_st2[6])) begin
					state <= COMMAND_RW_DATA_EXEC8;
				end else begin
					i_bytes_to_read <= i_n ? (8'h80 << (i_n[3] ? 4'h8 : i_n[2:0])) : i_dtl;
					i_timeout <= OVERRUN_TIMEOUT;
					i_weak_sector <= 0;
					state <= COMMAND_RW_DATA_WAIT_SECTOR;
				end
			end else begin
				//try the next sector in the sectorinfo list
				if (i_sector_c == i_c) i_bc <= 0;
				i_current_sector <= i_current_sector + 1'd1;
				i_seek_pos <= i_seek_pos + i_sector_size;
				state <= COMMAND_RW_DATA_EXEC3;
			end

			//wait for the sector needed for positioning at the head
			COMMAND_RW_DATA_WAIT_SECTOR:
			if (fast ||
				((i_current_sector_pos[ds0][hds] == i_current_sector - 1'd1) &&
				(i_rpm_timer[ds0][hds] == i_rpm_time[ds0][hds] >> 2 ))) begin
				m_status[UPD765_MAIN_EXM] <= 1;
				state <= COMMAND_RW_DATA_EXEC_WEAK;
			end

			COMMAND_RW_DATA_EXEC_WEAK:
			if (image_edsk[ds0] &&
				(i_sector_size == { i_bytes_to_read, 1'b0 } || // 2 weak sectors
				(i_sector_size == ({ i_bytes_to_read, 1'b0 } + i_bytes_to_read)) || // 3 weak sectors
				(i_sector_size == { i_bytes_to_read, 2'b00 } ))) begin // 4 weak sectors
				//if sector data == 2,3,4x sector size, then handle multiple version of the same sector (weak sectors)
				//otherwise extra data is considered as GAP data
				if (i_weak_sector != next_weak_sector[ds0]) begin
					i_seek_pos <= i_seek_pos + i_bytes_to_read;
					i_sector_size <= i_sector_size - i_bytes_to_read;
					i_weak_sector <= i_weak_sector + 1'd1;
				end else begin
					next_weak_sector[ds0] <= next_weak_sector[ds0] + 1'd1;
					state <= COMMAND_RW_DATA_EXEC5;
				end
			end else begin
				if (SPECCY_SPEEDLOCK_HACK & 
					 i_current_sector == 2 & !pcn[ds0] & ~hds & i_sector_st1[5] & i_sector_st2[5])
					next_weak_sector[ds0] <= next_weak_sector[ds0] + 1'd1;
				else
					next_weak_sector[ds0] <= 0;
				state <= COMMAND_RW_DATA_EXEC5;
			end

			//Read the LBA for the sector into the RAM
			COMMAND_RW_DATA_EXEC5:
			if (~sd_busy) begin
				sd_buff_type <= UPD765_SD_BUFF_SECTOR;
				sd_rd[ds0] <= 1;
				sd_lba <= i_seek_pos[31:9];
				sd_busy <= 1;
				buff_addr <= i_seek_pos[8:0];
				buff_wait <= 1;
				state <= COMMAND_RW_DATA_EXEC6;
			end

			//Read from/write to Speccy
			COMMAND_RW_DATA_EXEC6:
			if (~sd_busy & ~buff_wait) begin
				if (!i_bytes_to_read || dma_terminal) begin
					//end of the current sector
					if (i_write && buff_addr && i_seek_pos < image_size[ds0]) begin
						sd_lba <= i_seek_pos[31:9];
						sd_wr[ds0] <= 1;
						sd_busy <= 1;
					end
					state <= COMMAND_RW_DATA_EXEC8;
				end else if (!i_timeout) begin
					m_status[UPD765_MAIN_EXM] <= 0;
					status[0] <= 8'h40;
					status[1] <= 8'h10; //overrun
					status[2] <= i_sector_st2 | (i_rw_deleted ? 8'h40 : 8'h0);
					state <= COMMAND_READ_RESULTS;
				end else if (~m_status[UPD765_MAIN_RQM]) begin
					m_status[UPD765_MAIN_RQM] <= 1;
				end else if (~i_write & ~old_rd & rd & a0) begin
					if (&buff_addr) begin
						//sector continues on the next LBA
						state <= COMMAND_RW_DATA_EXEC5;
					end
					//Speedlock: fuzz 'weak' sectors last bytes
					//weak sector is cyl 0, head 0, sector 2
					m_data <= (SPECCY_SPEEDLOCK_HACK &
								i_current_sector == 2 & !pcn[ds0] & ~hds &
								i_sector_st1[5] & i_sector_st2[5] & !i_bytes_to_read[14:4]) ?
						 buff_data_in << next_weak_sector[ds0] : buff_data_in;

					m_status[UPD765_MAIN_RQM] <= 0;
					if (i_sector_size) begin
						i_sector_size <= i_sector_size - 1'd1;
						buff_addr <= buff_addr + 1'd1;
						buff_wait <= 1;
						i_seek_pos <= i_seek_pos + 1'd1;
					end
					i_bytes_to_read <= i_bytes_to_read - 1'd1;
					i_timeout <= OVERRUN_TIMEOUT;
				end else if (i_write & ~old_wr & wr & a0) begin
					buff_wr <= 1;
					buff_data_out <= din;
					i_timeout <= OVERRUN_TIMEOUT;
					m_status[UPD765_MAIN_RQM] <= 0;
					state <= COMMAND_RW_DATA_EXEC7;
				end else begin
					i_timeout <= i_timeout - 1'd1;
				end
			end

			COMMAND_RW_DATA_EXEC7:
			begin
				buff_wr <= 0;
				if (i_sector_size) begin
					i_sector_size <= i_sector_size - 1'd1;
					buff_addr <= buff_addr + 1'd1;
					buff_wait <= 1;
					i_seek_pos <= i_seek_pos + 1'd1;
				end
				i_bytes_to_read <= i_bytes_to_read - 1'd1;
				if (&buff_addr) begin
					//sector continues on the next LBA
					//so write out the current before reading the next
					if (i_seek_pos < image_size[ds0]) begin
						sd_lba <= i_seek_pos[31:9];
						sd_wr[ds0] <= 1;
						sd_busy <= 1;
					end
					state <= COMMAND_RW_DATA_EXEC5;
				end else begin
					state <= COMMAND_RW_DATA_EXEC6;
				end
			end

			//End of reading/writing sector, what's next?
			COMMAND_RW_DATA_EXEC8:
			if (~sd_busy) begin
				if (dma_terminal) begin
                    m_status[UPD765_MAIN_EXM] <= 0;
                    status[0] <= 0; status[1] <= i_sector_st1 & 8'h20; status[2] <= i_sector_st2 & 8'h20;
                    state <= COMMAND_READ_RESULTS;
                end else if (~i_rtrack & ~(i_sk & (i_rw_deleted ^ i_sector_st2[6])) &
					((i_sector_st1[5] & i_sector_st2[5]) | (i_rw_deleted ^ i_sector_st2[6]))) begin
					//deleted mark or crc error
					m_status[UPD765_MAIN_EXM] <= 0;
					status[0] <= 8'h40;
					status[1] <= i_sector_st1;
					status[2] <= i_sector_st2 | (i_rw_deleted ? 8'h40 : 8'h0);
					state <= COMMAND_READ_RESULTS;
				end else	if ((i_rtrack ? i_current_sector : i_sector_r) == i_eot) begin
					//end of cylinder
					m_status[UPD765_MAIN_EXM] <= 0;
					status[0] <= i_rtrack ? 8'h00 : 8'h40;
					status[1] <= 8'h80;
					status[2] <= (i_rw_deleted ^ i_sector_st2[6]) ? 8'h40 : 8'h0;
					state <= COMMAND_READ_RESULTS;
				end else begin
					//read the next sector (multi-sector transfer)
					if (i_mt & image_sides[ds0]) begin
						hds <= ~hds;
						i_h <= ~i_h;
						image_track_offsets_addr <= { pcn[ds0], ~hds };
						buff_wait <= 1;
					end
					if (~i_mt | hds | ~image_sides[ds0]) i_r <= i_r + 1'd1;
					state <= COMMAND_RW_DATA_EXEC2;
				end
			end

			COMMAND_FORMAT_TRACK:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
					ds0 <= din[0];
					state <= COMMAND_FORMAT_TRACK1;
				end
			end

			COMMAND_FORMAT_TRACK1: //doesn't modify the media
			if (~old_wr & wr & a0) begin
				i_n <= din;
				state <= COMMAND_FORMAT_TRACK2;
			end

			COMMAND_FORMAT_TRACK2:
			if (~old_wr & wr & a0) begin
				i_sc <= din;
				state <= COMMAND_FORMAT_TRACK3;
			end

			COMMAND_FORMAT_TRACK3:
			if (~old_wr & wr & a0) begin
				//i_gpl <= din;
				state <= COMMAND_FORMAT_TRACK4;
			end

			COMMAND_FORMAT_TRACK4:
			if (~old_wr & wr & a0) begin
				//i_d <= din;
				m_status[UPD765_MAIN_EXM] <= 1;
				state <= COMMAND_FORMAT_TRACK5;
			end

			COMMAND_FORMAT_TRACK5:
			if (!i_sc) begin
				m_status[UPD765_MAIN_EXM] <= 0;
				status[0] <= 0;
				status[1] <= 0;
				status[2] <= 0;
				state <= COMMAND_READ_RESULTS;
			end else	if (~old_wr & wr & a0) begin
				i_c <= din;
				state <= COMMAND_FORMAT_TRACK6;
			end

			COMMAND_FORMAT_TRACK6:
			if (~old_wr & wr & a0) begin
				i_h <= din;
				state <= COMMAND_FORMAT_TRACK7;
			end

			COMMAND_FORMAT_TRACK7:
			if (~old_wr & wr & a0) begin
				i_r <= din;
				state <= COMMAND_FORMAT_TRACK8;
			end

			COMMAND_FORMAT_TRACK8:
			if (~old_wr & wr & a0) begin
				i_n <= din;
				i_sc <= i_sc - 1'd1;
				i_r <= i_r + 1'd1;
				state <= COMMAND_FORMAT_TRACK5;
			end

			COMMAND_SCAN_EQUAL:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
					state <= COMMAND_IDLE;
				end
			end

			COMMAND_SCAN_HIGH_OR_EQUAL:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
					state <= COMMAND_IDLE;
				end
			end

			COMMAND_SCAN_LOW_OR_EQUAL:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
					state <= COMMAND_IDLE;
				end
			end

			COMMAND_SETUP:
			if (!old_wr & wr & a0) begin
				case (i_substate)
					0: begin
							ds0 <= din[0];
							hds <= din[2];
							i_substate <= 1;
						end
					1: begin
							i_c <= din;
							i_substate <= 2;
						end
					2:	begin
							i_h <= din;
							i_substate <= 3;
						end
					3: begin
							i_r <= din;
							i_substate <= 4;
						end
					4: begin
							i_n <= din;
							i_substate <= 5;
						end
					5: begin
							i_eot <= din;
							i_substate <= 6;
						end
					6:	begin
							//i_gpl <= din;
							i_substate <= 7;
						end
					7: begin
							i_dtl <= din;
							i_substate <= 0;
							if (~motor[ds0] | ~ready[ds0] | ~image_ready[ds0]) begin
								status[0] <= 8'h40;
								status[1] <= 8'b101;
								status[2] <= 0;
								state <= COMMAND_READ_RESULTS;
							end else if (hds & ~image_sides[ds0]) begin
								hds <= 0;
								status[0] <= 8'h48; //no side B
								status[1] <= 0;
								status[2] <= 0;
								state <= COMMAND_READ_RESULTS;
							end else begin
								state <= i_command;
							end
						end
				endcase
			end

			COMMAND_READ_RESULTS:
			begin
				m_status[UPD765_MAIN_RQM] <= 1;
				m_status[UPD765_MAIN_DIO] <= 1;
				if (~old_rd & rd & a0) begin
					case (i_substate)
						0: begin
								m_data <= { status[0][7:3], hds, 1'b0, ds0 };
								i_substate <= 1;
							end
						1: begin
								m_data <= status[1];
								i_substate <= 2;
							end
						2: begin
								m_data <= status[2];
								i_substate <= 3;
							end
						3: begin
								m_data <= i_sector_c;
								i_substate <= 4;
							end
						4: begin
								m_data <= i_sector_h;
								i_substate <= 5;
							end
						5: begin
								m_data <= i_sector_r;
								i_substate <= 6;
							end
						6: begin
								m_data <= i_sector_n;
								state <= COMMAND_IDLE;
							end
						7: ;//not happen
					endcase
				end
			end

			COMMAND_INVALID:
			begin
				int_state <= '{ 0, 0 };
				m_status[UPD765_MAIN_DIO] <= 1;
				status[0] <= 8'h80;
				state <= COMMAND_INVALID1;
			end

			COMMAND_INVALID1:
			if (~old_rd & rd & a0) begin
				state <= COMMAND_IDLE;
				m_data <= status[0];
			end

			COMMAND_RELOAD_TRACKINFO:
			if (image_ready[ds0] & image_trackinfo_dirty[ds0]) begin
				i_rpm_timer[ds0] <= '{ 0, 0 };
				next_weak_sector[ds0] <= 0;
				image_track_offsets_addr <= { pcn[ds0], 1'b0 };
				old_hds <= hds;
				hds <= 0;
				buff_wait <= 1;
				state <= COMMAND_RELOAD_TRACKINFO1;
			end else begin
				state <= i_command;
			end

			COMMAND_RELOAD_TRACKINFO1:
			if (~buff_wait& ~sd_busy) begin
				if (image_ready[ds0] && image_track_offsets_in) begin
					sd_buff_type <= UPD765_SD_BUFF_TRACKINFO;
					sd_rd[ds0] <= 1;
					sd_lba <= image_track_offsets_in[15:1];
					sd_busy <= 1;
					state <= COMMAND_RELOAD_TRACKINFO2;
				end else begin
					image_trackinfo_dirty[ds0] <= 0;
					hds <= old_hds;
					state <= i_command;
				end
			end

			COMMAND_RELOAD_TRACKINFO2:
			if (~sd_busy) begin
				buff_addr <= {image_track_offsets_in[0], 8'h15}; //number of sectors
				buff_wait <= 1;
				state <= COMMAND_RELOAD_TRACKINFO3;
			end

			COMMAND_RELOAD_TRACKINFO3:
			if (~sd_busy & ~buff_wait) begin
				i_current_track_sectors[ds0][hds] <= buff_data_in;
				i_rpm_time[ds0][hds] <= sector_period(buff_data_in);

				//assume the head position is at the middle of a track after a seek
				i_current_sector_pos[ds0][hds] <= buff_data_in[7:1];

				if (hds == image_sides[ds0]) begin
					image_trackinfo_dirty[ds0] <= 0;
					hds <= old_hds;
					state <= i_command;
				end else begin //read TrackInfo from the other head if 2 sided
					image_track_offsets_addr <= { pcn[ds0], 1'b1 };
					hds <= 1;
					buff_wait <= 1;
					state <= COMMAND_RELOAD_TRACKINFO1;
				end
			end

		endcase //status

	end
end

endmodule

module cubz_u765_dpram #(parameter DATAWIDTH=8, ADDRWIDTH=12)
(
	input	                clock,

	input	[ADDRWIDTH-1:0] address_a,
	input	[DATAWIDTH-1:0] data_a,
	input	                wren_a,
	output reg [DATAWIDTH-1:0] q_a,

	input	[ADDRWIDTH-1:0] address_b,
	input	[DATAWIDTH-1:0] data_b,
	input	                wren_b,
	output reg [DATAWIDTH-1:0] q_b
);

logic [DATAWIDTH-1:0] ram[0:(1<<ADDRWIDTH)-1];

always_ff@(posedge clock) begin
	if(wren_a) begin
		ram[address_a] <= data_a;
		q_a <= data_a;
	end else begin
		q_a <= ram[address_a];
	end
end

always_ff@(posedge clock) begin
	if(wren_b) begin
		ram[address_b] <= data_b;
		q_b <= data_b;
	end else begin
		q_b <= ram[address_b];
	end
end

endmodule
