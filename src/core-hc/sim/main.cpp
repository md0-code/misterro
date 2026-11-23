// SPDX-License-Identifier: GPL-3.0-or-later
#include "Vhc85_sim.h"
#include "verilated.h"
#include <array>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

struct Simulator {
    Vhc85_sim m;
    uint64_t cycles=0, cpu_edges=0, stalls=0, mem_writes=0, frames=0, tape_edges=0;
    std::array<uint8_t,65536> memory{};
    std::array<uint8_t,448*312*3> pixels{};
    bool old_vs=true, old_tape=false, old_mem=false;
    uint16_t old_address=0;
    std::array<uint8_t,16384> rom{};
    std::string prefix;
    int model;
    Simulator(int selected) : model(selected) {
#ifdef HC_FAMILY
        m.requested_model=model==90?1:model==91?2:0;
        m.rom_download=0;m.rom_write=0;m.rom_address=0;m.rom_byte=0;
#endif
        prefix = model == 85 ? "" : "hc"+std::to_string(model)+"-";
        std::ifstream firmware("assets/roms/hc"+std::to_string(model)+".rom",std::ios::binary);
        firmware.read(reinterpret_cast<char*>(rom.data()),rom.size());
        if(firmware.gcount()!=16384) throw std::runtime_error("Missing 16 KiB HC ROM");
    }
    std::string screenText() const {
        std::string result;
        for(int row=0;row<24;++row) {
            for(int col=0;col<32;++col) {
                char found='?';
                for(int ch=32;ch<127;++ch) {
                    bool same=true;
                    for(int line=0;line<8;++line) {
                        int y=row*8+line;
                        int address=0x4000+((y&0xc0)<<5)+((y&7)<<8)+((y&0x38)<<2)+col;
                        if(memory[address]!=rom[0x3d00+(ch-32)*8+line]) {same=false;break;}
                    }
                    if(same) {found=char(ch);break;}
                }
                result+=found;
            }
            result+='\n';
        }
        return result;
    }
    void tick() {
        m.clk=0; m.eval();
        bool pixel=m.ce_pixel;
        cpu_edges+=m.debug_cpu_p; stalls+=m.debug_stall;
        m.clk=1; m.eval(); ++cycles;
        if(m.debug_mem_wr) {
            memory[m.debug_addr]=m.debug_data;
            if(!old_mem || old_address!=m.debug_addr) ++mem_writes;
        }
        old_address=m.debug_addr; old_mem=m.debug_mem_wr;
        if(old_vs && !m.vs) ++frames;
        old_vs=m.vs;
        if(old_tape!=bool(m.tape_active)) ++tape_edges;
        old_tape=m.tape_active;
        if(pixel && m.video_x<448 && m.video_y<312) {
            size_t n=(m.video_y*448+m.video_x)*3;
            int level = model == 85 || m.bright ? 255 : 192;
            pixels[n]=(m.rgb&2)?level:0;
            pixels[n+1]=(m.rgb&4)?level:0;
            pixels[n+2]=(m.rgb&1)?level:0;
        }
    }
#ifdef HC_FAMILY
    void uploadFamily() {
        std::ifstream input("assets/roms/family.rom",std::ios::binary);
        std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(input)),{});
        if(bytes.size()!=65536)throw std::runtime_error("Missing HC family firmware");
        m.rom_download=1;for(int n=0;n<4;++n)tick();
        for(size_t n=0;n<bytes.size();++n){m.rom_write=1;m.rom_address=n;m.rom_byte=bytes[n];tick();}
        m.rom_write=0;m.rom_download=0;for(int n=0;n<8;++n)tick();
    }
    void selectModel(int next) {
        model=next;m.requested_model=next==90?1:next==91?2:0;
        std::ifstream input("assets/roms/hc"+std::to_string(next)+".rom",std::ios::binary);
        input.read(reinterpret_cast<char*>(rom.data()),rom.size());
        if(input.gcount()!=16384)throw std::runtime_error("Missing switched model ROM");
        for(int n=0;n<512;++n)tick();
    }
#endif
    void run(double seconds) {
        uint64_t count=uint64_t(seconds*56000000.0);
        for(uint64_t i=0;i<count;++i) tick();
    }
    void key(uint8_t code, bool down, bool extended=false) {
        m.ps2_key=((m.ps2_key^0x400)&0x400)|(down?0x200:0)|(extended?0x100:0)|code;
        tick();
    }
    void press(uint8_t code, bool symbol=false) {
        if(symbol) key(0x14,true);
        key(code,true); run(.080); key(code,false);
        if(symbol) key(0x14,false);
        run(.100);
    }
    void save(const std::string &name) {
        std::ofstream mem("build/"+prefix+name+".bin",std::ios::binary);
        mem.write(reinterpret_cast<const char*>(memory.data()),memory.size());
        std::ofstream pic("build/"+prefix+name+".ppm",std::ios::binary);
        pic<<"P6\n448 312\n255\n";
        pic.write(reinterpret_cast<const char*>(pixels.data()),pixels.size());
    }
};
int main(int argc,char **argv) {
    Verilated::commandArgs(argc,argv);
    double seconds=3; bool test=false; std::string tape; int model=85;
    for(int i=1;i<argc;++i) {
        std::string arg=argv[i];
        if(arg=="--seconds" && i+1<argc) seconds=std::stod(argv[++i]);
        else if(arg=="--test") test=true;
        else if(arg=="--model" && i+1<argc) model=std::stoi(argv[++i]);
        else if(arg=="--tape" && i+1<argc) tape=argv[++i];
    }
    auto start=std::chrono::steady_clock::now();
    Simulator s(model);
    s.m.reset=1; for(int i=0;i<128;++i) s.tick(); s.m.reset=0;
#ifdef HC_FAMILY
    s.uploadFamily();
#endif
    if(test || !tape.empty()) {
        bool ready=false;
        for(int attempt=0;attempt<60;++attempt) {
            s.run(.1);
            auto text=s.screenText();
            if(text.find("HC")!=std::string::npos && text.find("FELI")!=std::string::npos) { ready=true; break; }
        }
        if(!ready) { s.save("boot"); throw std::runtime_error("Original ROM did not reach its boot banner in six seconds"); }
        s.run(.1);
    } else s.run(seconds);
    s.save("boot");
    std::cout<<"Boot: PC="<<std::hex<<unsigned(s.m.debug_pc)<<std::dec<<" frames="<<s.frames<<std::endl;
    if(test) {
        // Enter PRINT 2+2 using real keyboard scanning and the original ROM.
        s.press(0x4d); s.press(0x1e); s.press(0x42,true); s.press(0x1e); s.press(0x5a);
        s.run(.3); s.save("basic");
        std::cout<<"BASIC command entered, PC="<<std::hex<<unsigned(s.m.debug_pc)<<std::dec<<std::endl;
        s.press(0x78); // F11, through the real keyboard reset path.
        bool restarted=false;
        for(int attempt=0;attempt<60;++attempt) {
            s.run(.1);
            if(s.screenText().find("FELI")!=std::string::npos) {restarted=true;break;}
        }
        if(!restarted) throw std::runtime_error("F11 did not restart the original ROM");
        s.run(.1); s.save("reset");
        s.press(0x4d); s.press(0x26); s.press(0x42,true); s.press(0x26); s.press(0x5a);
        s.run(.3); s.save("reset-basic");
#ifdef HC_FAMILY
        s.selectModel(model==85?90:model==90?91:85);
        bool switched=false;
        for(int attempt=0;attempt<60;++attempt){
            s.run(.1);
            if(s.screenText().find("FELI")!=std::string::npos && s.screenText().find(std::to_string(s.model))!=std::string::npos){switched=true;break;}
        }
        if(!switched)throw std::runtime_error("OSD model switch did not boot the selected ROM");
        s.run(.1);s.save("switch");
        s.press(0x4d);s.press(0x1e);s.press(0x42,true);s.press(0x1e);s.press(0x5a);
        s.run(.3);s.save("switch-basic");
#endif
    }
    if(!tape.empty()) {
        s.press(0x3b); s.press(0x4d,true); s.press(0x4d,true); s.press(0x5a); // LOAD ""
        s.run(.1);
        std::cout<<"LOAD request: PC="<<std::hex<<unsigned(s.m.debug_pc)<<std::dec<<std::endl;
        if(s.m.debug_pc>=0x0800) {
            s.save("tape");
            std::cerr<<s.screenText();
            throw std::runtime_error("Keyboard LOAD command did not enter the ROM cassette reader");
        }
        std::ifstream input(tape,std::ios::binary);
        if(!input) throw std::runtime_error("Cannot open tape: "+tape);
        std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(input)),{});
        bool tzx=bytes.size()>=10 && std::string(bytes.begin(),bytes.begin()+7)=="ZXTape!";
        s.m.tape_mode=tzx?2:0; s.m.tape_download=1; s.tick();
        for(size_t i=0;i<bytes.size();++i) {
            s.m.tape_wr=1; s.m.tape_addr=i; s.m.tape_data=bytes[i]; s.tick();
        }
        s.m.tape_wr=0; s.m.tape_download=0; s.tick();
        if(s.m.tape_overflow) throw std::runtime_error("Tape exceeds buffer capacity");
        for(int sec=0;sec<int(seconds);++sec) {
            s.run(1); s.save("tape");
            std::cout<<"Tape "<<sec+1<<"s: PC="<<std::hex<<unsigned(s.m.debug_pc)<<std::dec
                     <<" active="<<unsigned(s.m.tape_active)<<std::endl;
        }
    }
    double elapsed=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
    std::ofstream report("build/"+s.prefix+"simulation.json");
    report<<"{\"cycles\":"<<s.cycles<<",\"cpu_edges\":"<<s.cpu_edges<<",\"stalled_clocks\":"<<s.stalls
          <<",\"memory_writes\":"<<s.mem_writes<<",\"frames\":"<<s.frames
          <<",\"pc\":"<<unsigned(s.m.debug_pc)<<",\"wall_seconds\":"<<elapsed<<"}\n";
    std::cout<<"Simulated "<<s.cycles<<" clocks in "<<elapsed<<" seconds"<<std::endl;
    s.m.final();
    if(s.mem_writes<1000 || s.frames<2 || !s.cpu_edges) return 1;
}
