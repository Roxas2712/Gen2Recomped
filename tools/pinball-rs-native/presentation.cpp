#include "presentation.h"
#include <algorithm>
#include <cstring>
namespace {
uint16_t word(const uint8_t* p){return p[0]|(uint16_t(p[1])<<8);}
int16_t signed_word(const uint8_t* p){return static_cast<int16_t>(word(p));}
int offset_x(uint16_t v){return (v&256)?int(v&511)-512:int(v&511);}
int offset_y(uint16_t v){return (v&128)?int(v&255)-256:int(v&255);}
void put(uint8_t* p,uint16_t v){p[0]=v;p[1]=v>>8;}
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
int PinballTableView::tilemap(int bg,int,int,uint16_t*){return bg>=1&&bg<=3?gba::kWsTilemapKeepWrapped:gba::kWsTilemapUnavailable;}
int PinballTableView::object_x(int i,uint16_t,uint16_t,uint16_t,int* value){if(!rendering_||!rendering_->authored_[i])return 0;*value=rendering_->x_[i];return 1;}
int PinballTableView::object_y(int i,uint16_t,uint16_t,uint16_t,int* value){if(!rendering_||!rendering_->authored_[i])return 0;*value=rendering_->y_[i];return 1;}
bool PinballTableView::render(gba::GbaBus& bus,const gba::GbaPpu& canonical,const uint8_t*,
 std::vector<uint8_t>& rgba,uint32_t& width,uint32_t& height) {
 constexpr uint32_t main=0x0200B0C0;
 const auto field=bus.read8(main+4),state=bus.read8(main+2);
 const auto display=bus.read16(0x04000000);
 // Menus, bonus boards, pauses and capture/shop overlays retain the complete
 // original viewport until their authored full-table layouts are available.
 if((state!=2&&state!=3)||field>1||bus.read8(main+3)!=1||(display&0x87)||
    bus.read8(main+0xf)||bus.read16(main+0x28)||bus.read16(main+0x2c))return false;
 const auto* game=bus.native_code_view(0x02000000,0x1410);
 const auto* upper=bus.native_code_view(0x0200FBB0,0x8000);
 const auto* lower=bus.native_code_view(0x020030A0,0x8000);
 if(!game||!upper||!lower)return false;
 if(!surface_){surface_=std::make_unique<gba::GbaPpu>();surface_->set_view_margins(0,16,0,288);}
 std::memcpy(vram_.data(),bus.vram_ptr(),vram_.size());
 std::memcpy(oam_.data(),bus.oam_ptr(),oam_.size());
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
   const auto* item=bus.native_code_view(original+2+part*8,8);
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
  const auto* bytes=bus.native_code_view(source,length);
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
 for(unsigned y=top;y<448;y++) {
  if(y==top||(y&7)==0) {
   const unsigned row=y/8,destination=(row+10)%22;
   std::memcpy(vram_.data()+0x8000+destination*0x400,
    (row<32?upper:lower)+(row%32)*0x400,0x400);
  }
  surface_->render_presentation_scanline(canonical,y,host_display,io_.data(),vram_.data(),oam_.data(),bus.pal_ptr());
 }
 surface_->mark_framebuffer_latched();rendering_=nullptr;
 width=256;height=board_height+16;rgba.assign(size_t(width)*height*4,0);
 const auto* full=surface_->latched_framebuffer();
 for(unsigned y=0;y<board_height;y++)for(unsigned x=0;x<width;x++) {
  const uint8_t* pixel=full+((y+top)*256+x)*3;
  auto* dest=rgba.data()+(size_t(y)*width+x)*4;
  std::memcpy(dest,pixel,3);dest[3]=255;
 }
 // BG0 contains the live score, coins, caught count and reserve balls. Isolate
 // it from the scrolling board instead of copying a repeated camera fragment.
 if(!hud_)hud_=std::make_unique<gba::GbaPpu>();
 std::array<uint8_t,1024> palette;
 std::memcpy(palette.data(),bus.pal_ptr(),palette.size());palette[0]=palette[1]=0;
 for(unsigned y=144;y<160;y++)hud_->render_presentation_scanline(canonical,y,(display&0xff)|0x100,
  bus.io().raw(),bus.vram_ptr(),bus.oam_ptr(),palette.data());
 hud_->mark_framebuffer_latched();const auto* hud=hud_->latched_framebuffer();
 for(unsigned y=0;y<16;y++)for(unsigned x=0;x<width;x++) {
  auto* dest=rgba.data()+(size_t(y+board_height)*width+x)*4;
  if(x>=8&&x<248)std::memcpy(dest,hud+((y+144)*240+x-8)*3,3);
  dest[3]=255;
 }
 return true;
}
