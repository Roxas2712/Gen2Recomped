// Contributions by Roxas2712. Synthetic GBA raster inputs; no game data.
#undef NDEBUG
#include "gba_ppu.h"
#include <array>
#include <cassert>
#include <cstdio>
#include <vector>
struct DispatchEntry {uint32_t addr;uint8_t thumb,resume;void (*fn)();};
extern "C" const DispatchEntry kDispatchTable[]={{0xffffffffu,0,0,nullptr}};
extern "C" const unsigned kDispatchTableLen=0;
static void word(uint8_t* p,unsigned v){p[0]=v;p[1]=v>>8;}
int main(){
 for(bool wide:{false,true}){
  gba::GbaPpu ppu;if(wide)ppu.set_view_margins(8,8,0,0);
  std::array<uint8_t,0x60> io{};
  std::array<uint8_t,96*1024> vram{};
  std::array<uint8_t,1024> oam{},palette{};
  for(unsigned i=0;i<128;i++)word(oam.data()+i*8,0x200);
  word(io.data()+14,0x0103); // BG3 priority 3, map at 0x800.
  word(palette.data()+2,0x03e0); // green BG
  word(palette.data()+514,0x001f);word(palette.data()+516,0x7c00); // red/blue OBJ
  for(unsigned i=0;i<32;i++){vram[32+i]=0x11;vram[0x10000+i]=0x11;vram[0x10020+i]=0x22;}
  for(unsigned i=0;i<1024;i++)word(vram.data()+0x800+i*2,1);
  auto object=[&](unsigned index,unsigned mode,unsigned priority,unsigned tile){
   auto* p=oam.data()+index*8;word(p,16|mode);word(p+2,16);word(p+4,tile|(priority<<10));
  };
  auto pixel=[&](){
   std::vector<uint8_t> picture(ppu.render_bytes());
   ppu.render(picture.data(),0x1840,io.data(),vram.data(),oam.data(),palette.data());
   unsigned x=16+(wide?8:0);auto off=(16*ppu.render_width()+x)*3;
   return std::array<uint8_t,3>{picture[off],picture[off+1],picture[off+2]};
  };
  // The transparent monitor mask (OBJ0) must reveal green BG3, never OBJ1.
  object(0,0x400,3,1);object(1,0,3,0);
  word(io.data()+0x50,0x0800);word(io.data()+0x52,0x1000);
  assert((pixel()==std::array<uint8_t,3>{0,255,0}));
  // OAM index selects the one OBJ pixel before its BG-relative priority.
  object(0,0,3,1);object(1,0,0,0);word(io.data()+14,0x0102);word(io.data()+0x50,0);
  assert((pixel()==std::array<uint8_t,3>{0,255,0}));
  // With no foreground BG, the same lowest-index blue OBJ wins.
  word(io.data()+14,0x0103);
  assert((pixel()==std::array<uint8_t,3>{0,0,255}));
 }
 std::puts("GBA OBJ layer: monitor alpha mask, OAM priority and native/wide parity passed");
}
