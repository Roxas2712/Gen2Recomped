#include "presentation.h"
#include <algorithm>
#include <cstring>
#include <cstdlib>
namespace {
uint16_t word(const uint8_t* p){return p[0]|(uint16_t(p[1])<<8);}
int16_t signed_word(const uint8_t* p){return static_cast<int16_t>(word(p));}
int offset_x(uint16_t v){return (v&256)?int(v&511)-512:int(v&511);}
int offset_y(uint16_t v){return (v&128)?int(v&255)-256:int(v&255);}
void put(uint8_t* p,uint16_t v){p[0]=v;p[1]=v>>8;}
// This pinned runtime's native_code_view exposes RAM and mapper-backed code,
// not ordinary 8/16 MiB cartridge assets. Pinball's verified ROM is contiguous.
const uint8_t* cartridge_view(const gba::GbaBus& bus,uint32_t address,size_t size){
 if(address<0x08000000u)return nullptr;
 const uint64_t offset=uint64_t(address)-0x08000000u;
 if(!bus.rom_ptr()||offset+size>bus.rom_size())return nullptr;
 return bus.rom_ptr()+offset;
}
// These hooks exist only during composition of the separate host surface.
// The canonical GBA PPU never sees expanded rows, altered OAM or tile banks.
struct Providers {
 decltype(gba::g_ws_tilemap_provider) tiles=gba::g_ws_tilemap_provider;
 decltype(gba::g_ws_obj_attr_x_provider) x=gba::g_ws_obj_attr_x_provider;
 decltype(gba::g_ws_obj_attr_y_provider) y=gba::g_ws_obj_attr_y_provider;
 int layers=gba::g_ws_authored_margin_layers;
 ~Providers(){gba::g_ws_tilemap_provider=tiles;gba::g_ws_obj_attr_x_provider=x;gba::g_ws_obj_attr_y_provider=y;gba::g_ws_authored_margin_layers=layers;}
};
}
PinballTableView* PinballTableView::rendering_=nullptr;
PinballTableView::PinballTableView():cache_enabled_(std::getenv("ASCENDANT_PINBALL_REFERENCE_TABLE")==nullptr){}
// Render only BG0 with each line's real scroll/VRAM/palette state. Copying the
// canonical composite also copied the scrolling board through transparent HUD
// texels; re-rendering BG0 at the frame boundary used the wrong raster registers.
void PinballTableView::scanline(const gba::GbaPpu& source,uint32_t y,uint16_t display,
 const uint8_t* io,const uint8_t* vram,const uint8_t* oam,const uint8_t* palette) {
 if(y==0)hud_rows_.fill(false);
 if(y<144||y>=160)return;
 if(!hud_surface_)hud_surface_=std::make_unique<gba::GbaPpu>();
 std::array<uint8_t,0x60> hud_io;std::memcpy(hud_io.data(),io,hud_io.size());
 std::array<uint8_t,1024> hud_palette;std::memcpy(hud_palette.data(),palette,hud_palette.size());
 hud_palette[0]=hud_palette[1]=0; // Opaque host backdrop, never the board.
 put(hud_io.data()+0x50,0); // Do not blend BG0 with removed board layers.
 put(hud_io.data()+0x52,0);put(hud_io.data()+0x54,0);
 const uint16_t hud_display=(display&0xff)|0x100; // keep BG0; no OBJ, BG1-3 or windows
 hud_surface_->render_presentation_scanline(source,y,hud_display,hud_io.data(),vram,oam,hud_palette.data());
 hud_rows_[y-144]=true;
}
void PinballTableView::frame_ready() {
 if(!hud_surface_||!std::all_of(hud_rows_.begin(),hud_rows_.end(),[](bool row){return row;}))return;
 hud_surface_->mark_framebuffer_latched();
 const auto* strip=hud_surface_->latched_framebuffer()+144*240*3;
 // A blank BG0 scanout contains no new score. Retain the latest complete
 // authored strip across these observed presentation gaps. Zero
 // scores still contain glyphs; genuine changes publish on the next HUD pass.
 if(std::any_of(strip,strip+hud_bytes,[](uint8_t value){return value!=0;}))
  std::memcpy(hud_rgb_.data(),strip,hud_bytes);
}
void PinballTableView::restored() noexcept {hud_rgb_.fill(0);hud_rows_.fill(false);}
std::vector<uint8_t> PinballTableView::save_hud() const {return {hud_rgb_.begin(),hud_rgb_.end()};}
void PinballTableView::load_hud(const uint8_t* bytes) {std::memcpy(hud_rgb_.data(),bytes,hud_bytes);}
bool PinballTableView::unchanged_band(unsigned band,unsigned first,unsigned end,uint16_t display,const uint8_t* palette) {
 if(!cache_enabled_)return false;
 dependency_.clear();
 auto append=[&](const void* p,size_t length){const auto* bytes=static_cast<const uint8_t*>(p);dependency_.insert(dependency_.end(),bytes,bytes+length);};
 append(palette,2); // backdrop, including fully transparent rows
 // Host scrolls are zero and the supported board uses regular mode-0 BGs.
 // Include each referenced map entry and its entire tile; flips and palettes
 // cannot make a changed texel evade this exact-byte dependency comparison.
 for(unsigned bg=1;bg<4;bg++) {
  if(!(display&(0x100<<bg)))continue;
  const unsigned cnt=word(io_.data()+8+bg*2),size=cnt>>14;
  const unsigned base=((cnt>>8)&31)*0x800,characters=((cnt>>2)&3)*0x4000;
  const unsigned rows=(size&2)?64:32,columns=(size&1)?64:32;
  const unsigned tile_y=(first/8)%rows,block_columns=columns/32;
  for(unsigned x=0;x<32;x++) {
   const unsigned block=(x/32)+(tile_y/32)*block_columns;
   const unsigned off=base+block*0x800+((tile_y%32)*32+x%32)*2;
   if(off+2>vram_.size())continue;
   append(vram_.data()+off,2);
   const unsigned entry=word(vram_.data()+off),length=(cnt&0x80)?64:32;
   const unsigned tile=characters+(entry&1023)*length;
   if(tile+length<=vram_.size())append(vram_.data()+tile,length);
   append(palette+((cnt&0x80)?0:(entry>>12)*32),(cnt&0x80)?512:32);
  }
 }
 constexpr unsigned dimensions[3][4][2]={{{8,8},{16,16},{32,32},{64,64}},{{16,8},{32,8},{32,16},{64,32}},{{8,16},{8,32},{16,32},{32,64}}};
 for(unsigned id=0;id<128;id++) {
  if(!authored_[id])continue;
  const auto* object=oam_.data()+id*8;const unsigned a=word(object),b=word(object+2),attributes=word(object+4),shape=a>>14;
  if(shape>=3)continue;
  const bool affine=(a&0x100)!=0;
  const unsigned height=dimensions[shape][b>>14][1]*((affine&&(a&0x200))?2:1);
  if(y_[id]>=int(end)||y_[id]+int(height)<=int(first))continue;
  append(&id,sizeof(id));append(object,6);append(&x_[id],sizeof(int));append(&y_[id],sizeof(int));
  const unsigned tile_width=dimensions[shape][b>>14][0]/8,tile_height=dimensions[shape][b>>14][1]/8;
  const bool color256=(a&0x2000)!=0;const unsigned tile_bytes=color256?64:32;
  for(unsigned tile_y=0;tile_y<tile_height;tile_y++)for(unsigned tile_x=0;tile_x<tile_width;tile_x++) {
   const unsigned tile=(attributes&1023)+((display&0x40)?(tile_y*tile_width+tile_x)*(color256?2:1):tile_y*32+tile_x*(color256?2:1));
   const unsigned offset=0x10000+tile*32;
   if(offset<vram_.size())append(vram_.data()+offset,std::min<size_t>(tile_bytes,vram_.size()-offset));
  }
  append(palette+512+(color256?0:(attributes>>12)*32),color256?512:32);
  if(affine) {
   const unsigned matrix=((b>>9)&31)*32;
   for(unsigned component=0;component<4;component++)append(oam_.data()+matrix+component*8+6,2);
  }
 }
 if(bands_valid_[band]&&bands_[band]==dependency_)return true;
 bands_[band]=dependency_;bands_valid_[band]=true;return false;
}
int PinballTableView::tilemap(int bg,int,int,uint16_t*){return bg>=1&&bg<=3?gba::kWsTilemapKeepWrapped:gba::kWsTilemapUnavailable;}
int PinballTableView::object_x(int i,uint16_t,uint16_t,uint16_t,int* value){if(!rendering_||!rendering_->authored_[i])return 0;*value=rendering_->x_[i];return 1;}
int PinballTableView::object_y(int i,uint16_t,uint16_t,uint16_t,int* value){if(!rendering_||!rendering_->authored_[i])return 0;*value=rendering_->y_[i];return 1;}
bool PinballTableView::render(gba::GbaBus& bus,const gba::GbaPpu& canonical,uint64_t native_frame,
 std::vector<uint8_t>& rgba,uint32_t& width,uint32_t& height) {
 reused_rows=rendered_rows=0;
 constexpr uint32_t main=0x0200B0C0;
 const auto field=bus.read8(main+4),state=bus.read8(main+2);
 const auto display=bus.read16(0x04000000);
 // Menus, bonus boards, pauses and capture/shop overlays retain the complete
 // original viewport until their authored full-table layouts are available.
 const bool eligible=(state==2||state==3)&&field<=1&&bus.read8(main+3)==1&&!(display&0x87)&&
    !bus.read8(main+0xf)&&!bus.read16(main+0x28)&&!bus.read16(main+0x2c);
 // Native banners remain complete and live. Recover the portrait layout only
 // after half a second of stable gameplay, so blinking flags cannot repeatedly
 // zoom the whole pane. Repainting the same guest frame never advances this.
 if(!eligible){if(expanded_once_)stable_frames_=0;last_frame_=native_frame;return false;}
 if(native_frame!=last_frame_){
  if(stable_frames_<30)stable_frames_=native_frame==last_frame_+1?std::min(30u,stable_frames_+1):1;
  last_frame_=native_frame;
 }
 if(stable_frames_<30)return false;
 expanded_once_=true;
 const auto* game=bus.native_code_view(0x02000000,0x1410);
 const auto* upper=bus.native_code_view(0x0200FBB0,0x8000);
 const auto* lower=bus.native_code_view(0x020030A0,0x8000);
 if(!game||!upper||!lower)return false;
 if(!surface_){surface_=std::make_unique<gba::GbaPpu>();surface_->set_view_margins(0,16,0,288);}
 std::memcpy(vram_.data(),bus.vram_ptr(),vram_.size());
 // Sprite-group IDs/poses describe the freshly built software OAM buffer.
 // Hardware OAM is uploaded later by DefaultMainCallback after VBlank wait;
 // pairing its previous frame with current IDs made actors blink/misassign.
 const auto* sprite_oam=bus.native_code_view(0x03005000,oam_.size());
 if(!sprite_oam)return false;
 std::memcpy(oam_.data(),sprite_oam,oam_.size());
 std::memcpy(io_.data(),bus.io().raw(),io_.size());
 // Board BG1/2/3 share world coordinates. Stream BG3's 22-row hardware ring
 // from the game's two live decompressed buffers for EACH authored world row.
 // This renders current data; no camera history or stale-frame stitching.
 for(unsigned i=0x14;i<0x20;i++)io_[i]=0;
 const int camera_x=signed_word(game+0x58),camera_y=signed_word(game+0x5a);
 authored_.fill(false);
 const auto table=bus.read32(main+0x44);
 if(table<0x08000000||table>0x08ffff00)return false;
 const auto first=bus.read32(table);
 const auto group_base=first-(field==0?70:74)*0xb8;
 const auto* groups=bus.native_code_view(group_base,100*0xb8);
 if(!groups)return false;
#ifdef PINBALL_EU_VARIANT
 constexpr uint32_t sets=0x0894F224;
 constexpr uint32_t cave_gfx=0x0873FAAC,cynda_gfx=0x0866E9EC,makuhita_gfx=0x086A2B6C;
 constexpr uint32_t egg_frames=0x08949052,chinchou_gfx=0x085E728C,lotad_gfx=0x0866DEEC;
#else
 constexpr uint32_t sets=0x086B155C;
 constexpr uint32_t cave_gfx=0x084FB68C,cynda_gfx=0x08449D8C,makuhita_gfx=0x0847DF0C;
 constexpr uint32_t egg_frames=0x086AD2EE,chinchou_gfx=0x083C806C,lotad_gfx=0x0844928C;
#endif
 const auto sprites=bus.read32(sets+field*8);
 const auto group_count=bus.read16(sets+field*8+4);
 if(group_count>100)return false;
 for(unsigned group=0;group<group_count;group++) {
  // Screen-space HUD and the camera's right-edge mask have no world position.
  if(group<3||(group>=5&&group<=9)||group==(field==0?81:85))continue;
  const auto* g=groups+group*0xb8;
  if(!word(g))continue;
  const int base_x=signed_word(g+2),base_y=signed_word(g+4);
  // Explicit offscreen sentinels lack a usable authored world position.
  if(base_y==180||base_y==200)continue;
  const auto original=bus.read32(sprites+group*4);
  const auto count=std::min<unsigned>(22,bus.read16(original));
  for(unsigned part=0;part<count;part++) {
   const auto* simple=g+8+part*8;const auto id=word(simple);
   if(id>=128)continue;
   const int dx=offset_x(word(simple+2)),dy=offset_y(word(simple+4));
   const int sx=base_x+dx,sy=base_y+dy;
   const auto* actual=oam_.data()+id*8;
   if((field==0&&group==62&&part<6)||(field==1&&group==63&&part<3)) {
    const unsigned bumper=field==0?part/2:part;
    authored_[id]=true;
    x_[id]=signed_word(game+0x178+bumper*4)/10-8+dx;
    y_[id]=signed_word(game+0x17a+bumper*4)/10-(field==0?4:10)+dy;
    continue;
   }
   if((word(actual)&255)!=(sy&255)||(word(actual+2)&511)!=(sx&511))continue;
   authored_[id]=true;x_[id]=sx+camera_x;y_[id]=sy+camera_y;
  }
 }
 // The original game omits entire physical groups when its small camera cannot
 // see them. Reconstruct known board props from the cartridge's sprite sets,
 // current VRAM animation frames and authored world positions, in host OAM.
 auto prop=[&](unsigned group,int world_x,int world_y,int bumper_mode=0) {
  if(group>=group_count||word(groups+group*0xb8))return;
  const auto original=bus.read32(sprites+group*4);
  const auto count=std::min<unsigned>(22,bus.read16(original));
  for(unsigned part=0;part<count;part++) {
   const auto* item=cartridge_view(bus,original+2+part*8,8);
   if(!item||(word(item)&0x100))continue; // unauthored affine pose
   unsigned id=0;while(id<128&&authored_[id])id++;if(id==128)return;
   const auto a=word(item),b=word(item+2);
   put(oam_.data()+id*8,a);put(oam_.data()+id*8+2,b);put(oam_.data()+id*8+4,word(item+4));
   int px=world_x,py=world_y;
   if(bumper_mode) {
    const unsigned n=bumper_mode==1?part/2:part;
    if(n>=3)continue;
    px=signed_word(game+0x178+n*4)/10-8;
    py=signed_word(game+0x17a+n*4)/10-(bumper_mode==1?4:10);
   }
   authored_[id]=true;x_[id]=px+offset_x(b);y_[id]=py+offset_y(a);
  }
 };
 // Culling also prevents the cartridge from uploading some offscreen graphics.
 // Supply those original frames to the HOST copy only; never patch guest VRAM.
 auto tiles=[&](unsigned group,uint32_t source,unsigned tile,unsigned length) {
  if(word(groups+group*0xb8))return;
  const auto* bytes=cartridge_view(bus,source,length);
  if(bytes&&0x10000+tile*32+length<=vram_.size())std::memcpy(vram_.data()+0x10000+tile*32,bytes,length);
 };
 if(field==0) {
  const unsigned egg_frame=game[0x1ed];
  if(egg_frame<34) {
   const unsigned pose=bus.read16(egg_frames+egg_frame*8+4);
   if(pose<6)tiles(52,cave_gfx+pose*1152,0x115,1152);
  }
  if(game[0x746]<5)tiles(51,cynda_gfx+game[0x746]*640,0x198,640);
  const unsigned counter=word(game+0x304),state=game[0x300];
  const unsigned pose=state==2?counter%9/3+4:state==4?counter%9/3+7:counter%36/18+(state?2:0);
  tiles(58,makuhita_gfx+pose*768,0x1ac,768);
  for(unsigned i=0;i<3;i++) {
   const unsigned hit=game[0x170+i];
   const unsigned idle=bus.read32(0x02000290)%50/25;
   const unsigned frame=hit>100?(game[0x16c]==4?8:9-hit/105):hit?hit:idle;
   if(frame<10)tiles(62,(game[0x16c]==4?lotad_gfx:chinchou_gfx)+frame*256,0x174+i*8,256);
  }
  prop(52,88,144);prop(58,184,277);prop(65,208,80);
  if(signed_word(game+0x2d4)||signed_word(game+0x2d6))prop(51,signed_word(game+0x2d4),signed_word(game+0x2d6));
  if(!game[0x2a4])prop(62,0,0,1);
 }else {
  prop(61,68,144);prop(62,36,163);prop(63,0,0,2);
 }
 for(unsigned i=0;i<128;i++)if(!authored_[i])put(oam_.data()+i*8,0x0200);
 Providers restore;rendering_=this;
 struct Reset {PinballTableView*& value;~Reset(){value=nullptr;}} reset{rendering_};
 gba::g_ws_tilemap_provider=tilemap;gba::g_ws_obj_attr_x_provider=object_x;
 gba::g_ws_obj_attr_y_provider=object_y;gba::g_ws_authored_margin_layers=1;
 // Disable only the viewport-sized HUD/window masks in the host copy. The
 // original HUD is rendered separately below the complete board.
 const uint16_t host_display=(display&~uint16_t(0xe100))|0x1e00;
 const unsigned top=field==0?100:76,board_height=448-top;
 std::array<uint8_t,18> render_io;
 put(render_io.data(),host_display);std::memcpy(render_io.data()+2,io_.data()+0xa,6);
 std::memcpy(render_io.data()+8,io_.data()+0x4c,10);
 // VCOUNT, DISPSTAT, HUD scrolls and unused affine registers do not affect
 // these mode-0 host rows. They must not invalidate the board every frame.
 if(cache_enabled_&&(!global_valid_||cached_field_!=field||cached_io_!=render_io)) {
  bands_valid_.fill(false);global_valid_=true;cached_field_=field;cached_io_=render_io;
 }
 bool reuse=false;
 for(unsigned y=top;y<448;y++) {
  if(y==top||(y&7)==0) {
   const unsigned row=y/8,destination=(row+10)%22;
   std::memcpy(vram_.data()+0x8000+destination*0x400,
    (row<32?upper:lower)+(row%32)*0x400,0x400);
   reuse=unchanged_band(y/8,y,std::min(448u,(y/8+1)*8),host_display,bus.pal_ptr());
  }
  if(reuse)++reused_rows;
  else{surface_->render_presentation_scanline(canonical,y,host_display,io_.data(),vram_.data(),oam_.data(),bus.pal_ptr());++rendered_rows;}
 }
 surface_->mark_framebuffer_latched();rendering_=nullptr;
 width=256;height=board_height+16;rgba.assign(size_t(width)*height*4,0);
 const auto* full=surface_->latched_framebuffer();
 for(unsigned y=0;y<board_height;y++)for(unsigned x=0;x<width;x++) {
  const uint8_t* pixel=full+((y+top)*256+x)*3;
  auto* dest=rgba.data()+(size_t(y)*width+x)*4;
  std::memcpy(dest,pixel,3);dest[3]=255;
 }
 // The isolated completed BG0 mirror has an opaque black backdrop. No pixels
 // from BG1/2/3, table sprites or camera movement can leak into this strip.
 for(unsigned y=0;y<16;y++)for(unsigned x=0;x<width;x++) {
  auto* dest=rgba.data()+(size_t(y+board_height)*width+x)*4;
  if(x>=8&&x<248)std::memcpy(dest,hud_rgb_.data()+(y*240+x-8)*3,3);
  dest[3]=255;
 }
 return true;
}
