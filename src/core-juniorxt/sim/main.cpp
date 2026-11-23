#include "Vjunior_sim.h"
#include "Vjunior_sim___024root.h"
#include "verilated.h"
#include <vector>
#include <fstream>
#include <iostream>
#include <cstdint>
#include <filesystem>
#include <iomanip>
#include <deque>
#include <map>
#include <set>
#include <algorithm>
using namespace std;
vector<uint8_t> load(const string& p){ifstream f(p,ios::binary);if(!f)throw runtime_error(p);return vector<uint8_t>((istreambuf_iterator<char>(f)),{});}
int main(int argc,char**argv){
 Verilated::commandArgs(argc,argv); Vjunior_sim t;
 if(argc<3){cerr<<"usage: sim BIOS.rom disk.img [seconds] [first|persist|floppy|boot] (options: JUNIOR_CFG, JUNIOR_RAM, JUNIOR_DISPLAY)\n";return 2;}
 auto option=[](const char*n,int d){const char*v=getenv(n);return v?int(strtol(v,nullptr,0)):d;};
 int cfg=option("JUNIOR_CFG",1),ram_blocks=option("JUNIOR_RAM",10),display=option("JUNIOR_DISPLAY",0);unsigned text_base=display==2?0x860000:0x850000;
 bool boot_only=argc>4 && string(argv[4])=="boot",winchester=argc>4 && string(argv[4])=="winchester";
 // Fixed disk 1 (JUNIOR_HD): what MiSTer's Linux side does for rtl/common/ide.v, one raw image.
 vector<uint8_t> hd;if(getenv("JUNIOR_HD"))hd=load(getenv("JUNIOR_HD"));
 int istate=0,iw=0,icount=0,iphase=0,iwait=0;unsigned ilba=0,hd_reads=0,hd_writes=0;uint16_t icmd=0,ireg1=0,ibuf[256];bool iwrite=false,ihold=false,irelease=false,ipresent=false,identify=false;
 t.cfg=cfg;t.ram_blocks=ram_blocks;t.display=display;
 vector<uint8_t> mem(0x2000000),rom=load(argv[1]),disk=load(argv[2]);
 if(argc>5){auto saved=load(argv[5]);copy(saved.begin(),saved.end(),mem.begin());}copy(rom.begin(),rom.end(),mem.begin()+0x100000);
 bool floppy_diag=argc>4 && string(argv[4])=="floppy";
 if(floppy_diag){auto code=load("floppy-test.bin");copy(code.begin(),code.end(),mem.begin()+0x2000);uint8_t reset_code[]={0xea,0x00,0x20,0x00,0x00};copy(reset_code,reset_code+5,mem.begin()+0x10fff0);}
 uint64_t limit=uint64_t((argc>3?stod(argv[3]):20)*200000000ULL);
 uint64_t clk28_acc=0,clk57_acc=0,txn_data=0;uint32_t txn_addr=0;int txn_len=0,txn_wait=0;bool txn_we=false;uint8_t txn_be=0;
 bool lastio=true;uint16_t mgaddr=0;int fstate=0,fi=0;unsigned lba=0,reads=0,writes=0;int initreg=0;unsigned transactions=0;bool pb6=false;uint64_t key_start=0;int key_bit=-1;uint8_t key_byte=0;int key_phase=0;bool old_video_clk=false,old_hblank=true,old_vblank=true,record_video=false,old_speaker=false;unsigned speaker_edges=0;string video_request,video_name;set<string> captured_video;vector<vector<uint8_t>> video_rows;vector<uint8_t> video_row;deque<uint8_t> keys;int scenario=0;uint64_t phase_tick=0;bool bat=false; bool success=false;bool persist=argc>4 && string(argv[4])=="persist";
 t.ps2_clock=1;t.ps2_data=1;t.reset_cpu=1;t.reset_sdram=1;
 t.mem_done=0;t.mem_busy=0;t.mem_rdata=0;t.mgmt_read=0;t.mgmt_write=0;
 for(uint64_t tick=0;tick<limit;++tick){
  t.clk100=tick&1; bool rising=(tick&3)==2;t.clk_chip=(tick>>1)&1;
  clk28_acc+=57272720;if(clk28_acc>=200000000){clk28_acc-=200000000;t.clk28=!t.clk28;}
  clk57_acc+=114545440;if(clk57_acc>=200000000){clk57_acc-=200000000;t.clk57=!t.clk57;}
  // PS/2 keyboard BAT after the motherboard releases its reset line.
  if(!pb6 && (t.port_b&64)){key_start=tick+300000;key_byte=0xff;key_bit=0;key_phase=0;}
  pb6=t.port_b&64;
  if(key_bit>=0 && tick>=key_start){
   uint64_t d=tick-key_start;int bit=d/14000;
   if(bit>=11){t.ps2_clock=1;t.ps2_data=1;if(key_phase<2){key_phase++;key_byte=key_phase==1?0xfa:0xaa;key_start=tick+200000;}else{key_bit=-1;bat=true;}}
   else{t.ps2_clock=(d%14000)<7000;t.ps2_data=bit==0?0:bit==10?1:bit==9?(__builtin_popcount(key_byte)%2==0):((key_byte>>(bit-1))&1);}
  }
  if(key_bit<0 && bat && !keys.empty() && tick>key_start+360000){key_byte=keys.front();keys.pop_front();key_start=tick;key_bit=0;key_phase=2;}
  if(tick==2000){t.reset_cpu=0;t.reset_sdram=0;}
  bool next_busy=t.mem_busy,next_done=t.mem_done;uint64_t next_rdata=t.mem_rdata;
  if(rising){
   next_done=0;
   if(txn_wait && --txn_wait==0){uint64_t rd=0;for(int i=0;i<2*txn_len;i++){
     auto a=txn_addr*2+i;if(txn_we && ((txn_be>>i)&1))mem.at(a)=(txn_data>>(i*8))&255;
     rd|=uint64_t(mem.at(a))<<(8*i);
    }next_rdata=rd;next_done=1;next_busy=0;
   }else if(!txn_wait && t.mem_start && !t.reset_cpu){txn_addr=t.mem_addr;txn_len=1<<t.mem_len;txn_data=t.mem_wdata;txn_be=t.mem_wbe;txn_we=t.mem_we;txn_wait=4;next_busy=1;if(transactions++<8)cout<<"MEM "<<hex<<txn_addr*2<<" W "<<txn_we<<" D "<<txn_data<<" PC "<<t.pc_fetch<<dec<<"\n";}
   t.mgmt_read=0;t.mgmt_write=0;
   if(tick>3000 && initreg<6){int vals[]={winchester?0:1,0,40,int(disk.size()/512/80),int(disk.size()/512),2};t.mgmt_address=0xf200+initreg;t.mgmt_writedata=vals[initreg++];t.mgmt_write=1;}
   else if(initreg==6 && irelease)irelease=false;
   else if(initreg==6 && !ipresent){t.mgmt_address=0xf006;t.mgmt_writedata=hd.empty()?0x88:0x89;t.mgmt_write=1;irelease=ipresent=true;}
   else if(initreg==6 && fstate==0 && !t.fdd_request && (istate || t.ide_request)){
    auto mw=[&](int a,int d){t.mgmt_address=0xf000+a;t.mgmt_writedata=d;t.mgmt_write=1;irelease=a!=15;};
    auto mr=[&](int a){t.mgmt_address=0xf000+a;t.mgmt_read=1;irelease=a!=15;};
    switch(istate){
     case 0:if(t.ide_request==6){mw(5,0x5000);ihold=false;}
            else if(t.ide_request==4 && !ihold){mr(5);istate=1;}
            else if(t.ide_request==5){if(iwrite){mr(0);istate=20;}else istate=10;}break;
     case 1:icmd=t.mgmt_readdata;mr(1);istate=2;break;
     case 2:ireg1=t.mgmt_readdata;mr(2);istate=3;break;
     case 3:{unsigned cmd=icmd>>8,drv=icmd&255;istate=40;cout<<"IDE command "<<hex<<cmd<<" drive "<<drv<<" sector/count "<<ireg1<<" cylinder "<<t.mgmt_readdata<<dec<<endl;
            if(drv&16){ihold=true;istate=0;}                               // no second drive: never answers
            else if(cmd==0xEC){for(auto&w:ibuf)w=0;unsigned n=hd.size()/512;ibuf[1]=n/68;ibuf[3]=4;ibuf[6]=17;ibuf[49]=0x200;ibuf[60]=n&0xffff;ibuf[61]=n>>16;icount=1;iwrite=false;identify=true;istate=10;}
            else if(cmd==0x20||cmd==0x30){ilba=(ireg1>>8)|(unsigned(t.mgmt_readdata)<<8)|((drv&15)<<24);icount=(ireg1&255)?(ireg1&255):256;iwrite=cmd==0x30;
             if(ilba+icount<=hd.size()/512)istate=iwrite?30:10;}
            break;}
     case 10:if(!identify)for(int i=0;i<256;i++)ibuf[i]=hd.at(ilba*512+2*i)|(hd.at(ilba*512+2*i+1)<<8);
             mw(0,1);iw=0;iphase=0;istate=11;break;
     case 11:if(!iphase){mw(15,ibuf[iw]);iphase=1;}else{t.mgmt_address=0xf00f;iphase=0;if(++iw==256)istate=12;}break;
     case 12:--icount;mw(5,0x5800|(icount?0:0x200)|(icmd&255));if(!identify){ilba++;hd_reads++;}identify=false;istate=0;break;
     case 30:mw(0,1);istate=31;break;
     case 31:mw(5,0x5800|(icmd&255));istate=0;break;
     case 20:t.mgmt_address=0xf00f;iw=0;iphase=0;iwait=3;istate=21;break;
     case 21:t.mgmt_address=0xf00f;if(iwait)iwait--;
             else if(iphase==0){ibuf[iw]=t.mgmt_readdata;mr(15);iphase=1;}
             else if(++iphase==4){iphase=0;if(++iw==256)istate=22;}break;
     case 22:for(int i=0;i<256;i++){hd.at(ilba*512+2*i)=ibuf[i]&255;hd.at(ilba*512+2*i+1)=ibuf[i]>>8;}
             ilba++;hd_writes++;mw(5,(--icount?0x5800:0x5000)|(icmd&255));istate=0;break;
     case 40:mw(0,0x0400);istate=41;break;                                  // any other command: aborted
     case 41:mw(5,0x5100|(icmd&255));istate=0;break;
    }
   }
   else if(initreg==6){
    switch(fstate){
     case 0:if(t.fdd_request){t.mgmt_address=0xf200;t.mgmt_read=1;fstate=1;}break;
     case 1:lba=t.mgmt_readdata&0x7fff;cout<<"MEDIA LBA "<<lba<<" request "<<int(t.fdd_request)<<"\n";fi=0;fstate=(t.fdd_request&1)?2:3;break;
     case 2:t.mgmt_address=0xf20f;t.mgmt_write=1;t.mgmt_writedata=disk.at(lba*512+fi);if(++fi==512){fstate=4;reads++;}break;
     case 3:t.mgmt_address=0xf20f;t.mgmt_read=1;fstate=5;break;
     case 5:disk.at(lba*512+fi)=t.mgmt_readdata&255;t.mgmt_address=0xf20f;t.mgmt_read=1;if(++fi==512){t.mgmt_read=0;fstate=4;writes++;}else fstate=5;break;
     case 4:if(!t.fdd_request)fstate=0;break;
    }
   }
  }
  // External CGA VRAM response: the sequencer samples char at slot2, attr at3.
  unsigned va=0x850000+((t.fx_cga_cur_word&0x3fff)*2);
  t.fx_cga_vram_d=mem[va+((t.fx_cga_phase&15)==3)];
  t.fx_hgc_vram_d=mem[0x860000+((t.fx_hgc_cur_word&0x3fff)*2)+((t.fx_hgc_phase&31)==4)];
  t.eval();
  if(rising){t.mem_busy=next_busy;t.mem_done=next_done;t.mem_rdata=next_rdata;t.eval();}
  bool speaker=(t.rootp->junior_sim__DOT__u_chipset__DOT__timer_counter_out&4)&&(t.port_b&2);
  if(scenario==8 && speaker!=old_speaker)speaker_edges++;old_speaker=speaker;
  if(t.clk28 && !old_video_clk){
   if(!t.vblank && old_vblank && !video_request.empty()){record_video=true;video_name=video_request;video_request.clear();video_rows.clear();video_row.clear();}
   if(record_video && !t.vblank && !t.hblank){video_row.push_back(t.red*255/63);video_row.push_back(t.green*255/63);video_row.push_back(t.blue*255/63);}
   if(record_video && t.hblank && !old_hblank && !video_row.empty()){video_rows.push_back(video_row);video_row.clear();}
   if(record_video && t.vblank && !old_vblank){
    size_t width=10000;for(auto&r:video_rows)width=min(width,r.size()/3);
    if(width<600 || video_rows.size()<190)throw runtime_error("Incomplete native video frame");
    ofstream ppm(video_name+".ppm",ios::binary);ppm<<"P6\n"<<width<<" "<<video_rows.size()<<"\n255\n";
    for(auto&r:video_rows)ppm.write((char*)r.data(),width*3);record_video=false;captured_video.insert(video_name);
   }
   old_hblank=t.hblank;old_vblank=t.vblank;
  }
  old_video_clk=t.clk28;
  if(rising && lastio && !t.io_write_n && t.cpu_status==2){if(floppy_diag && t.bus_address==0xe9){cout<<"DISK TEST MARK "<<int(t.bus_data)<<"\n";cout.flush();if(t.bus_data>=254){success=t.bus_data==255;break;}}if((t.bus_address>=0x250 && t.bus_address<0x270)||(t.bus_address>=0x3f0 && t.bus_address<0x3f8))cout<<"SIO OUT "<<hex<<t.bus_address<<" "<<int(t.bus_data)<<dec<<"\n";}
  if(rising)lastio=t.io_write_n;

  if(tick && tick%2000000ULL==0){
   vector<string> lines;string screen;for(int y=0;y<25;y++){string line;for(int x=0;x<80;x++){auto ch=mem[text_base+2*(y*80+x)];line+=ch>=32&&ch<127?ch:' ';}line.erase(line.find_last_not_of(' ')+1);lines.push_back(line);screen+=line+"\n";}
   string last_line;for(auto& line:lines)if(!line.empty())last_line=line;bool prompt=last_line=="A:\\>";
   auto has=[&](const string& v){return screen.find(v)!=string::npos;};
   auto lineis=[&](const string& v){return find(lines.begin(),lines.end(),v)!=lines.end();};
   auto key=[&](uint8_t code){keys.push_back(code);keys.push_back(0xf0);keys.push_back(code);};
   auto type=[&](string text){map<char,uint8_t> codes={{'a',0x1c},{'b',0x32},{'c',0x21},{'d',0x23},{'e',0x24},{'f',0x2b},{'g',0x34},{'h',0x33},{'i',0x43},{'j',0x3b},{'k',0x42},{'l',0x4b},{'m',0x3a},{'n',0x31},{'o',0x44},{'p',0x4d},{'q',0x15},{'r',0x2d},{'s',0x1b},{'t',0x2c},{'u',0x3c},{'v',0x2a},{'w',0x1d},{'x',0x22},{'y',0x35},{'z',0x1a},{' ',0x29},{'.',0x49},{'-',0x4e},{'\r',0x5a}};
    for(char ch:text){if(ch=='>'){keys.push_back(0x12);key(0x49);keys.push_back(0xf0);keys.push_back(0x12);}else key(codes.at(ch));}
   };
   auto capture=[&](string name){ofstream f(name+".bin",ios::binary);f.write((char*)mem.data(),mem.size());cout<<"CAPTURE "<<name<<"\n";};
   bool idle=keys.empty() && key_bit<0 && tick>key_start+400000;
   switch(scenario){
    case 12:if(idle && has("SIO BIOS PASS")){cout<<"PASS native BIOS INT 14h serial loopback\n";type("demo\r");scenario=3;}break;
    case 0:if(prompt){if(int(mem[0x413])+256*int(mem[0x414])!=ram_blocks*64)throw runtime_error("Native POST RAM size differs from the fitted memory");cout<<"DOS BOOTED at "<<double(tick)/200000000<<" s RAM "<<int(mem[0x413])+256*int(mem[0x414])<<" KiB\n";capture("dos");if(boot_only){cout<<"RESULT: PASS boot, options "<<cfg<<" RAM "<<ram_blocks*64<<" KiB display "<<display<<"\n";success=true;break;}type(persist?"type test.txt\r":"echo junior-xt runtime pass > test.txt\r");scenario=1;phase_tick=tick;}break;
    case 1:if(idle && prompt && tick>phase_tick+20000000){if(!persist)type("type test.txt\r");scenario=2;phase_tick=tick;}break;
    case 2:if(idle && prompt && lineis("junior-xt runtime pass")){cout<<"PASS "<<(persist?"persisted":"new")<<" DOS file contents\n";type(persist?"del test.txt\r":"siotest\r");scenario=persist?10:12;phase_tick=tick;}break;
    case 3:if(idle && has("640x200 monochrome")){capture("demo-text");video_request="demo-text";scenario=30;}break;
    case 30:if(captured_video.count("demo-text")){key(0x26);scenario=4;phase_tick=tick;}break;
    case 4:if(idle && mem[0x449]==4 && tick>phase_tick+40000000){for(unsigned i=0;i<16384;i+=2){uint16_t v=i;v^=(v&255)<<8;if(mem[0x850000+i]!=(v&255)||mem[0x850001+i]!=(v>>8))throw runtime_error("Native CGA colour VRAM mismatch");}capture("demo-color");video_request="demo-color";scenario=40;}break;
    case 40:if(captured_video.count("demo-color")){key(0x29);scenario=5;}break;
    case 5:if(idle && has("640x200 monochrome")){key(0x25);scenario=6;phase_tick=tick;}break;
    case 6:if(idle && mem[0x449]==6 && tick>phase_tick+40000000){for(unsigned i=0;i<16384;i++)if(mem[0x850000+i]!=(i%2?0x55:0xaa))throw runtime_error("Native CGA monochrome VRAM mismatch");capture("demo-mono");video_request="demo-mono";scenario=60;}break;
    case 60:if(captured_video.count("demo-mono")){key(0x29);scenario=7;}break;
    case 7:if(idle && has("640x200 monochrome")){key(0x1b);scenario=8;phase_tick=tick;}break;
    case 8:if(idle && tick>phase_tick+80000000){key(0x76);scenario=9;}break;
    case 9:if(idle && prompt){if(speaker_edges<200 || !writes)throw runtime_error("Missing native speaker waveform or disk writes");cout<<"SPEAKER EDGES "<<speaker_edges<<"\n";cout<<"PASS native keyboard, CGA modes, speaker and return to DOS\n";success=true;}break;
    case 10:if(idle && prompt && tick>phase_tick+40000000){type("dir test.txt\r");scenario=11;phase_tick=tick;}break;
    case 11:if(idle && (has("not found")||has("Not Found")||has("No files"))){cout<<"PASS DOS delete persisted file\n";success=true;}break;
   }
   if(tick%20000000ULL==0){cout<<"SECOND "<<double(tick)/200000000<<" PC "<<hex<<t.pc_fetch<<" CX "<<t.reg_cx<<" SI "<<t.reg_si<<" PB "<<int(t.port_b)<<" RAM "<<int(mem[0x413])+256*int(mem[0x414])<<dec<<" disk R/W "<<reads<<"/"<<writes<<" FDC "<<int(t.rootp->junior_sim__DOT__u_chipset__DOT__u_PERIPHERALS__DOT__floppy__DOT__state)<<" IRQ "<<int(t.rootp->junior_sim__DOT__u_chipset__DOT__u_PERIPHERALS__DOT__fdd_interrupt)<<" phase "<<scenario<<"\n"<<screen;cout.flush();}
   if(winchester && has("HD FAIL"))throw runtime_error("Fixed disk check failed on the guest");
   if(winchester && has("HD PASS")){cout<<screen<<"RESULT: PASS Winchester ROM boot, fixed disk reads "<<hd_reads<<" writes "<<hd_writes<<"\n";success=true;}
   if(success && (boot_only||winchester))break;
   if(success){cout<<"RESULT: PASS native unmodified BIOS, 640 KiB POST, floppy DMA, FreeDOS and "<<(persist?"independent disk persistence":"CGA/keyboard/speaker demo")<<"\n";break;}
  }

 }
 if(!hd.empty()){ofstream h("hd-modified.img",ios::binary);h.write((char*)hd.data(),hd.size());}
 ofstream out("memory.bin",ios::binary);out.write((char*)mem.data(),mem.size());ofstream d("modified.img",ios::binary);d.write((char*)disk.data(),disk.size());
 t.final();cout<<"FETCH "<<hex<<t.pc_fetch<<" STATUS "<<int(t.cpu_status)<<dec<<" ";cout<<"FINISH disk reads "<<reads<<" writes "<<writes<<"\n";return success?0:1;
}
