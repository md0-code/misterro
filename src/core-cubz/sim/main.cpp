// SPDX-License-Identifier: GPL-3.0-or-later
#include "Vcubz_core.h"
#include "verilated.h"
#include <array>
#include <vector>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <iomanip>
#include <map>
struct Sim {
 Vcubz_core m;uint64_t cycles=0;std::vector<unsigned char> disk;std::array<unsigned char,512*256> pixels{};
 bool first_dma_checked=false;
 bool command_wait=true;
 std::string text,prefix="build/monitor";std::ofstream io;int sdstate=0,byte=0,sub=0,hold=0,drive=0;bool writing=false;
 uint32_t lba=0;uint16_t lastpc=0,lastaddr=0,console_pc=0xeb7b;unsigned reads=0,writes=0;unsigned long long io_count=0;
 void tick(){
  m.sd_buff_wr=0;
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
  if(!disk.empty() && !first_dma_checked && m.debug_dma>=2048){
   first_dma_checked=true;
   // Sample physical RAM after the ROM boot DMA; original EDSK first sector.
   for(unsigned a=0;a<128;++a){m.peek_addr=0x3000+a;tick();tick();
    if(m.peek_data!=disk[512+a])throw std::runtime_error("Boot DMA byte mismatch at "+std::to_string(a)+" expected "+std::to_string(disk[512+a])+" actual "+std::to_string(m.peek_data));}
   std::cerr<<"PASS: boot DMA copied original sector bytes to physical RAM\n";
  }
  m.clk=0;m.eval();
  if(m.ce_pixel && m.video_x<512 && m.video_y<256)pixels[m.video_y*512+m.video_x]=m.pixel?255:0;
  if(m.debug_io_wr || m.debug_io_rd){
   if((m.debug_io_wr && ((m.debug_addr&255)!=0xc2 || cycles<5000000)) || (m.debug_io_rd && (m.debug_addr&255)!=0x90 && (m.debug_addr&255)!=0xc2))io<<std::hex<<cycles<<" "<<(m.debug_io_wr?'W':'R')<<" "<<unsigned(m.debug_addr&255)<<" "<<unsigned(m.debug_io_wr?m.debug_data:m.debug_in)<<" pc="<<m.debug_pc<<std::endl;
  }
  if(m.debug_addr!=lastaddr && m.debug_addr==console_pc){char c=m.debug_char;text+=c;if(c>=32 || c=='\r' || c=='\n')std::cout<<c<<std::flush;}
  if(cycles && cycles%40000000==0)std::cerr<<"["<<cycles/40000000<<"s PC="<<std::hex<<m.debug_pc<<std::dec<<" DMA="<<m.debug_dma<<" SD="<<reads<<"/"<<writes<<"]\n";
  lastaddr=m.debug_addr;lastpc=m.debug_pc;m.clk=1;m.eval();++cycles;
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
   if(shift)key(0x12);key(it->second);key(it->second,false);if(shift)key(0x12,false);run(1200000);
   if((c=='\r' || c=='\n') && !disk.empty() && command_wait)waitFor("A>",before,200000000);
  }
 }
 void save(){
  std::ofstream ppm(prefix+".ppm",std::ios::binary);ppm<<"P6\n512 256\n255\n";for(auto p:pixels)for(int i=0;i<3;++i)ppm.put(p);
  std::ofstream txt(prefix+"-console.txt",std::ios::binary);txt<<text;
  std::ofstream plain(prefix+"-console-clean.txt",std::ios::binary);plain<<visible(text);
  std::ofstream mem(prefix+"-ram.bin",std::ios::binary),vram(prefix+"-vram.bin",std::ios::binary);
  for(unsigned a=0;a<65536;++a){m.peek_addr=a;tick();tick();mem.put(m.peek_data);if(a<16384)vram.put(m.peek_video);}
  std::ofstream out(prefix+"-disk.dsk",std::ios::binary);if(writes)out.write((char*)disk.data(),disk.size());
  std::ofstream status(prefix+"-status.json");status<<"{\"cycles\":"<<cycles<<",\"pc\":"<<m.debug_pc<<",\"dma_bytes\":"<<m.debug_dma<<",\"sd_reads\":"<<reads<<",\"sd_writes\":"<<writes<<",\"keyboard_overflow\":"<<unsigned(m.keyboard_overflow)<<"}\n";
  std::cout<<"\nPC="<<std::hex<<m.debug_pc<<std::dec<<" DMA="<<m.debug_dma<<" SD="<<reads<<"/"<<writes<<" cycles="<<cycles<<"\n";
 }
};
int main(int argc,char**argv){try{
 Verilated::commandArgs(argc,argv);Sim s;std::string rom="assets/roms/cubz-v14.rom",disk,command,until;double seconds=3;bool turbo=false;
 for(int i=1;i<argc;++i){std::string a=argv[i];if(a=="--rom")rom=argv[++i];else if(a=="--disk")disk=argv[++i];else if(a=="--seconds")seconds=std::stod(argv[++i]);else if(a=="--type")command=argv[++i];else if(a=="--until")until=argv[++i];else if(a=="--type-file"){std::ifstream q(argv[++i],std::ios::binary);command.assign(std::istreambuf_iterator<char>(q),{});}else if(a=="--exercise-turbo")turbo=true;else if(a=="--output")s.prefix=argv[++i];else throw std::runtime_error("Unknown argument "+a);}
 s.io.open(s.prefix+"-io.txt");s.m.serial_rx=3;s.m.gpio_a_in=255;s.m.reset=1;s.m.video_reset=1;s.run(128);
 std::ifstream f(rom,std::ios::binary);std::vector<unsigned char> firmware((std::istreambuf_iterator<char>(f)),{});if(firmware.size()!=8192)throw std::runtime_error("Need original 8K firmware layout");
 for(unsigned a=0;a<firmware.size();++a){s.m.rom_wr=1;s.m.rom_addr=a;s.m.rom_data=firmware[a];s.tick();}
 s.console_pc=firmware[0x180a]|(firmware[0x180b]<<8);
 s.m.rom_wr=0;s.m.video_reset=0;
 if(!disk.empty()){
  std::ifstream d(disk,std::ios::binary);s.disk.assign(std::istreambuf_iterator<char>(d),{});if(s.disk.size()<512)throw std::runtime_error("Missing disk");
  s.m.img_size=s.disk.size();s.m.img_wp=0;s.m.img_mounted=1;s.run(1000);s.m.img_mounted=0;s.run(2000000);
 }
 s.m.reset=0;
 if(until.empty())s.run(uint64_t(seconds*40000000));
 else s.waitFor(until,0,uint64_t(seconds*40000000));
 if(turbo){
  s.command_wait=false;auto begin=s.text.size();s.type("TURBO\r");s.waitFor("Include error messages",begin,400000000);
  begin=s.text.size();s.type("N");s.waitFor("Logged drive:",begin,200000000);s.waitFor(">",begin,200000000);
  auto old=s.prefix;s.prefix+="-turbo";s.save();s.prefix=old;
  begin=s.text.size();s.type("Q");s.waitFor("A>",begin,200000000);s.command_wait=true;
 }

 if(!command.empty()){s.type(command);s.run(40000000);}
 s.save();return 0;
 }catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}}
