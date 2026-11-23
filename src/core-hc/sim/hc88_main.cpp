// SPDX-License-Identifier: GPL-3.0-or-later
#include "Vhc88_sim.h"
#include "verilated.h"
#include <array>
#include <vector>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <iomanip>
#include <map>
#include <algorithm>
struct Sim {
 Vhc88_sim m;uint64_t cycles=0;std::vector<unsigned char> disk;std::array<unsigned char,896*312> pixels{};
 bool old_fetch=false,old_iow=false,old_beeper=false;
 unsigned beeper_edges=0;std::array<unsigned char,16384> vram{};std::array<unsigned char,768> font{};
 bool command_wait=true;
 std::string text,prefix="build/hc88-boot";std::ofstream io;int sdstate=0,byte=0,sub=0,hold=0,drive=0;bool writing=false;
 uint32_t lba=0;uint16_t lastpc=0,lastaddr=0,console_pc=0xe60c,held_address=0;unsigned reads=0,writes=0;unsigned long long io_count=0;
 void tick(){
  m.sd_buff_wr=0;
  if(bool(m.beeper)!=old_beeper)++beeper_edges;old_beeper=m.beeper;
  if(m.debug_mem_wr && (m.debug_command&1) && ((m.debug_command&8) || (!(m.debug_command&32) && (m.debug_addr>>14)==1)))vram[m.debug_addr&16383]=m.debug_data;
  if(!sdstate && (m.sd_rd || m.sd_wr)){
   writing=m.sd_wr;drive=((m.sd_rd|m.sd_wr)&1)?0:1;lba=m.sd_lba;byte=0;sub=0;sdstate=1;m.sd_ack=1;
   if(drive)throw std::runtime_error("Unexpected empty drive B request");
   if(writing)++writes;else ++reads;
  }
  if(sdstate==1){
   m.sd_buff_addr=byte;
   if(!writing){m.sd_buff_wr=1;m.sd_buff_dout=size_t(lba)*512+byte<disk.size()?disk[size_t(lba)*512+byte]:0;}
   if(++sub==3){
    sub=0;
    if(writing && size_t(lba)*512+byte<disk.size())disk[size_t(lba)*512+byte]=m.sd_buff_din;
    if(++byte==512){sdstate=2;hold=32;}
   }
  } else if(sdstate==2){if(--hold==0){m.sd_ack=0;sdstate=3;}}
  else if(sdstate==3 && !(m.sd_rd|m.sd_wr))sdstate=0;
  m.clk=0;m.eval();
  if(m.ce_pixel && m.video_x<896 && m.video_y<312)pixels[m.video_y*896+m.video_x]=m.rgb|(m.bright?8:0);
  if(m.debug_io_wr && !old_iow){
   if((m.debug_io_wr && ((m.debug_addr&255)!=0xc2 || cycles<5000000)) || (false && (m.debug_addr&255)!=0x90 && (m.debug_addr&255)!=0xc2))io<<std::hex<<cycles<<" "<<(m.debug_io_wr?'W':'R')<<" "<<unsigned(m.debug_addr&255)<<" "<<unsigned(m.debug_io_wr?m.debug_data:m.debug_in)<<" pc="<<m.debug_pc<<std::endl;
  }
  if(m.debug_fetch && !old_fetch && m.debug_addr==console_pc){char c=m.debug_char;text+=c;if(c>=32 || c=='\r' || c=='\n')std::cout<<c<<std::flush;}
  if(cycles && cycles%56000000==0)std::cerr<<"["<<cycles/56000000<<"s PC="<<std::hex<<m.debug_pc<<std::dec<<" DMA="<<0<<" SD="<<reads<<"/"<<writes<<"]\n";
  old_iow=m.debug_io_wr;old_fetch=m.debug_fetch;lastaddr=m.debug_addr;lastpc=m.debug_pc;m.clk=1;m.eval();++cycles;
 }
 void run(uint64_t n){while(n--)tick();}
 static std::string visible(const std::string& raw){
  std::string out;
  for(size_t i=0;i<raw.size();++i){
   unsigned char c=raw[i];
   if(c==27 && i+1<raw.size()){char op=raw[++i];if(op=='Y' || op=='=')i+=2;continue;}
   if(c>=32 || c=='\r' || c=='\n' || c=='\t')out+=c;
  }
  return out;
 }
 void waitFor(const std::string& needle,size_t start,uint64_t limit){
  uint64_t deadline=cycles+limit;size_t checked=~size_t(0);bool found=false;
  while(!found && cycles<deadline){
   if(text.size()!=checked){checked=text.size();auto plain=visible(text.substr(start));found=plain.find(needle)!=std::string::npos;
    if(plain.find("Bdos Err")!=std::string::npos){save();throw std::runtime_error("Native CP/M disk error");}}
   if(!found)tick();
  }
  if(!found){save();throw std::runtime_error("Native output not found: "+needle);}
 }
 void key(unsigned scan,bool down=true){m.ps2_key=((m.ps2_key^1024)&1024)|(down?512:0)|scan;run(4000);}
 void type(const std::string &s){
  const std::map<char,int> keys={{'a',0x1c},{'b',0x32},{'c',0x21},{'d',0x23},{'e',0x24},{'f',0x2b},{'g',0x34},{'h',0x33},{'i',0x43},{'j',0x3b},{'k',0x42},{'l',0x4b},{'m',0x3a},{'n',0x31},{'o',0x44},{'p',0x4d},{'q',0x15},{'r',0x2d},{'s',0x1b},{'t',0x2c},{'u',0x3c},{'v',0x2a},{'w',0x1d},{'x',0x22},{'y',0x35},{'z',0x1a},{'0',0x45},{'1',0x16},{'2',0x1e},{'3',0x26},{'4',0x25},{'5',0x2e},{'6',0x36},{'7',0x3d},{'8',0x3e},{'9',0x46},{' ',0x29},{'.',0x49},{',',0x41},{'\r',0x5a},{'\n',0x5a},{'=',0x55},{'-',0x4e}};
  for(unsigned char c:s){size_t before=text.size();bool shift=c>='A'&&c<='Z';char lower=shift?c+32:c;
   auto it=keys.find(lower);if(it==keys.end())throw std::runtime_error("Unsupported scripted key");
   key(it->second);
   if(c!='\r' && c!='\n')waitFor(std::string(1,(c>='a'&&c<='z')?c-32:c),before,12000000);
   else run(200000);
   key(it->second,false);
   if(c!='\r' && c!='\n'){
    uint64_t deadline=cycles+12000000;
    do{m.peek_address=held_address;m.eval();if(!m.peek_ram)break;tick();}while(cycles<deadline);
    if(cycles>=deadline)throw std::runtime_error("Keyboard release was not scanned");
   }
   if((c=='\r' || c=='\n') && !disk.empty() && command_wait)waitFor("A>",before,200000000);
  }
 }
 std::string basicScreen(){
  std::string result;
  for(unsigned row=0;row<24;++row){for(unsigned col=0;col<32;++col){
   char found='?';for(unsigned c=32;c<127;++c){bool same=true;
    for(unsigned line=0;line<8;++line){unsigned y=row*8+line,addr=((y&0xc0)<<5)+((y&7)<<8)+((y&0x38)<<2)+col;
     if(vram[addr]!=font[(c-32)*8+line]){same=false;break;}}
    if(same){found=c;break;}}
   result+=found;}result+='\n';}return result;
 }
 void waitBasic(const std::string& needle,uint64_t limit){
  uint64_t end=cycles+limit;while(cycles<end){run(560000);if(basicScreen().find(needle)!=std::string::npos)return;}
  save();throw std::runtime_error("BASIC display not found: "+needle+"\n"+basicScreen());
 }
 void press(unsigned scan,bool symbol=false){if(symbol)key(0x14);key(scan);run(4480000);key(scan,false);if(symbol)key(0x14,false);run(5600000);}
 void tape(const std::string& path){std::ifstream f(path,std::ios::binary);std::vector<unsigned char>b((std::istreambuf_iterator<char>(f)),{});
  if(b.size()<10)throw std::runtime_error("Missing cassette test");m.tape_mode=2;m.tape_download=1;run(8);
  for(unsigned n=0;n<b.size();++n){m.tape_wr=1;m.tape_addr=n;m.tape_data=b[n];tick();}m.tape_wr=0;m.tape_download=0;tick();
 }
 void exercise(const std::string& cassette,bool basic_only=false){
  waitFor("A>",0,280000000);
  auto base=prefix;size_t begin=0;
  if(!basic_only){
  type("dir\r");type("drives\r");type("type hello.txt\r");type("track\r");
  if(text.find("B: not ready")==std::string::npos)throw std::runtime_error("Empty drive was not rejected");
  if(text.find("HC-88 native floppy read test OK.")==std::string::npos)throw std::runtime_error("Native TYPE failed");
  type("write\r");type("type check.txt\r");
  if(text.find("PASS: native BDOS create/write/close/read/compare")==std::string::npos || text.find("HC-88 persistent floppy write verified.")==std::string::npos || writes==0)throw std::runtime_error("Native persistent write failed");
  save();prefix=base+"-demo";
  command_wait=false;begin=text.size();type("demo\r");waitFor("Press a key",begin,168000000);run(16800000);save();
  if(beeper_edges<50 || !(m.debug_command&16))throw std::runtime_error("Native demo did not exercise sound/512-pixel mode");
  begin=text.size();key(0x29);run(200000);key(0x29,false);waitFor("A>",begin,168000000);
  }
  command_wait=false;prefix=base+"-basic";type("basic\r");waitBasic("FELI",336000000);
  press(0x4d);press(0x1e);press(0x42,true);press(0x1e);press(0x5a);waitBasic("4",56000000);save();
  std::ofstream basic(prefix+"-text.txt");basic<<basicScreen();basic.close();
  press(0x3b);press(0x4d,true);press(0x4d,true);press(0x5a);tape(cassette);
  waitBasic("7319",1120000000);prefix=base+"-tape";save();std::ofstream loaded(prefix+"-text.txt");loaded<<basicScreen();loaded.close();
  prefix=base+"-reset";begin=text.size();key(0x78);run(10000);key(0x78,false);waitFor("A>",begin,280000000);
  command_wait=true;type("type check.txt\r");
  std::ofstream result(base+"-exercise.json");result<<"{\"status\":\"passed\",\"mode\":\""<<(basic_only?"basic-only":"full")<<"\",\"native_original_bootstrap\":true,\"runtime_basic\":true,\"ear_tape\":true,\"f11_restart\":true}\n";
 }
 void save(){
  std::ofstream ppm(prefix+".ppm",std::ios::binary);ppm<<"P6\n896 312\n255\n";for(auto p:pixels){int level=(p&8)?255:192;ppm.put((p&2)?level:0);ppm.put((p&4)?level:0);ppm.put((p&1)?level:0);}
  std::ofstream txt(prefix+"-console.txt",std::ios::binary);txt<<text;
  std::ofstream plain(prefix+"-console-clean.txt",std::ios::binary);plain<<visible(text);
  std::ofstream mem(prefix+"-ram.bin",std::ios::binary),vram(prefix+"-vram.bin",std::ios::binary);
 for(unsigned a=0;a<65536;++a){m.peek_address=a;tick();tick();mem.put(m.peek_ram);if(a<16384)vram.put(m.peek_vram);}
  std::ofstream out(prefix+"-disk.dsk",std::ios::binary);if(writes)out.write((char*)disk.data(),disk.size());
  std::ofstream status(prefix+"-status.json");status<<"{\"cycles\":"<<cycles<<",\"pc\":"<<m.debug_pc<<",\"unused\":"<<0<<",\"sd_reads\":"<<reads<<",\"sd_writes\":"<<writes<<",\"keyboard_overflow\":"<<0<<"}\n";
  std::cout<<"\nPC="<<std::hex<<m.debug_pc<<std::dec<<" DMA="<<0<<" SD="<<reads<<"/"<<writes<<" cycles="<<cycles<<"\n";
 }
};
int main(int argc,char**argv){try{
 Verilated::commandArgs(argc,argv);Sim s;std::string rom="assets/roms/family.rom",disk="assets/disks/hc88/system.dsk",command,until;double seconds=3;std::string cassette;bool basic_only=false;
 for(int i=1;i<argc;++i){std::string a=argv[i];if(a=="--rom")rom=argv[++i];else if(a=="--disk")disk=argv[++i];else if(a=="--seconds")seconds=std::stod(argv[++i]);else if(a=="--type")command=argv[++i];else if(a=="--until")until=argv[++i];else if(a=="--type-file"){std::ifstream q(argv[++i],std::ios::binary);command.assign(std::istreambuf_iterator<char>(q),{});}else if(a=="--exercise")cassette=argv[++i];else if(a=="--basic-only")basic_only=true;else if(a=="--output")s.prefix=argv[++i];else throw std::runtime_error("Unknown argument "+a);}
 std::ifstream symbols("build/hc88-software/bios.sym");std::string label,equ,value;
 while(symbols>>label>>equ>>value){if(label=="conout")s.console_pc=std::stoul(value,nullptr,16);if(label=="held")s.held_address=std::stoul(value,nullptr,16);}
 s.io.open(s.prefix+"-io.txt");s.m.reset=1;s.m.requested_model=3;s.run(128);
 std::ifstream f(rom,std::ios::binary);std::vector<unsigned char> firmware((std::istreambuf_iterator<char>(f)),{});if(firmware.size()!=65536)throw std::runtime_error("Need complete HC family firmware");
 s.m.reset=0;s.m.rom_download=1;s.run(8);
 for(unsigned a=0;a<firmware.size();++a){s.m.rom_write=1;s.m.rom_address=a;s.m.rom_byte=firmware[a];s.tick();}

 s.m.rom_write=0;s.m.rom_download=0;s.run(512);
 if(!disk.empty()){
  std::ifstream d(disk,std::ios::binary);s.disk.assign(std::istreambuf_iterator<char>(d),{});if(s.disk.size()<512)throw std::runtime_error("Missing disk");
  s.m.img_size=s.disk.size();s.m.img_wp=0;s.m.img_mounted=1;s.run(1000);s.m.img_mounted=0;s.run(1000);
 }
 std::ifstream fontfile("assets/roms/hc85.rom",std::ios::binary);fontfile.seekg(0x3d00);fontfile.read((char*)s.font.data(),s.font.size());
 s.m.reset=0;
 if(until.empty())s.run(uint64_t(seconds*56000000));
 else s.waitFor(until,0,uint64_t(seconds*56000000));
 if(!cassette.empty())s.exercise(cassette,basic_only);

 if(!command.empty()){s.type(command);s.run(56000000);}
 s.save();return 0;
 }catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}}
