// Contributions by Roxas2712. Synthetic raster data only; no game assets.
#undef NDEBUG
#include "presentation.h"
#include <algorithm>
#include <array>
#include <cassert>
#include <cstdio>
#include <cstring>
static void word(uint8_t* p,unsigned v){p[0]=v;p[1]=v>>8;}
struct DispatchEntry {uint32_t addr;uint8_t thumb,resume;void (*fn)();};
extern "C" const DispatchEntry kDispatchTable[]={{0xffffffffu,0,0,nullptr}};
extern "C" const unsigned kDispatchTableLen=0;
int main(){
 gba::GbaPpu source;
 PinballTableView view;
 std::array<uint8_t,0x60> io{};
 std::array<uint8_t,96*1024> vram{};
 std::array<uint8_t,1024> oam{},palette{};
 word(io.data()+8,0x0100); // BG0 map at 0x800, 4bpp characters at zero.
 word(io.data()+10,0x0204); // BG1, separate character/map banks: green board.
 word(palette.data(),0x03e0); // Deliberately green backdrop; host must replace it.
 word(palette.data()+2,0x7fff);word(palette.data()+4,0x001f);
 // Tile 1: one white vertical stroke and seven transparent pixels per row.
 // Tile 2: a red stroke. Alternating map columns reveal real raster scrolls.
 for(unsigned row=0;row<8;row++){vram[32+row*4]=1;vram[64+row*4]=2;}
 for(unsigned row=0;row<32;row++)for(unsigned col=0;col<32;col++)word(vram.data()+0x800+(row*32+col)*2,1+col%2);
 auto frame=[&](bool reverse){
  view.scanline(source,0,0x1f00,io.data(),vram.data(),oam.data(),palette.data());
  for(unsigned y=144;y<160;y++){
   word(io.data()+0x10,((y&1)^reverse)*8); // HBlank-style scroll change.
   view.scanline(source,y,0x1f00,io.data(),vram.data(),oam.data(),palette.data());
  }
  // Final register state must not change already sampled scanlines.
  word(io.data()+0x10,123);
  view.frame_ready();
 };
 frame(false);
 for(unsigned y=0;y<16;y++)for(unsigned x=0;x<240;x++){
  const auto* pixel=view.hud()+(y*240+x)*3;
  if(x%8==0){
   const bool red=((x/8+y)%2)!=0;
   assert(pixel[0]==255&&pixel[1]==(red?0:255)&&pixel[2]==(red?0:255));
  }else assert(pixel[0]==0&&pixel[1]==0&&pixel[2]==0);
 }
 const auto saved=view.save_hud();
 // A complete transparent/multiplexed HUD pass must not flash the strip off.
 const auto tiles=vram;vram.fill(0);frame(false);assert(view.save_hud()==saved);vram=tiles;
 frame(true);assert(view.save_hud()!=saved);
 view.restored();assert(std::all_of(view.hud(),view.hud()+PinballTableView::hud_bytes,[](auto v){return v==0;}));
 view.load_hud(saved.data());assert(view.save_hud()==saved);
 // An incomplete producer frame must never publish a half-old/half-new HUD.
 view.scanline(source,0,0x1f00,io.data(),vram.data(),oam.data(),palette.data());
 view.scanline(source,144,0x1f00,io.data(),vram.data(),oam.data(),palette.data());
 view.frame_ready();assert(view.save_hud()==saved);
 std::puts("Pinball HUD raster: opaque backdrop, per-line scroll, live glyphs, complete-frame latch and restore passed");
}
