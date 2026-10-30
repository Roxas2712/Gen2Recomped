// ROM-free regression for the GBC full-table surface. By Roxas2712.
#include "table.h"
#include "ppu.h"
#include <algorithm>
#include <cstdio>
#include <stdexcept>
struct GBCTableRenderTest {
 static void run() {
  GBConfig config{};config.model=GB_MODEL_CGB;
  GBContext*c=gb_context_create(&config);if(!c)throw std::runtime_error("context");
  auto*ppu=static_cast<GBPPU*>(c->ppu);std::vector<uint8_t>out(192*285*4,0);
  auto require=[](bool pass,const char*why){if(!pass)throw std::runtime_error(why);};
  auto palette=[](uint8_t*p,unsigned id,unsigned color){p[id*2]=color;p[id*2+1]=color>>8;};
  auto solid=[&](unsigned tile,unsigned id){for(unsigned row=0;row<8;row++){c->vram[tile*16+row*2]=(id&1)?255:0;c->vram[tile*16+row*2+1]=(id&2)?255:0;}};
  c->hram[0x1e]=0x67;c->hram[0x2f]=0xff;
  palette(ppu->bg_palette_ram,1,0x7c00);palette(ppu->bg_palette_ram,2,0x03e0);
  palette(ppu->obj_palette_ram,1,0x001f);palette(ppu->obj_palette_ram,2,0x03e0);
  solid(0x101,1);solid(2,1);solid(4,2);
  std::fill(c->vram+0x1800,c->vram+0x1c00,1);
  // Software OAM belongs to the current camera. Stale hardware OAM is ignored.
  c->wram[0x1000]=32;c->wram[0x1001]=24;c->wram[0x1002]=2;
  c->oam[0]=80;c->oam[1]=80;c->oam[2]=4;
  draw_half(c,out,0,false);
  auto pixel=[&](unsigned x,unsigned y,unsigned r,unsigned g,unsigned b){unsigned at=(y*192+x)*4;return out[at]==r&&out[at+1]==g&&out[at+2]==b;};
  require(pixel(16,16,255,0,0),"Current software sprite must appear");
  require(pixel(72,64,0,0,255),"Previous hardware sprite must not leak");
  // One winning sprite is selected before background priority is resolved.
  c->wram[0x1003]=128;c->wram[0x1004]=32;c->wram[0x1005]=24;c->wram[0x1006]=4;
  draw_half(c,out,0,false);require(pixel(16,16,0,0,255),"BG-hidden front sprite must still hide lower OBJ");
  solid(2,0);draw_half(c,out,0,false);require(pixel(16,16,0,255,0),"Transparent front OBJ must expose next OBJ");
  // Window uses the STAT-switched unsigned tile bank. Its second row and
  // native framebuffer deliberately contain table-colored contamination.
  std::fill(out.begin(),out.end(),0);solid(5,2);
  for(unsigned row=0;row<8;row++){c->vram[0x1000+5*16+row*2]=255;c->vram[0x1000+5*16+row*2+1]=0;}
  std::fill(c->vram+0x1c00,c->vram+0x1c20,5);std::fill(c->vram+0x1c20,c->vram+0x1c40,1);
  std::fill(std::begin(ppu->rgb_framebuffer),std::end(ppu->rgb_framebuffer),0xffff00ff);
  c->hram[0x26]=144;draw_hud(c,out);
  for(unsigned y=272;y<285;y++)for(unsigned x=0;x<192;x++) {
   const bool text=x>=16&&x<176&&y>=274&&y<282;
   require(text?pixel(x,y,0,255,0):pixel(x,y,0,0,0),"HUD must contain only authored text row and black padding");
   require(out[(y*192+x)*4+3]==255,"HUD padding must be opaque");
  }
  // A real multi-row bonus/menu window is retained at native pixel scale.
  std::fill(out.begin(),out.end(),0);std::fill(c->vram+0x1c00,c->vram+0x1cc0,5);c->hram[0x26]=96;
  draw_hud(c,out);
  for(unsigned y=0;y<285;y++)for(unsigned x=0;x<192;x++) {
   const bool window=x>=16&&x<176&&y>=237;
   require(window?pixel(x,y,0,255,0):pixel(x,y,0,0,0),"Bonus window must remain complete on the fixed full-table canvas");
  }
  // Reproduce the cartridge boundary: new stage id, LCD still on, hBGP
  // already zero, and live VRAM still holding the old half. Keep every pixel.
  c->wram[0x18f1]=4;c->wram[0x18f2]=2;c->wram[0x14ac]=1;
  c->io[0x40]=0xe7;c->hram[0x1e]=0xe7;c->hram[0x23]=0xe4;
  GBCTable view;view.last_field=0;view.sampled_stage=0;view.last_board.assign(192*285*4,73);view.last_picture=view.last_board;
  const auto expected=view.last_picture;
  require(view.compose(c,out)&&out==expected,"New stage id must not display old-half VRAM while LCD is still on");
  c->hram[0x23]=0;
  require(view.compose(c,out)&&out==expected,"Palette-cleared loading phase must keep the completed full table");
  require(view.transition_holds==2&&view.failures==0,"Transition must hold before attempting scratch graphics");
  GBCTable first;c->io[0x40]=0;
  require(first.compose(c,out)&&out.size()==192*285*4,"First loading frame must not fall back to a half table");
  for(unsigned i=0;i<192*285;i++)require(out[i*4]==0&&out[i*4+3]==255,"Initial full-table loading canvas must be opaque");
  // A complete authored ball crosses y=136 in both directions. It is clipped
  // only by the whole board, never by either 136-pixel background half.
  GBCTable::Ball ball;ball.valid=true;ball.has_pose=true;ball.x=64;
  for(unsigned i=0;i<16*16;i++){ball.pixels[i*4]=255;ball.pixels[i*4+3]=255;}
  std::vector<uint8_t> blockers(192*272,0);
  for(int direction : {-1,1})for(int step=0;step<=24;step++) {
   ball.y=direction==1?120+step:144-step;std::fill(out.begin(),out.end(),0);
   require(GBCTable::draw_ball(ball,out,blockers,272)==256,"A seam-crossing ball must retain every opaque pixel in either direction");
  }
  ball.y=128;blockers[135*192+64]=1;blockers[136*192+64]=1;
  std::fill(out.begin(),out.end(),0);
  require(GBCTable::draw_ball(ball,out,blockers,272)==254,"Foreground priority must cover ball pixels on both sides of the seam");
  std::fill(blockers.begin(),blockers.end(),0);ball.y=120;
  require(GBCTable::draw_ball(ball,out,blockers,128)==128,"The ball must remain behind a real window overlay");
  ball.valid=false;require(GBCTable::draw_ball(ball,out,blockers,272)==0,"Intentionally hidden balls must stay hidden");
  ball.valid=true;ball.y=130;view.ball=ball;view.window_top=272;
  view.last_picture=expected;view.ball_blockers=blockers;
  require(view.retain(c,out,true)&&out[(135*192+64)*4]==255&&out[(136*192+64)*4]==255,"Loading must retain one complete ball spanning the join");
  view.ball.x=80;require(view.retain(c,out,true),"retained scene");
  require(out[(135*192+64)*4]==73&&out[(135*192+80)*4]==255,"The retained background must not accumulate old ball poses");
  // Original-game camera hides must not remove the world ball at either
  // transfer threshold; an intentional hide away from a transfer still wins.
  view.ball=ball;c->wram[0x14ac]=0;c->wram[0x14b6]=168;c->wram[0x1548]=0;
  view.ball.stage=0;view.sample_ball(c);require(view.ball.valid,"Downward camera OAM rebuild must preserve the ball");
  c->wram[0x14ac]=1;c->wram[0x14b6]=0;view.ball.stage=1;
  view.sample_ball(c);require(view.ball.valid,"Upward camera OAM rebuild must preserve the ball");
  c->wram[0x14b6]=80;view.sample_ball(c);require(!view.ball.valid,"Intentional non-transfer visibility flag must be respected");
  // A sparse/background presentation can legitimately move more than 64
  // world pixels between samples. Only unnormalized local coordinates wait.
  std::vector<uint8_t> synthetic_rom(0x8000,0);
  require(gb_context_load_rom(c,synthetic_rom.data(),synthetic_rom.size()),"synthetic cartridge context");
  c->wram[0x14ac]=0;c->wram[0x14b6]=80;c->wram[0x14b4]=80;c->wram[0x1548]=1;c->wram[0x18f2]=2;
  view.ball=ball;view.ball.stage=1;view.ball.y=210;
  view.sample_ball(c);require(view.ball.valid&&view.ball.stage==0&&view.ball.y==57,"Normalized fast crossings must update immediately even after sparse presentation");
  gb_context_destroy(c);
  std::puts("GBC surface: current OAM, OBJ/BG priority, STAT tile bank, 2496 HUD pixels and seamless world-ball coverage passed (no ROM)");
 }
 static void draw_half(GBContext*c,std::vector<uint8_t>&out,unsigned first,bool canonical){GBCTable::draw_half(c,out,first,canonical);}
 static void draw_hud(GBContext*c,std::vector<uint8_t>&out){GBCTable::draw_hud(c,out);}
};
int main(){try{GBCTableRenderTest::run();return 0;}catch(const std::exception&why){std::fprintf(stderr,"%s\n",why.what());return 1;}}
