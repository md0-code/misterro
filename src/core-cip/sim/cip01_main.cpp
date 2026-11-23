// SPDX-License-Identifier: GPL-3.0-or-later
#include "Vcip01_sim.h"
#include "verilated.h"
#include <array>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>
#ifdef REFERENCE_CLOCK
#define SIM_HZ 56000000
#define CAPTURE_PREFIX "reference-"
#endif
#ifndef SIM_HZ
#define SIM_HZ 7000000
#endif
#ifndef CAPTURE_PREFIX
#define CAPTURE_PREFIX ""
#endif
struct Simulator {
    Vcip01_sim m;
    uint64_t cycles=0,frames=0,low_writes=0;
    std::array<uint8_t,65536> memory{};
    std::array<uint8_t,448*312*3> pixels{};
    bool old_vs=true;
    std::string prefix=CAPTURE_PREFIX;
    void tick() {
        m.clk=0;m.eval();bool pixel=m.ce_pixel;
        if(m.debug_mem_wr && !m.reset) {memory[m.debug_addr]=m.debug_data;if(m.debug_addr<0x4000)++low_writes;}
        m.clk=1;m.eval();++cycles;
        if(old_vs&&!m.vs)++frames;old_vs=m.vs;
        if(pixel&&m.video_x<448&&m.video_y<312) {
            auto n=(m.video_y*448+m.video_x)*3;int level=(m.rgb&8)?255:205;
            pixels[n]=(m.rgb&2)?level:0;pixels[n+1]=(m.rgb&4)?level:0;pixels[n+2]=(m.rgb&1)?level:0;
        }
    }
#ifdef CIP_FAMILY
    void uploadFamily() {
        std::ifstream input("assets/roms/family.rom",std::ios::binary);
        std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(input)),{});
        if(bytes.size()!=83968)throw std::runtime_error("Missing CIP family firmware");
        m.rom_download=1;for(int n=0;n<4;++n)tick();
        for(size_t n=0;n<bytes.size();++n){m.rom_write=1;m.rom_address=n;m.rom_byte=bytes[n];tick();}
        m.rom_write=0;m.rom_download=0;for(int n=0;n<8;++n)tick();
    }
#endif
    void run(double seconds) {for(uint64_t n=uint64_t(seconds*SIM_HZ);n;--n)tick();}
    void key(uint8_t code,bool down) {m.ps2_key=((m.ps2_key^0x400)&0x400)|(down?0x200:0)|code;tick();}
    void press(uint8_t code,bool symbol=false) {
        if(symbol)key(0x14,true);key(code,true);run(.08);key(code,false);if(symbol)key(0x14,false);run(.1);
    }
    void save(const std::string& name) {
        std::ofstream mem("build/"+prefix+name+".bin",std::ios::binary);mem.write((char*)memory.data(),memory.size());
        std::ofstream pic("build/"+prefix+name+".ppm",std::ios::binary);pic<<"P6\n448 312\n255\n";pic.write((char*)pixels.data(),pixels.size());
    }
    std::string text() {
        std::string out;
        for(int row=0;row<24;++row) {for(int col=0;col<32;++col) {
            char ch='?';for(int c=32;c<127;++c) {bool match=true;for(int line=0;line<8;++line) {
                int y=row*8+line,addr=0x4000+((y&0xc0)<<5)+((y&7)<<8)+((y&0x38)<<2)+col;
                if(memory[addr]!=memory[0x3d00+(c-32)*8+line]) {match=false;break;}
            }if(match){ch=c;break;}}out+=ch;
        }out+='\n';}return out;
    }
};
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);double seconds=1;bool test=false,resident=false,monitor=false;std::string tape,prefix=CAPTURE_PREFIX;int tape_seconds=115;
    for(int i=1;i<argc;++i) {std::string a=argv[i];if(a=="--seconds"&&i+1<argc)seconds=std::stod(argv[++i]);else if(a=="--test")test=true;else if(a=="--tape"&&i+1<argc)tape=argv[++i];else if(a=="--tape-seconds"&&i+1<argc)tape_seconds=std::stoi(argv[++i]);else if(a=="--resident")resident=true;else if(a=="--monitor")monitor=true;else if(a=="--prefix"&&i+1<argc)prefix=argv[++i];}
    Simulator s;
    s.prefix=prefix;s.m.monitor_rom=monitor;
#ifdef CIP_FAMILY
    s.m.requested_model=resident?1:0;
    for(int i=1;i<argc;++i)if(std::string(argv[i])=="--family-model" && i+1<argc)s.m.requested_model=std::stoi(argv[++i]);
    s.m.rom_download=0;s.m.rom_write=0;s.m.rom_address=0;s.m.rom_byte=0;
#endif
    if(resident&&!monitor) {
        // Screen observer only. CPU firmware comes from the RTL's ROM array.
        std::ifstream f("assets/roms/cip03.rom",std::ios::binary);f.read((char*)s.memory.data(),16384);
        if(f.gcount()!=16384)throw std::runtime_error("Missing resident ROM");
    }
    s.m.reset=1;s.m.cold_reset=1;for(int i=0;i<32;++i)s.tick();s.m.reset=0;s.m.cold_reset=0;
#ifdef CIP_FAMILY
    s.uploadFamily();
#endif
    s.run(seconds);
    if(resident&&!monitor) {
        for(int i=0;i<80&&s.text().find("Basic-S")==std::string::npos;++i)s.run(.1);
        if(s.text().find("Basic-S")==std::string::npos)throw std::runtime_error("Resident BASIC startup banner missing");
    }
    s.save("boot");
    std::cout<<"Monitor PC="<<std::hex<<s.m.debug_pc<<std::dec<<" frames="<<s.frames<<std::endl;
    if(resident&&test) {
        if(monitor) {
            if(!s.m.boot_rom || s.m.debug_pc>=0x800)throw std::runtime_error("Copier ROM startup failed");
            std::cout<<"PASS: copier firmware startup"<<std::endl;
#ifdef CIP_FAMILY
            s.m.monitor_rom=0;{std::ifstream font("assets/roms/cip03.rom",std::ios::binary);font.read((char*)s.memory.data(),16384);}for(int n=0;n<300;++n)s.tick();s.run(1.5);
            for(int n=0;n<80&&s.text().find("Basic-S")==std::string::npos;++n)s.run(.1);
            if(s.text().find("Basic-S")==std::string::npos)throw std::runtime_error("Copier/resident selector did not boot BASIC");
            s.press(0x5a);s.press(0x4d);s.press(0x1e);s.press(0x42,true);s.press(0x1e);s.press(0x5a);s.run(.4);s.save("switch-basic");
            if(s.text().find('4')==std::string::npos)throw std::runtime_error("BASIC arithmetic after copier switch failed");
#endif
            return 0;
        }
        s.press(0x5a); // CIP-03 manual AP.1: ENTER activates the K cursor.
        s.press(0x4d);s.press(0x1e);s.press(0x42,true);s.press(0x1e);s.press(0x5a);s.run(.4);s.save("basic");
        if(s.text().find("4                               \n")==std::string::npos)throw std::runtime_error("Resident PRINT 2+2 failed");
        s.press(0x78);s.run(.5);
        for(int i=0;i<80&&s.text().find("Basic-S")==std::string::npos;++i)s.run(.1);
        s.save("reset");s.press(0x5a);
        s.press(0x4d);s.press(0x26);s.press(0x42,true);s.press(0x26);s.press(0x5a);s.run(.4);s.save("reset-basic");
        if(!s.m.boot_rom || s.text().find("6                               \n")==std::string::npos)throw std::runtime_error("Resident reset/PRINT 3+3 failed");
        std::cout<<s.text()<<"PASS: resident BASIC startup, arithmetic, F11 restart and second arithmetic"<<std::endl;
#ifdef CIP_FAMILY
        s.m.requested_model=s.m.requested_model==1?2:1;
        s.m.monitor_rom=0;for(int n=0;n<300;++n)s.tick();
        s.run(1.5);
        for(int i=0;i<80&&s.text().find("Basic-S")==std::string::npos;++i)s.run(.1);
        if(s.text().find("Basic-S")==std::string::npos)throw std::runtime_error("Family selector did not restart resident firmware");
        s.save("switch");s.press(0x5a);s.press(0x4d);s.press(0x1e);s.press(0x42,true);s.press(0x1e);s.press(0x5a);s.run(.4);s.save("switch-basic");
        if(s.text().find("4                               \n")==std::string::npos)throw std::runtime_error("BASIC failed after CIP model switch");
        s.m.requested_model=0;for(int n=0;n<300;++n)s.tick();s.run(.6);s.save("switch-monitor");
        if(!s.m.boot_rom || s.m.debug_pc>=0x800)throw std::runtime_error("Model switch did not restore CIP01 monitor");
#endif
        return 0;
    }
    if(tape.empty())return 0;
    s.press(0x4b);s.press(0x5a);s.press(0x5a);s.run(.1);s.save("loader");
    std::cout<<"Loader PC="<<std::hex<<s.m.debug_pc<<std::dec<<" boot="<<int(s.m.boot_rom)<<std::endl;
    std::ifstream in(tape,std::ios::binary);if(!in)throw std::runtime_error("Missing tape");std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(in)),{});
    s.m.tape_download=1;s.m.tape_mode=2;for(int i=0;i<16;++i)s.tick();
    for(size_t i=0;i<bytes.size();++i) {s.m.tape_addr=i;s.m.tape_data=bytes[i];s.m.tape_wr=1;s.tick();s.m.tape_wr=0;s.tick();}
    s.m.tape_download=0;for(int i=0;i<16;++i)s.tick();bool launched=false;
    for(int sec=0;sec<tape_seconds;++sec) {
        s.run(1);
        if(sec%10==0){s.save("tape");std::cout<<"Tape "<<sec+1<<"s PC="<<std::hex<<s.m.debug_pc<<std::dec<<" boot="<<int(s.m.boot_rom)<<" low-writes="<<s.low_writes<<std::endl;}
        if(sec>90&&!s.m.boot_rom&&s.m.debug_pc<0x4000){launched=true;break;}
    }
    s.run(1);s.save("loaded");std::cout<<s.text()<<std::flush;
    if(tape_seconds<100)return 0;
    if(!launched)throw std::runtime_error("Tape BASIC did not launch");
    if(test) {
        s.press(0x4d);s.press(0x1e);s.press(0x42,true);s.press(0x1e);s.press(0x5a);s.run(.4);s.save("basic");std::cout<<s.text()<<std::flush;
        if(s.text().find('4')==std::string::npos)throw std::runtime_error("PRINT 2+2 failed");
        s.press(0x78);s.run(.5);s.save("cold-reset");if(!s.m.boot_rom)throw std::runtime_error("F11 did not restore monitor");

    }
    std::cout<<"PASS: cassette runtime launch, BASIC command, F11 reset recovery"<<std::endl;
}
