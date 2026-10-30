// Original cartridge host and deterministic two-device link, by Roxas2712.
#include "gbrt.h"
#include "gb_boot.h"
#include "gb_sha1.h"
#include "gb_sha256.h"
#include "ir.h"
#include <array>
#include <cstdio>
#include <cstring>
#include <memory>
#include <string>
#include <vector>
namespace {
constexpr size_t RAM=32768;
struct Machine {
 GBContext* ctx=nullptr;
 GBJoypadState keys{255,255};
 std::vector<int16_t> pcm;
 std::array<uint8_t,160*144*4> rgba{};
 bool pending=false;uint8_t outgoing=255;
 ~Machine(){if(ctx)gb_context_destroy(ctx);}
};
struct Session {Machine m[2];int seats=1;uint64_t frames=0,elapsed[2]={0,0},serial=0,ir=0;
#ifdef ASCENDANT_TCG_QA
 bool call_active[2]={false,false},call_done[2]={false,false};
#endif
};
std::string error;
void sample(GBContext* ctx,int16_t l,int16_t r){auto*m=static_cast<Machine*>(ctx->platform);if(m->pcm.size()<8192){m->pcm.push_back(l);m->pcm.push_back(r);}}
void serial(GBContext* ctx,uint8_t b){auto*m=static_cast<Machine*>(ctx->platform);m->pending=true;m->outgoing=b;ctx->serial_transfer.deferred=1;}
void picture(Machine& m){auto*p=gb_get_framebuffer(m.ctx);if(p)for(size_t i=0;i<160*144;i++){m.rgba[4*i]=(p[i]>>16)&255;m.rgba[4*i+1]=(p[i]>>8)&255;m.rgba[4*i+2]=p[i]&255;m.rgba[4*i+3]=255;}}
void resolve(Session& s){
 auto&a=s.m[0];auto&b=s.m[1];
 // After both devices reach the same oscillator time, complete the cable byte.
 if(a.pending||b.pending){
  bool ap=a.pending,bp=b.pending;uint8_t av=ap?a.outgoing:255,bv=bp?b.outgoing:255;
  bool aa=ap||gb_serial_take_slave_byte(a.ctx,&av),ba=bp||gb_serial_take_slave_byte(b.ctx,&bv);
  if(ba)gb_serial_complete_transfer(b.ctx,av);
  if(aa)gb_serial_complete_transfer(a.ctx,bv);
  a.pending=b.pending=false;s.serial++;
 }
 auto*ai=static_cast<GBIRState*>(a.ctx->ir);auto*bi=static_cast<GBIRState*>(b.ctx->ir);
 bool al=gb_ir_local_led(ai),bl=gb_ir_local_led(bi);
 if(al!=gb_ir_peer_led(bi)||bl!=gb_ir_peer_led(ai))s.ir++;
 gb_ir_receive_peer_led(ai,bl);gb_ir_receive_peer_led(bi,al);
}
}
extern "C" {
uint8_t g_joypad_buttons=255,g_joypad_dpad=255;
const char* tcg_gbc_error(){return error.c_str();}
void* tcg_gbc_open(const char* path,int seats){
 error.clear();if(seats!=1&&seats!=2){error="Invalid device count";return nullptr;}
 FILE*f=path?std::fopen(path,"rb"):nullptr;if(!f){error="Cannot read TCG cartridge";return nullptr;}
 std::vector<uint8_t> rom(1048577);size_t n=std::fread(rom.data(),1,rom.size(),f);std::fclose(f);
 if(n!=1048576){error="Unsupported TCG cartridge size";return nullptr;}
 uint8_t digest[20];SHA1_CTX h;SHA1Init(&h);SHA1Update(&h,rom.data(),n);SHA1Final(digest,&h);
 const uint8_t want[20]={0x0f,0x86,0x70,0xa5,0x83,0x25,0x5c,0xff,0x3e,0x5b,0x7c,0xa7,0x1b,0x5d,0x74,0x54,0xd9,0x28,0xfc,0x48};
 if(std::memcmp(digest,want,20)){error="Unsupported TCG revision";return nullptr;}
 auto s=std::make_unique<Session>();s->seats=seats;
 for(int i=0;i<seats;i++){
  auto&m=s->m[i];GBConfig c{};c.model=GB_MODEL_CGB;c.enable_audio=true;c.enable_serial=true;c.speed_percent=100;c.cartridge_supports_cgb=true;c.cartridge_supports_sgb=true;
  m.ctx=gb_context_create(&c);if(!m.ctx){error="TCG allocation failed";return nullptr;}
  m.ctx->platform=&m;m.ctx->joypad=&m.keys;m.ctx->hardware_mode_pref=GB_HARDWARE_MODE_CGB;
  GBPlatformCallbacks cb{};cb.on_audio_sample=sample;if(seats==2)cb.on_serial_byte=serial;gb_set_platform_callbacks(m.ctx,&cb);
  m.ctx->mbc_type=rom[0x147];
  if(!gb_context_load_rom(m.ctx,rom.data(),n)||!gb_boot_start(m.ctx,nullptr)||m.ctx->eram_size!=RAM){error="TCG initialization failed";return nullptr;}
 }
 gbrt_interp_fallback_logging=false;return s.release();
}
int tcg_gbc_step(void* handle,uint8_t d0,uint8_t b0,uint8_t d1,uint8_t b1){
 auto*s=static_cast<Session*>(handle);if(!s)return 0;
 s->m[0].keys={d0,b0};s->m[1].keys={d1,b1};
 for(int i=0;i<s->seats;i++){s->m[i].pcm.clear();gb_reset_frame(s->m[i].ctx);}
 if(s->seats==1)gb_run_cycles(s->m[0].ctx,70224);
 else {
  const uint64_t target=(s->frames+1)*70224;
  // Slices stop at instruction boundaries (<=24 oscillator cycles). Both
  // devices share one time axis, including CGB double-speed transitions.
  while(s->elapsed[0]<target||s->elapsed[1]<target){
   int i=s->elapsed[0]<=s->elapsed[1]?0:1;
   auto*c=s->m[i].ctx;c->frame_done=0;
   uint32_t before=c->cycles;
#ifdef ASCENDANT_TCG_QA
   if(s->call_active[i]&&c->pc==0xfffe)s->call_done[i]=true;
   if(s->call_done[i])gb_tick(c,4);else
#endif
   gb_run_cycles(c,4);
   uint32_t delta=c->cycles-before;
   if(!delta){error="TCG device stopped advancing";return 0;}s->elapsed[i]+=delta;
   // Resolve when the other CPU catches up to a pending master's timestamp.
   if((s->m[0].pending&&s->elapsed[1]>=s->elapsed[0])||(s->m[1].pending&&s->elapsed[0]>=s->elapsed[1]))resolve(*s);
   else {
    auto*a=static_cast<GBIRState*>(s->m[0].ctx->ir);auto*b=static_cast<GBIRState*>(s->m[1].ctx->ir);
    bool al=gb_ir_local_led(a),bl=gb_ir_local_led(b);
    if(al!=gb_ir_peer_led(b)||bl!=gb_ir_peer_led(a))s->ir++;
    gb_ir_receive_peer_led(a,bl);gb_ir_receive_peer_led(b,al);
   }
  }
 }
 for(int i=0;i<s->seats;i++){
  if(s->m[i].ctx->has_unimplemented_interpreter_opcode){error="Unsupported TCG instruction";return 0;}picture(s->m[i]);
 }
 s->frames++;return 1;
}
const uint8_t* tcg_gbc_picture(void*h,int seat){auto*s=static_cast<Session*>(h);return s&&seat>=0&&seat<s->seats?s->m[seat].rgba.data():nullptr;}
const int16_t* tcg_gbc_audio(void*h,int seat,size_t*n){auto*s=static_cast<Session*>(h);if(!s||seat<0||seat>=s->seats){*n=0;return nullptr;}auto&m=s->m[seat];*n=m.pcm.size()/2;return m.pcm.data();}
int tcg_gbc_ram(void*h,int seat,uint8_t*data,size_t n,int write){auto*s=static_cast<Session*>(h);if(!s||seat<0||seat>=s->seats||!data||n!=RAM)return 0;auto*c=s->m[seat].ctx;if(write)std::memcpy(c->eram,data,n);else std::memcpy(data,c->eram,n);return 1;}
uint64_t tcg_gbc_counter(void*h,int seat,int kind){auto*s=static_cast<Session*>(h);if(!s||seat<0||seat>=s->seats)return 0;auto*c=s->m[seat].ctx;if(kind==0)return s->frames;if(kind==1)return c->total_interpreter_instructions;if(kind==2)return c->total_dispatch_fallbacks;if(kind==3)return s->serial;if(kind==4)return s->ir;return c->cycles;}
// Hash explicit deterministic state, never pointers, padding or host timings.
void tcg_gbc_digest(void*h,char out[65]){
 auto*s=static_cast<Session*>(h);if(!s){out[0]=0;return;}GBSha256Ctx hash;gb_sha256_init(&hash);
 for(int i=0;i<s->seats;i++){
  auto*c=s->m[i].ctx;
  uint8_t regs[]={c->a,c->f,c->b,c->c,c->d,c->e,c->h,c->l,uint8_t(c->pc),uint8_t(c->pc>>8),uint8_t(c->sp),uint8_t(c->sp>>8)};
  gb_sha256_update(&hash,regs,sizeof(regs));
  gb_sha256_update(&hash,c->wram,0x8000);gb_sha256_update(&hash,c->vram,0x4000);gb_sha256_update(&hash,c->oam,0xa0);gb_sha256_update(&hash,c->eram,RAM);gb_sha256_update(&hash,c->io,0x81);gb_sha256_update(&hash,c->hram,0x7f);
 }
 uint8_t d[32];gb_sha256_final(&hash,d);for(int i=0;i<32;i++)std::sprintf(out+2*i,"%02x",d[i]);out[64]=0;
}
// Copy-only memory contract for TCG API 1; offsets are region-relative.
int tcg_gbc_memory(void*h,int seat,int region,uint32_t offset,uint8_t* data,size_t n,int write){
 auto*s=static_cast<Session*>(h);if(!s||seat<0||seat>=s->seats||!data||n>4096)return 0;
 auto*c=s->m[seat].ctx;uint8_t*base=nullptr;size_t size=0;
 switch(region){case 0:base=c->wram;size=0x8000;break;case 1:base=c->eram;size=RAM;break;case 2:base=c->vram;size=0x4000;break;case 3:base=c->io;size=0x81;break;case 4:base=c->hram;size=0x7f;break;case 5:base=c->oam;size=0xa0;break;case 6:base=c->rom;size=1048576;break;default:return 0;}
 if(offset>size||n>size-offset||(write&&(s->seats!=1||region>1)))return 0;
 if(write)std::memcpy(base+offset,data,n);else std::memcpy(data,base+offset,n);return 1;
}
#ifdef ASCENDANT_TCG_QA
int tcg_gbc_qa_call(void*h,int seat,int bank,int pc,int a){
 auto*s=static_cast<Session*>(h);if(!s||s->seats!=2||seat<0||seat>1||bank<0||bank>63||pc<0||pc>65535)return 0;
 auto*c=s->m[seat].ctx;c->pc=pc;c->a=a;c->rom_bank=bank;c->hram[0]=bank;c->sp=0xdff0;
 c->ime=1;c->ime_pending=0;c->halted=0;c->halt_bug=0;c->stopped=0;c->stop_mode_active=0;c->frame_done=0;
 gb_write16(c,c->sp,0xfffe);s->call_active[seat]=true;s->call_done[seat]=false;return 1;
}
int tcg_gbc_qa_write(void*h,int seat,uint16_t address,const uint8_t*data,size_t n){
 auto*s=static_cast<Session*>(h);if(!s||seat<0||seat>=s->seats||!data||n>4096||n>65536u-address)return 0;
 for(size_t j=0;j<n;j++)gb_write8(s->m[seat].ctx,address+j,data[j]);return 1;
}
uint32_t tcg_gbc_qa_reg(void*h,int seat,int reg){
 auto*s=static_cast<Session*>(h);if(!s||seat<0||seat>=s->seats)return 0;auto*c=s->m[seat].ctx;
 switch(reg){case 0:return(c->a<<8)|c->f;case 1:return(c->b<<8)|c->c;case 2:return(c->d<<8)|c->e;case 3:return(c->h<<8)|c->l;case 4:return c->sp;case 5:return c->pc;case 6:return c->rom_bank;case 7:return s->call_done[seat];default:return 0;}
}
#endif
void tcg_gbc_close(void*h){delete static_cast<Session*>(h);}
}
