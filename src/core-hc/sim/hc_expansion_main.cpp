// SPDX-License-Identifier: GPL-3.0-or-later
#include "Vhc_expansion_sim.h"
#include "verilated.h"
#include <array>
#include <vector>
#include <fstream>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
struct Sim {
 Vhc_expansion_sim m;uint64_t cycles=0;std::array<std::vector<unsigned char>,2> disks;
 std::array<unsigned char,896*312> pixels{};std::ofstream log;std::string prefix;
 unsigned reads=0,writes=0;std::array<unsigned,2> drive_reads{},drive_writes{};int state=0,byte=0,sub=0,hold=0,drive=0;bool writing=false,oldio=false;
 uint32_t lba=0;unsigned lastpc=0;std::array<unsigned char,768> cpm_font{},basic_rom_font{};
 void tick(){
  m.sd_buff_wr=0;
  if(!state && (m.sd_rd||m.sd_wr)){
   writing=m.sd_wr;drive=((m.sd_rd|m.sd_wr)&1)?0:1;lba=m.sd_lba;byte=0;sub=0;state=1;m.sd_ack=1;
   if(disks[drive].empty())throw std::runtime_error("Empty drive requested");if(writing){++writes;++drive_writes[drive];}else{++reads;++drive_reads[drive];}
  }
  if(state==1){m.sd_buff_addr=byte;
   if(!writing){m.sd_buff_wr=1;m.sd_buff_dout=size_t(lba)*512+byte<disks[drive].size()?disks[drive][size_t(lba)*512+byte]:0;}
   if(++sub==3){sub=0;if(writing && size_t(lba)*512+byte<disks[drive].size())disks[drive][size_t(lba)*512+byte]=m.sd_buff_din;if(++byte==512){state=2;hold=32;}}
  }else if(state==2){if(!--hold){m.sd_ack=0;state=3;}}
  else if(state==3 && !(m.sd_rd|m.sd_wr))state=0;
  m.clk=0;m.eval();
  if(m.ce_pixel && m.video_x<896 && m.video_y<312)pixels[m.video_y*896+m.video_x]=m.rgb|(m.bright?8:0);
  if(m.debug_io_wr && !oldio && (m.debug_addr&255)!=254)log<<std::hex<<cycles<<" "<<unsigned(m.debug_addr)<<" "<<unsigned(m.debug_data)<<" pc="<<m.debug_pc<<std::endl;
  if(cycles && cycles%56000000==0)std::cerr<<"["<<cycles/56000000<<"s PC="<<std::hex<<m.debug_pc<<std::dec<<" SD="<<reads<<"/"<<writes<<"]\n";
  oldio=m.debug_io_wr;m.clk=1;m.eval();++cycles;
 }
 void run(double s){uint64_t n=s*56000000;while(n--)tick();}
 void key(int scan,bool down){m.ps2_key=((m.ps2_key^1024)&1024)|(down?512:0)|scan;run(.003);}
 void press(int scan){key(scan,true);run(.08);key(scan,false);run(.1);}
 void matrix(uint64_t keys,double seconds){m.extra_keys_n=((1ULL<<40)-1)^keys;run(seconds);m.extra_keys_n=(1ULL<<40)-1;run(.1);}
 void cpmCommand(){press(0x4d);matrix((1ULL<<0)|(1ULL<<36),.08);press(0x4b);for(int sc:{0x16,0x25,0x25,0x25,0x36})press(sc);press(0x5a);}
 bool cpmPrompt(){
  for(int row=0;row<24;++row){bool same=true;
   for(int col=0;col<2 && same;++col){char c=col?'>' : 'A';
    for(int y=0;y<8 && same;++y)for(int x=0;x<4;++x){bool ink=(pixels[(row*8+y)*896+col*4+x]&7)==0;
     if(ink!=bool(cpm_font[(c-32)*8+y]&(1<<(3-x)))){same=false;break;}}
   }if(same)return true;
  }return false;
 }
 void waitCpm(double timeout){
  uint64_t end=cycles+uint64_t(timeout*56000000);bool visible=false;
  while(cycles<end){if(cycles%100000==0)visible=cpmPrompt();
   if(visible && m.debug_fetch && (m.debug_addr==0xe0a9 || m.debug_addr==0xe0aa))return;tick();}
  save();throw std::runtime_error("Native CP/M prompt did not become ready");
 }
 void waitBasic(double timeout){
  uint64_t end=cycles+uint64_t(timeout*56000000);
  while(cycles<end){if(m.debug_fetch && m.debug_addr>=0x15e6 && m.debug_addr<=0x15ff &&
   m.debug_command==0 && m.debug_in==basic_rom_font[m.debug_addr-0x15e0]){run(.05);return;}tick();}
  save();throw std::runtime_error("Native BASIC input did not become ready");
 }
 void save(){
  std::ofstream ppm(prefix+".ppm",std::ios::binary);int width=m.requested_model==3?896:448;ppm<<"P6\n"<<width<<" 312\n255\n";
  for(int y=0;y<312;++y)for(int x=0;x<width;++x){unsigned char c=pixels[y*896+x],level=(m.requested_model==0 || c&8)?255:192;char v[3]={char(c&2?level:0),char(c&4?level:0),char(c&1?level:0)};ppm.write(v,3);}
  std::ofstream ram(prefix+".ram",std::ios::binary),vram(prefix+".vram",std::ios::binary);
  for(unsigned a=0;a<65536;++a){m.peek_address=a;m.eval();char c=m.peek_ram;ram.write(&c,1);if(a<16384){c=m.peek_vram;vram.write(&c,1);}}
  std::ofstream status(prefix+".json");status<<"{\"cycles\":"<<cycles<<",\"pc\":"<<m.debug_pc<<",\"sd_reads\":"<<reads<<",\"sd_writes\":"<<writes<<",\"drive_reads\":["<<drive_reads[0]<<","<<drive_reads[1]<<"],\"drive_writes\":["<<drive_writes[0]<<","<<drive_writes[1]<<"]}\n";
  for(int i=0;i<2;++i)if(!disks[i].empty()){std::ofstream d(prefix+"-disk"+std::to_string(i)+".dsk",std::ios::binary);d.write((char*)disks[i].data(),disks[i].size());}
  std::cout<<"PC="<<std::hex<<m.debug_pc<<std::dec<<" SD="<<reads<<"/"<<writes<<" clocks="<<cycles<<"\n";
 }
};
int main(int argc,char**argv){try{
 Verilated::commandArgs(argc,argv);Sim s;int model=4;double seconds=3;bool bootcpm=false,interface=false,breakboot=false,startcpm=false;std::string rom="assets/roms/family.rom",script;
 s.prefix="build/expansion";
 for(int i=1;i<argc;++i){std::string a=argv[i];if(a=="--model")model=std::stoi(argv[++i]);else if(a=="--seconds")seconds=std::stod(argv[++i]);else if(a=="--if1")interface=true;else if(a=="--boot-cpm")startcpm=true;else if(a=="--break")breakboot=true;else if(a=="--cpm")bootcpm=true;else if(a=="--rom")rom=argv[++i];else if(a=="--script")script=argv[++i];else if(a=="--output")s.prefix=argv[++i];else if(a=="--disk" || a=="--disk-b"){int drive=a=="--disk"?0:1;std::ifstream f(argv[++i],std::ios::binary);s.disks[drive].assign(std::istreambuf_iterator<char>(f),{});if(s.disks[drive].size()<512)throw std::runtime_error("Missing disk");}else throw std::runtime_error("Unknown argument "+a);}
 std::ifstream font("assets/roms/hc2000-1.rom",std::ios::binary);font.seekg(0x25ab);font.read((char*)s.cpm_font.data(),760);
 std::ifstream basic("assets/roms/hc85.rom",std::ios::binary);basic.seekg(0x15e0);basic.read((char*)s.basic_rom_font.data(),32);
 s.log.open(s.prefix+"-io.txt");s.m.requested_model=model;s.m.interface_enable=interface;s.m.ay_enable=1;s.m.boot_cpm=startcpm;s.m.serial_rx=1;s.m.serial_ready=1;s.m.extra_keys_n=((1ULL<<40)-1)^(breakboot?((1ULL<<0)|(1ULL<<35)):0);
 s.m.reset=1;s.run(.00001);s.m.reset=0;s.m.rom_download=1;s.run(.00001);
 std::ifstream f(rom,std::ios::binary);std::vector<unsigned char> firmware((std::istreambuf_iterator<char>(f)),{});if(firmware.size()!=65536)throw std::runtime_error("Missing complete family firmware");
 for(unsigned a=0;a<firmware.size();++a){s.m.rom_write=1;s.m.rom_address=a;s.m.rom_byte=firmware[a];s.tick();}
 s.m.rom_write=0;s.m.rom_download=0;s.run(.0001);
 for(int i=0;i<2;++i)if(!s.disks[i].empty()){s.m.img_size=s.disks[i].size();s.m.img_wp=0;s.m.img_mounted=1<<i;s.run(.0001);s.m.img_mounted=0;s.run(.0001);}

 s.run(seconds);s.m.extra_keys_n=(1ULL<<40)-1;
 if(bootcpm){s.cpmCommand();s.waitCpm(20);}
 if(startcpm || breakboot)s.waitCpm(20);
 if(!script.empty()){
  std::ifstream in(script);std::string op;
  while(in>>op){if(op=="basic_ready")s.waitBasic(45);else if(op=="cpm_ready")s.waitCpm(20);else if(op=="run"){double n;in>>n;s.run(n);}else if(op=="press"){int n;in>>std::hex>>n>>std::dec;s.press(n);}else if(op=="matrix"){uint64_t n;double seconds;in>>std::hex>>n>>std::dec>>seconds;s.matrix(n,seconds);}else if(op=="reset"){s.key(0x78,true);s.run(.01);s.key(0x78,false);}else throw std::runtime_error("Unknown script operation");}
 }
 s.save();return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}}
