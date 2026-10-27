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
 // A camera-culled bumper must still be reconstructed at its world position.
 // Synthetic cartridge templates/tiles only: no extracted game data.
 gba::GbaBus bus;std::vector<uint8_t> rom(8*1024*1024);
 auto rw=[&](unsigned address,unsigned v){word(rom.data()+address-0x08000000,v);};
 auto rd=[&](unsigned address,unsigned v){rw(address,v);rw(address+2,v>>16);};
 constexpr unsigned templates=0x08000400,sprite=0x08000800,table=0x08000900;
 rd(0x086b155c,templates);rw(0x086b1560,84);rd(templates+62*4,sprite);
 rw(sprite,6);
 for(unsigned part=0;part<6;part++){
  rw(sprite+2+part*8,0x8000);rw(sprite+4+part*8,0x4000+(part%2?0x100f:0));
  rw(sprite+6+part*8,0x174+(part/2)*8);
 }
 std::fill(rom.begin()+0x003c806c,rom.begin()+0x003c806c+512,0x11);
 bus.set_rom(rom.data(),rom.size());
 bus.write16(0x04000000,0x1e40);bus.write8(0x0200b0c2,2);bus.write8(0x0200b0c3,1);
 bus.write32(0x0200b104,table);rd(table,0x0200b3b8+70*0xb8);
 bus.write16(0x05000202,0x7fff);
 for(unsigned n=0;n<3;n++){bus.write16(0x02000178+n*4,1250+n*100);bus.write16(0x0200017a+n*4,1270+n*100);}
 PinballTableView world;std::vector<uint8_t> rgba;uint32_t width,height;
 assert(world.render(bus,source,1,rgba,width,height));
 const auto pixel=(23*width+117)*4;
 assert(rgba[pixel]==255&&rgba[pixel+1]==255&&rgba[pixel+2]==255);
 // Current group IDs belong to software OAM, not last VBlank's hardware OAM.
 const unsigned group=0x0200b3b8+58*0xb8,template58=0x08000a00;
 rd(templates+58*4,template58);rw(template58,1);
 bus.write16(group,1);bus.write16(group+2,60);bus.write16(group+4,210);
 bus.write16(group+8,20);bus.write16(group+10,0);bus.write16(group+12,0);
 bus.write16(0x03005000+20*8,210);bus.write16(0x03005002+20*8,60);bus.write16(0x03005004+20*8,0x174);
 bus.write16(0x07000000+20*8,0x200); // stale/disabled hardware allocation
 assert(world.render(bus,source,2,rgba,width,height));
 const auto active_pixel=(110*width+60)*4;
 assert(rgba[active_pixel]==255&&rgba[active_pixel+1]==255&&rgba[active_pixel+2]==255);
 assert(bus.read16(0x07000000+20*8)==0x200); // presentation never patches the guest
 std::puts("Pinball HUD raster: opaque backdrop, per-line scroll, live glyphs, complete-frame latch, restore and camera-culled/current-frame world sprites passed");
}
