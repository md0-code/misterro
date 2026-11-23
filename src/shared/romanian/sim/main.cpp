// SPDX-License-Identifier: GPL-3.0-or-later
#include "Vmachine_core.h"
#include "verilated.h"
#include <vector>
#include <array>
#include <fstream>
#include <iostream>
#include <iomanip>
#include <map>
#include <stdexcept>
#include <cstdint>
struct Sim {
 Vmachine_core m;uint64_t cycles=0;bool loopback=false;
 bool recording=false,record_level=0,last_mic=0,playing=false;uint64_t last_change=0,tape_left=0,tape_fraction=0;size_t tape_index=0;
 std::string record_path;std::vector<uint64_t> recorded;std::vector<unsigned char> printed;
 std::vector<std::pair<uint32_t,bool>> tape;
 static std::vector<unsigned char> load(std::string path){std::ifstream f(path,std::ios::binary);if(!f)throw std::runtime_error("Cannot open "+path);return {std::istreambuf_iterator<char>(f),{}};}
 void record(std::string path){recording=true;record_path=path;recorded.clear();last_change=cycles;last_mic=m.mic;record_level=m.mic;}
 void stop_record(){
  if(!recording)return;recorded.push_back(cycles-last_change);recording=false;std::vector<unsigned char> pulses;
  auto word=[&](unsigned n){pulses.push_back(n&255);pulses.push_back((n>>8)&255);};uint64_t fraction=0;
  if(record_level)word(0);
  for(auto cycles:recorded){uint64_t ticks=cycles*3500000+fraction;fraction=ticks%MACHINE_CLOCK;ticks/=MACHINE_CLOCK;
   if(ticks>32767){word(0x8001);word(0x8000|(ticks>>16));word(ticks&65535);}else word(ticks);
  }
  std::ofstream f(record_path,std::ios::binary);auto integer=[&](uint32_t n){for(int j=0;j<4;++j)f.put((n>>(j*8))&255);};
  f.write("PZXT",4);integer(2);f.put(1);f.put(0);f.write("PULS",4);integer(pulses.size());f.write((char*)pulses.data(),pulses.size());std::cerr<<"Recorded "<<recorded.size()<<" native MIC pulses\n";
 }
 void open_tape(std::string path){
  auto bytes=load(path);tape.clear();size_t at=0;bool level=false;
  auto word=[&](){if(at+2>bytes.size())throw std::runtime_error("Truncated tape");unsigned v=bytes[at]|(bytes[at+1]<<8);at+=2;return v;};
  auto pulse=[&](uint32_t n){tape.push_back({n,level});level=!level;};
  if(bytes.size()>=4&&std::string((char*)bytes.data(),4)=="PZXT"){
   while(at<bytes.size()){
    if(at+8>bytes.size())throw std::runtime_error("Truncated PZX chunk");std::string tag((char*)bytes.data()+at,4);at+=4;uint32_t n=word();n|=uint32_t(word())<<16;size_t end=at+n;if(end>bytes.size())throw std::runtime_error("PZX chunk allocation");
    if(tag=="PULS"){level=false;while(at<end){unsigned v=word(),count=1;if(v>0x8000){count=v&32767;v=word();}uint32_t duration=v;if(v&32768){duration=(uint32_t(v&32767)<<16)|word();}while(count--)pulse(duration);}}
    else if(tag=="PAUS"){uint32_t duration=word();duration|=uint32_t(word())<<16;tape.push_back({duration&0x7fffffff,bool(duration>>31)});}
    at=end;
   }
  }else{
   while(at<bytes.size()){unsigned size=word();if(size<2||at+size>bytes.size())throw std::runtime_error("Invalid TAP block");for(unsigned j=0;j<(bytes[at]==0?8063:3223);++j)pulse(2168);pulse(667);pulse(735);
    for(unsigned j=0;j<size;++j)for(int bit=7;bit>=0;--bit){unsigned duration=(bytes[at+j]&(1<<bit))?1710:855;pulse(duration);pulse(duration);}at+=size;tape.push_back({3500000,level});}
  }
  tape_index=0;tape_left=0;tape_fraction=0;playing=true;
 }
static constexpr int FrameWidth=MACHINE_CLOCK==84000000?896:512;
 std::array<unsigned char,FrameWidth*312> pixels{};
 std::vector<unsigned char> ext=std::vector<unsigned char>(32*1024*1024);std::array<std::vector<unsigned char>,4> disks;
 std::ofstream trace;std::string prefix="build/boot";int sdstate=0,byte=0,sub=0,hold=0,drive=0,extdelay=0;bool writing=false;uint32_t lba=0;unsigned reads=0,writes=0,io=0,memwrites=0,fetches=0;std::map<unsigned,unsigned> pcs;uint64_t last_read=~uint64_t(0);
 void tick(){
  if(loopback){m.serial_rx=m.serial_tx;m.serial_ready=(~m.serial_dtr)&31;m.serial_cts=(~m.serial_rts)&31;}
  if(playing){while(!tape_left&&tape_index<tape.size()){auto [duration,level]=tape[tape_index++];uint64_t n=uint64_t(duration)*MACHINE_CLOCK+tape_fraction;tape_left=n/3500000;tape_fraction=n%3500000;m.ear=level;}if(tape_left)--tape_left;else{playing=false;m.ear=1;}}
  if(recording&&m.mic!=last_mic){recorded.push_back(cycles-last_change);last_change=cycles;last_mic=m.mic;}
  m.sd_buff_wr=0;
  if(!sdstate && (m.sd_rd||m.sd_wr)){
   writing=m.sd_wr;drive=0;while(!((m.sd_rd|m.sd_wr)&(1<<drive)))++drive;lba=m.sd_lba;byte=0;sub=0;sdstate=1;m.sd_ack=1;if(writing)++writes;else ++reads;
   if(size_t(lba)*512+512>disks[drive].size())throw std::runtime_error("SD request outside mounted image");
  }
  if(sdstate==1){m.sd_buff_addr=byte;if(!writing){m.sd_buff_wr=1;m.sd_buff_dout=disks[drive][size_t(lba)*512+byte];}
   if(++sub==3){sub=0;if(writing)disks[drive][size_t(lba)*512+byte]=m.sd_buff_din;if(++byte==512){sdstate=2;hold=32;}}}
  else if(sdstate==2){if(--hold==0){m.sd_ack=0;sdstate=3;}}
  else if(sdstate==3 && !(m.sd_rd|m.sd_wr))sdstate=0;
  if(!m.ext_req){m.ext_ack=0;extdelay=0;}else if(!m.ext_ack && ++extdelay==8){if(m.ext_write)ext[m.ext_address]=m.ext_dout;m.ext_din=ext[m.ext_address];m.ext_ack=1;}
  m.clk=0;m.eval();
  if(m.ce_pixel&&m.video_x<FrameWidth&&m.video_y<312)pixels[m.video_y*FrameWidth+m.video_x]=(m.rgb&7)|(m.bright?8:0);
  if(m.debug_io_wr||m.debug_io_rd){++io;uint64_t read_key=(uint64_t(m.debug_addr)<<24)|(uint64_t(m.debug_pc)<<8)|m.debug_in;if(m.debug_io_wr||((m.debug_addr&255)!=0xfe&&(m.debug_addr&255)!=0x80&&(m.debug_addr&255)!=0x20&&(m.debug_addr&255)!=0x21&&read_key!=last_read))trace<<std::hex<<cycles<<" "<<(m.debug_io_wr?'W':'R')<<" "<<m.debug_addr<<" "<<unsigned(m.debug_io_wr?m.debug_data:m.debug_in)<<" pc="<<m.debug_pc<<"\n";if(m.debug_io_rd)last_read=read_key;}
  if(m.printer_write)printed.push_back(m.printer_data);
  if(m.debug_mem_wr)++memwrites;
  if(m.debug_fetch&&m.debug_cpu_p){++fetches;pcs[m.debug_pc]++;}
  m.clk=1;m.eval();++cycles;
 }
 void run(uint64_t n){while(n--)tick();}
 void key(unsigned scan,bool down){m.ps2_key=((m.ps2_key^1024)&1024)|(down?512:0)|scan;run(MACHINE_CLOCK*(NATIVE_ASCII==2?(down?0.01:0.08):0.06));}
 void type(std::string s){const std::map<char,int> keys={{'a',0x1c},{'b',0x32},{'c',0x21},{'d',0x23},{'e',0x24},{'f',0x2b},{'g',0x34},{'h',0x33},{'i',0x43},{'j',0x3b},{'k',0x42},{'l',0x4b},{'m',0x3a},{'n',0x31},{'o',0x44},{'p',0x4d},{'q',0x15},{'r',0x2d},{'s',0x1b},{'t',0x2c},{'u',0x3c},{'v',0x2a},{'w',0x1d},{'x',0x22},{'y',0x35},{'z',0x1a},{'0',0x45},{'1',0x16},{'2',0x1e},{'3',0x26},{'4',0x25},{'5',0x2e},{'6',0x36},{'7',0x3d},{'8',0x3e},{'9',0x46},{' ',0x29},{'.',0x49},{',',0x41},{13,0x5a},{10,0x5a},{'=',0x55},{'-',0x4e},{char(34),0x52},{char(39),0x52},{'+',0x55},{'*',0x3e},{'/',0x4a},{'?',0x4a},{';',0x4c},{':',0x4c},{'<',0x41},{'>',0x49}};
  for(char c:s){bool capital=c>='A'&&c<='Z';bool shift=(!NATIVE_ASCII&&capital)||c==34||c=='+'||c=='*'||c=='?'||c==':'||c=='<'||c=='>';char lower=capital?c+32:c;auto k=keys.find(lower);if(k==keys.end())throw std::runtime_error("Unsupported keyboard script");if(shift)key(0x12,1);key(k->second,1);key(k->second,0);run(MACHINE_CLOCK*0.08);if(shift)key(0x12,0);}}
 void save(){trace.flush();
  {std::ofstream f(prefix+"-printer.bin",std::ios::binary);f.write((char*)printed.data(),printed.size());}
  for(unsigned n=0;n<4;++n)if(!disks[n].empty()){std::ofstream image(prefix+"-disk"+std::to_string(n)+".dsk",std::ios::binary);image.write((char*)disks[n].data(),disks[n].size());}
  std::ofstream ppm(prefix+".ppm",std::ios::binary);ppm<<"P6\n"<<FrameWidth<<" 312\n255\n";for(auto p:pixels){unsigned c=(p&8)?255:192;ppm.put((p&2)?c:0);ppm.put((p&4)?c:0);ppm.put((p&1)?c:0);}
  std::ofstream ram(prefix+"-ram.bin",std::ios::binary),vram(prefix+"-vram.bin",std::ios::binary);for(unsigned a=0;a<65536;++a){m.peek_address=a;m.clk=0;m.eval();ram.put(HAS_SDRAM?ext[a]:m.peek_ram);vram.put(m.peek_vram);}
  {std::ofstream regs(prefix+"-registers.bin",std::ios::binary);for(unsigned r=0;r<7;++r){uint32_t value=m.debug_regs[r];regs.write((char*)&value,4);}}
  std::ofstream out(prefix+"-state.json");out<<"{\"control\":"<<m.debug_control<<",\"cycles\":"<<cycles<<",\"pc\":"<<m.debug_pc<<",\"io\":"<<io<<",\"writes\":"<<memwrites<<",\"fetches\":"<<fetches<<",\"sd_reads\":"<<reads<<",\"sd_writes\":"<<writes<<",\"boot_ready\":"<<unsigned(m.boot_ready)<<",\"hot_pcs\":{";
  bool comma=false;for(auto [pc,n]:pcs)if(n>1000){if(comma)out<<",";out<<"\""<<pc<<"\":"<<n;comma=true;}out<<"}}\n";
  std::cerr<<"PC="<<std::hex<<m.debug_pc<<std::dec<<" cycles="<<cycles<<" IO="<<io<<" SD="<<reads<<"/"<<writes<<"\n";
 }
};
int main(int argc,char**argv){try{
 Verilated::commandArgs(argc,argv);Sim s;std::string rom="assets/roms/boot.rom",typing,script;double seconds=2,after=1;unsigned status=0;
 for(int i=1;i<argc;++i){std::string a=argv[i];if(a=="--joy")s.m.joy0=std::stoul(argv[++i],nullptr,0);else if(a=="--loopback")s.loopback=true;else if(a=="--rom")rom=argv[++i];else if(a=="--script")script=argv[++i];else if(a=="--type-file"){std::ifstream t(argv[++i],std::ios::binary);typing.assign(std::istreambuf_iterator<char>(t),{});}else if(a=="--seconds")seconds=std::stod(argv[++i]);else if(a=="--after")after=std::stod(argv[++i]);else if(a=="--type")typing=argv[++i];else if(a=="--output")s.prefix=argv[++i];else if(a=="--status")status=std::stoul(argv[++i],nullptr,0);else if(a=="--disk"){unsigned n=std::stoul(argv[++i]);std::ifstream d(argv[++i],std::ios::binary);s.disks.at(n).assign(std::istreambuf_iterator<char>(d),{});}else throw std::runtime_error("Unknown argument "+a);}
 s.trace.open(s.prefix+"-io.txt");s.m.reset=1;s.m.video_reset=1;s.m.serial_rx=31;s.m.serial_ready=31;s.m.serial_cts=31;s.m.gpio_in=0xffffff;s.m.printer_ack_n=1;s.m.network_rx=1;s.m.ear=1;s.m.status[0]=status;s.run(128);s.m.video_reset=0;
 std::ifstream f(rom,std::ios::binary);std::vector<unsigned char> firmware((std::istreambuf_iterator<char>(f)),{});if(firmware.size()!=ROM_BYTES)throw std::runtime_error("Firmware size mismatch");
 for(unsigned a=0;a<firmware.size();++a){s.m.rom_wr=1;s.m.rom_address=a;s.m.rom_byte=firmware[a];while(s.m.rom_wait)s.tick();s.tick();}s.m.rom_wr=0;s.m.video_reset=0;
 for(unsigned n=0;n<4;++n)if(!s.disks[n].empty()){s.m.img_mounted=1<<n;s.m.img_size=s.disks[n].size();s.run(1000);s.m.img_mounted=0;}
 s.run(100000);s.m.reset=0;s.run(uint64_t(seconds*MACHINE_CLOCK));
 if(!script.empty()){
  std::ifstream in(script);if(!in)throw std::runtime_error("Cannot open script "+script);std::string line;while(std::getline(in,line)){if(!line.empty()&&line.back()==13)line.pop_back();if(line.empty()||line[0]=='#')continue;auto n=line.find(' ');std::string cmd=line.substr(0,n),arg=n==std::string::npos?"":line.substr(n+1);
   if(cmd=="wait")s.run(std::stod(arg)*MACHINE_CLOCK);
   else if(cmd=="type")s.type(arg);
   else if(cmd=="enter"){s.key(0x5a,1);s.key(0x5a,0);}
   else if(cmd=="key")s.key(std::stoul(arg,nullptr,16),1);
   else if(cmd=="release")s.key(std::stoul(arg,nullptr,16),0);
   else if(cmd=="save"){auto old=s.prefix;s.prefix+="-"+arg;s.save();s.prefix=old;}
   else if(cmd=="record")s.record(arg);
   else if(cmd=="stop-record")s.stop_record();
   else if(cmd=="play")s.open_tape(arg);
   else if(cmd=="nmi"){s.m.nmi=1;s.run(128);s.m.nmi=0;}
   else if(cmd=="network"){s.m.network_rx=std::stoul(arg,nullptr,0);s.run(128);}
   else if(cmd=="reset"){s.m.reset=1;s.run(1000);s.m.reset=0;}
   else if(cmd=="status")s.m.status[0]=std::stoul(arg,nullptr,0);
   else throw std::runtime_error("Unknown script command "+cmd);
  }
 }
 if(!typing.empty()){s.type(typing);s.run(uint64_t(after*MACHINE_CLOCK));}s.stop_record();s.save();return 0;
 }catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}}
