// SPDX-License-Identifier: GPL-3.0-or-later
#include "Vrp_fdc_sim.h"
#include "verilated.h"
#include <vector>
#include <array>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <algorithm>
struct Test {
 Vrp_fdc_sim m;std::array<std::vector<unsigned char>,4> disk;int state=0,byte=0,sub=0,drive=0,hold=0;bool writing=false;unsigned lba=0,reads=0,writes=0;
 void tick(){
  m.sd_buff_wr=0;
  if(!state && (m.sd_rd||m.sd_wr)){writing=m.sd_wr;drive=0;while(!((m.sd_rd|m.sd_wr)&(1<<drive)))++drive;lba=m.sd_lba;byte=0;sub=0;state=1;m.sd_ack=1;if(writing)++writes;else ++reads;}
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
 std::vector<unsigned> format(int drive,int head,int n,int count,int fill,bool ids=true,bool mfm=true){write(mfm?0x4d:0x0d);write(drive|(head<<2));write(n);write(count);write(0x2a);write(fill);
  if(ids)for(int i=1;i<=count;++i){write(0);write(head);write(i);write(n);}return result();}
 void check(bool ok,const char*why){if(!ok)throw std::runtime_error(why);}
 void sector(bool writing,int drive,int head,int n,int sector,std::vector<unsigned char>& bytes,bool mfm=true){write((writing?0x05:0x06)|(mfm?0x40:0));write(drive|(head<<2));write(0);write(head);write(sector);write(n);write(sector);write(0x2a);write(n==0?128:255);
  for(auto &b:bytes){if(writing)write(b);else b=get();}m.tc=1;run(8);m.tc=0;auto st=result();check(st[0]==unsigned(head<<2|drive) && st[1]==0 && st[2]==0,"FDC sector transfer status");}
};
int main(int argc,char**argv){try{Verilated::commandArgs(argc,argv);Test t;t.disk[0].resize(256+160*4864,0xe5);auto &image=t.disk[0];
 std::fill(image.begin(),image.begin()+256,0);std::string signature="MV - CPCEMU Disk-File\r\nDisk-Info\r\n";std::copy(signature.begin(),signature.end(),image.begin());image[0x30]=80;image[0x31]=2;image[0x32]=0;image[0x33]=19;
 for(int track=0;track<160;++track){size_t at=256+track*4864;std::fill(image.begin()+at,image.begin()+at+256,0);std::string sig="Track-Info\r\n";std::copy(sig.begin(),sig.end(),image.begin()+at);image[at+0x10]=track/2;image[at+0x11]=track%2;image[at+0x13]=2;image[at+0x14]=2;image[at+0x15]=9;image[at+0x16]=0x2a;image[at+0x17]=0xe5;for(int sec=0;sec<9;++sec){image[at+0x18+sec*8]=track/2;image[at+0x19+sec*8]=track%2;image[at+0x1a+sec*8]=sec+1;image[at+0x1b+sec*8]=2;}}
 t.disk[1]=t.disk[0];t.disk[2]=t.disk[0];t.disk[3]=t.disk[0];auto original=t.disk;
 t.m.nRD=1;t.m.nWR=1;t.m.reset=1;t.run(20);t.m.reset=0;t.run(100);t.mount(0,false);t.mount(1,false);t.mount(2,false);t.mount(3,false);t.write(3);t.write(0xdf);t.write(2);
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
 for(int drive=2;drive<4;++drive){
  auto saved=t.disk;st=t.format(drive,drive&1,2,9,0x61+drive);t.check(st[0]==unsigned(drive|((drive&1)<<2))&&st[1]==0,"Four-drive FORMAT failed");
  sector.resize(512);t.sector(false,drive,drive&1,2,1,sector);t.check(std::all_of(sector.begin(),sector.end(),[&](unsigned char v){return v==0x61+drive;}),"Four-drive readback");
  for(int other=0;other<4;++other)if(other!=drive)t.check(t.disk[other]==saved[other],"Four-drive isolation");
 }
 auto execute=[&](unsigned op,int drive,int head,std::vector<unsigned char>& data,int eot=1,bool terminal=true){
  t.write(op);t.write(drive|(head<<2));t.write(0);t.write(head);t.write(1);t.write(2);t.write(eot);t.write(0x2a);t.write(1);
  bool to_disk=(op&31)==5||(op&31)==9||(op&31)==17||(op&31)==25||(op&31)==29;
  for(auto &v:data)if(to_disk)t.write(v);else v=t.get();
  if(terminal){t.m.tc=1;t.run(8);t.m.tc=0;}return t.result();
 };
 std::vector<unsigned char> scan(512,0x5a);
 st=execute(0x51,0,0,scan,1,false);t.check(st[0]==0&&st[1]==0&&st[2]==8,"SCAN equal");
 std::fill(scan.begin(),scan.end(),0x70);st=execute(0x59,0,0,scan,1,false);t.check(st[0]==0&&st[2]==0,"SCAN low or equal");
 std::fill(scan.begin(),scan.end(),0x30);st=execute(0x5d,0,0,scan,1,false);t.check(st[0]==0&&st[2]==0,"SCAN high or equal");
 st=execute(0x51,0,0,scan,1,false);t.check(st[2]==4,"SCAN mismatch result");
 std::fill(scan.begin(),scan.end(),0xab);st=execute(0x49,3,1,scan);t.check(st[0]==7&&st[1]==0&&st[2]==0,"WRITE deleted data");
 t.check((t.disk[3][256+4864+0x1d]&0x40)!=0,"Deleted mark not persisted in DSK");
 std::fill(scan.begin(),scan.end(),0);st=execute(0x4c,3,1,scan);t.check(st[0]==7&&st[2]==0&&scan[0]==0xab,"READ deleted data");
 st=execute(0x46,3,1,scan);t.check(st[2]==0x40,"Normal READ must report control mark");
 t.format(2,0,2,9,0x63);t.format(2,1,2,9,0xa6);
 scan.resize(1024);st=execute(0xc6,2,0,scan,1,false);
 t.check(std::all_of(scan.begin(),scan.begin()+512,[](unsigned char v){return v==0x63;})&&std::all_of(scan.begin()+512,scan.end(),[](unsigned char v){return v==0xa6;}),"Multi-track head ordering");
 for(int drive=0;drive<4;++drive){t.write(0x0f);t.write(drive);t.write(1+drive*2);}
 t.run(1000);
 for(int drive=0;drive<4;++drive){t.write(8);auto st0=t.get(),pcn=t.get();t.check(st0==unsigned(0x20|drive)&&pcn==unsigned(1+drive*2),"Four-drive SEEK/SENSE INTERRUPT");}
 t.write(0x0f);t.write(3);t.write(0);t.run(1000);t.write(8);t.get();t.get();t.m.drive_8inch=8;t.mount(3,false);st=t.format(3,0,0,26,0x71,true,false);t.check(st[0]==3&&st[1]==0,"8-inch FM 26-sector FORMAT");
 sector.resize(128);t.sector(false,3,0,0,26,sector,false);t.check(sector[0]==0x71&&sector[127]==0x71,"8-inch FM sector read");
 t.write(0x4a);t.write(3);st=t.result();t.check(st[1]==1,"Wrong recording density must fail");
 t.check(t.disk[3][256+0x13]==1,"FM recording metadata persistence");
 t.write(0x06);t.write(3);t.write(0);t.write(0);t.write(26);t.write(0);t.write(26);t.write(0x2a);t.write(128);
 for(int byte=0;byte<127;++byte)t.check(t.get()==0x71,"FM terminal count prefix");
 while((t.read(false)&0xc0)!=0xc0){}t.m.tc=1;t.run(8);t.m.tc=0;
 t.check(t.get()==0x71,"TC must complete the pending final byte");st=t.result();t.check(st[0]==3&&st[1]==0,"TC pending-byte status");
 std::ofstream proof(argc>1?argv[1]:"build/fdc-validation.json");proof<<"{\"status\":\"passed\",\"sd_reads\":"<<t.reads<<",\"sd_writes\":"<<t.writes<<",\"checks\":[\"persistent FORMAT\",\"512 and 256 byte sectors\",\"all four drives and both heads\",\"native sector read/write\",\"write protection\",\"allocation bounds\",\"SCAN comparisons\",\"persistent deleted marks\",\"multi-track head order\",\"adjacent tracks preserved\"]}\n";
 std::cout<<"PASS: four-drive FORMAT and isolation, SCAN comparisons, persistent deleted marks, multi-track order, write protection and allocation bounds\n";return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}}
