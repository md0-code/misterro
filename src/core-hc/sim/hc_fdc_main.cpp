// SPDX-License-Identifier: GPL-3.0-or-later
#include "Vhc_fdc_sim.h"
#include "verilated.h"
#include <vector>
#include <array>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <algorithm>
struct Test {
 Vhc_fdc_sim m;std::array<std::vector<unsigned char>,2> disk;int state=0,byte=0,sub=0,drive=0,hold=0;bool writing=false;unsigned lba=0,reads=0,writes=0;
 void tick(){
  m.sd_buff_wr=0;
  if(!state && (m.sd_rd||m.sd_wr)){writing=m.sd_wr;drive=((m.sd_rd|m.sd_wr)&1)?0:1;lba=m.sd_lba;byte=0;sub=0;state=1;m.sd_ack=1;if(writing)++writes;else ++reads;}
  if(state==1){m.sd_buff_addr=byte;size_t pos=size_t(lba)*512+byte;if(pos>=disk[drive].size())throw std::runtime_error("FDC exceeds disk allocation");if(!writing){m.sd_buff_wr=1;m.sd_buff_dout=disk[drive][pos];}
   if(++sub==3){sub=0;if(writing)disk[drive][pos]=m.sd_buff_din;if(++byte==512){state=2;hold=16;}}}
  else if(state==2){if(!--hold){m.sd_ack=0;state=3;}}else if(state==3 && !(m.sd_rd|m.sd_wr))state=0;
  m.clk=0;m.eval();m.clk=1;m.eval();
 }
 void run(unsigned n){while(n--)tick();}
 unsigned read(bool data){m.a0=data;m.nWR=1;m.nRD=0;run(4);unsigned v=m.dout;m.nRD=1;run(4);return v;}
 void write(unsigned v){for(unsigned i=0;i<1000000;++i){if((read(false)&0xc0)==0x80){m.a0=1;m.din=v;m.nWR=0;run(4);m.nWR=1;run(4);return;}}throw std::runtime_error("FDC output handshake timed out");}
 unsigned get(){for(unsigned i=0;i<1000000;++i)if((read(false)&0xc0)==0xc0)return read(true);throw std::runtime_error("FDC input handshake timed out");}
 std::vector<unsigned> result(){std::vector<unsigned> out;for(int i=0;i<7;++i)out.push_back(get());return out;}
 void mount(int drive,bool wp){m.img_size=disk[drive].size();m.img_wp=wp;m.img_mounted=1<<drive;run(8);m.img_mounted=0;run(30000);}
 std::vector<unsigned> format(int drive,int head,int n,int count,int fill,bool ids=true){write(0x4d);write(drive|(head<<2));write(n);write(count);write(0x2a);write(fill);
  if(ids)for(int i=1;i<=count;++i){write(0);write(head);write(i);write(n);}return result();}
 void check(bool ok,const char*why){if(!ok)throw std::runtime_error(why);}
 void sector(bool writing,int drive,int head,int n,int sector,std::vector<unsigned char>& bytes){write(writing?0x45:0x46);write(drive|(head<<2));write(0);write(head);write(sector);write(n);write(sector);write(0x2a);write(255);
  for(auto &b:bytes){if(writing)write(b);else b=get();}m.tc=1;run(8);m.tc=0;auto st=result();check(st[0]==unsigned(head<<2|drive) && st[1]==0 && st[2]==0,"FDC sector transfer status");}
};
int main(int argc,char**argv){try{Verilated::commandArgs(argc,argv);Test t;std::ifstream f("assets/disks/hc2000/system.dsk",std::ios::binary);t.disk[0].assign(std::istreambuf_iterator<char>(f),{});t.disk[1]=t.disk[0];auto original=t.disk;
 t.m.nRD=1;t.m.nWR=1;t.m.reset=1;t.run(20);t.m.reset=0;t.run(100);t.mount(0,false);t.mount(1,false);t.write(3);t.write(0xdf);t.write(2);
 auto st=t.format(0,0,2,9,0xa5);t.check(st[0]==0 && st[1]==0 && st[2]==0,"FORMAT drive A failed");
 t.check(std::all_of(t.disk[0].begin()+512,t.disk[0].begin()+512+4608,[](unsigned char v){return v==0xa5;}),"FORMAT did not persist sector fill");
 t.check(std::equal(t.disk[0].begin(),t.disk[0].begin()+256,original[0].begin()),"FORMAT changed disk header");t.check(t.disk[1]==original[1],"FORMAT corrupted drive B");
 std::vector<unsigned char> sector(512);t.sector(false,0,0,2,1,sector);t.check(std::all_of(sector.begin(),sector.end(),[](unsigned char v){return v==0xa5;}),"Formatted sector readback failed");
 std::fill(sector.begin(),sector.end(),0x5a);t.sector(true,0,0,2,1,sector);std::fill(sector.begin(),sector.end(),0);t.sector(false,0,0,2,1,sector);t.check(std::all_of(sector.begin(),sector.end(),[](unsigned char v){return v==0x5a;}),"Sector write/read failed");
 auto driveA=t.disk[0];st=t.format(1,1,1,10,0x3c);t.check(st[0]==5 && st[1]==0 && st[2]==0,"FORMAT drive B/head 1 failed");
 size_t track=256+4864;t.check(t.disk[1][track+0x14]==1 && t.disk[1][track+0x15]==10,"FORMAT geometry was not written");
 t.check(std::all_of(t.disk[1].begin()+track+256,t.disk[1].begin()+track+256+2560,[](unsigned char v){return v==0x3c;}),"FORMAT head 1 did not persist");
 t.check(t.disk[0]==driveA,"Drive B changed drive A");t.check(std::equal(t.disk[1].begin(),t.disk[1].begin()+track,original[1].begin()),"FORMAT changed adjacent track");
 sector.resize(256);t.sector(false,1,1,1,10,sector);t.check(std::all_of(sector.begin(),sector.end(),[](unsigned char v){return v==0x3c;}),"Drive B sector-10 read failed");
 auto before=t.disk;t.mount(1,true);st=t.format(1,1,1,10,0, false);t.check(st[1]==2 && t.disk==before,"Write protection failed");
 st=t.format(0,0,3,29,0,false);t.check(st[1]!=0 && t.disk==before,"Oversize format changed adjacent tracks");
 std::ofstream proof("build/fdc-validation.json");proof<<"{\"status\":\"passed\",\"sd_reads\":"<<t.reads<<",\"sd_writes\":"<<t.writes<<",\"checks\":[\"persistent FORMAT\",\"512 and 256 byte sectors\",\"both heads and drives\",\"native sector read/write\",\"write protection\",\"allocation bounds\",\"adjacent tracks preserved\"]}\n";
 std::cout<<"PASS: persistent FORMAT, both drives/heads, sector read/write, write protection and allocation bounds\n";return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}}
