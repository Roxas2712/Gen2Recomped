// LÖVE host for privately recompiled GBC Pinball. Contributions by Roxas2712.
#include "gbrt.h"
#include "gb_boot.h"
#include "gb_sha1.h"
#include "table.h"
#include <array>
#include <cstdio>
#include <cstring>
#include <memory>
#include <string>
#include <vector>
#include <filesystem>
#include <fstream>
#include <chrono>
#include <mutex>
#ifdef __APPLE__
#include <pthread.h>
#endif

namespace {
struct Player {
    GBContext* ctx = nullptr;
    GBJoypadState keys{0xff,0xff};
    std::vector<int16_t> pcm;
    std::array<uint8_t,160*144*4> rgba{};
    bool rumble=false;
    bool full=false;
    GBCTable table;
    std::vector<uint8_t> expanded;
    std::vector<int16_t> mono;
    std::string path,original,checkpoint;
    std::array<double,4> timings{};
    bool composed=false;
};
// The pinned runtime also has process-wide trace/bootstrap helpers. Serialize
// native calls across worker threads; independent contexts keep all game state.
std::recursive_mutex runtime_mutex;
thread_local std::string error;
void sample(GBContext* ctx, int16_t l, int16_t r) {
    auto* p=static_cast<Player*>(ctx->platform);
    if(p && p->pcm.size()<8192) { p->pcm.push_back(l); p->pcm.push_back(r); }
}
}
extern "C" {
// The no-SDL runtime leaves these defaults to its host. Each live player
// supplies its own GBJoypadState, so these remain released fallback inputs.
uint8_t g_joypad_buttons=0xff;
uint8_t g_joypad_dpad=0xff;
void pinball_gbc_mbc5_rumble(GBContext* ctx,uint8_t value) {
    auto*p=static_cast<Player*>(ctx->platform);if(p)p->rumble=(value&8)!=0;
}
const char* pinball_gbc_error() { return error.c_str(); }
void* pinball_gbc_open(const char* path) {
    std::lock_guard<std::recursive_mutex> lock(runtime_mutex);
    error.clear();
    FILE* f=path?std::fopen(path,"rb"):nullptr;
    if(!f) { error="Cannot read the GBC cartridge"; return nullptr; }
    std::vector<uint8_t> rom(1048577);
    size_t size=std::fread(rom.data(),1,rom.size(),f);std::fclose(f);
    // Generated functions are valid for this exact revision only.
    if(size!=1048576) { error="Unsupported GBC cartridge size";return nullptr; }
    uint8_t hash[20];SHA1_CTX sha;SHA1Init(&sha);SHA1Update(&sha,rom.data(),size);SHA1Final(hash,&sha);
    const uint8_t expected[20]={0x94,0x02,0x01,0x4d,0x14,0x96,0x94,0x32,0x14,0x2a,0xbf,0xde,0x72,0x8c,0x6f,0x1a,0x10,0xee,0x4d,0xac};
    if(std::memcmp(hash,expected,20)) { error="Unsupported GBC cartridge revision";return nullptr; }
    auto p=std::make_unique<Player>();
    GBConfig config{};config.model=GB_MODEL_CGB;config.enable_audio=true;config.speed_percent=100;
    config.cartridge_supports_cgb=true;config.cartridge_supports_sgb=true;
    p->ctx=gb_context_create(&config);
    if(!p->ctx) { error="GBC context allocation failed";return nullptr; }
    p->ctx->platform=p.get();p->ctx->joypad=&p->keys;
    p->ctx->hardware_mode_pref=GB_HARDWARE_MODE_CGB;
    GBPlatformCallbacks cb{};cb.on_audio_sample=sample;
    gb_set_platform_callbacks(p->ctx,&cb);
    gbrt_interp_fallback_logging=false;
    p->ctx->mbc_type=rom[0x147];
    if(!gb_context_load_rom(p->ctx,rom.data(),size) || !gb_boot_start(p->ctx,nullptr)) {
        error="GBC initialization failed";gb_context_destroy(p->ctx);return nullptr;
    }
    return p.release();
}
int pinball_gbc_step(void* handle,uint8_t dpad,uint8_t buttons) {
    std::lock_guard<std::recursive_mutex> lock(runtime_mutex);
    auto* p=static_cast<Player*>(handle);if(!p)return 0;
    p->keys={dpad,buttons};p->pcm.clear();
    gb_run_frame(p->ctx);
    if(p->ctx->has_unimplemented_interpreter_opcode) { error="Unsupported GBC instruction";return 0; }
    auto* pixels=gb_get_framebuffer(p->ctx);
    if(pixels)for(size_t i=0;i<160*144;i++) {
        p->rgba[i*4]=(pixels[i]>>16)&255;p->rgba[i*4+1]=(pixels[i]>>8)&255;
        p->rgba[i*4+2]=pixels[i]&255;p->rgba[i*4+3]=255;
    }
    return 1;
}
const uint8_t* pinball_gbc_picture(void* handle) { auto*p=static_cast<Player*>(handle);return p?p->rgba.data():nullptr; }
const int16_t* pinball_gbc_audio(void* handle,size_t* frames) {
    auto*p=static_cast<Player*>(handle);*frames=p?p->pcm.size()/2:0;return p?p->pcm.data():nullptr;
}
uint64_t pinball_gbc_counter(void* handle,int kind) {
    auto*p=static_cast<Player*>(handle);if(!p)return 0;
    if(kind==0)return p->ctx->completed_frames;
    if(kind==1)return p->ctx->total_interpreter_instructions;
    if(kind==2)return p->ctx->total_dispatch_fallbacks;
    if(kind==3)return p->ctx->total_interpreter_cycles;
    if(kind==5)return p->rumble;
    if(kind==6)return p->table.failures;
    if(kind==7)return p->table.transition_holds;
    if(kind==8)return p->table.failure_holds;
    return p->ctx->cycles;
}
int pinball_gbc_ram(void* handle,uint8_t* data,size_t size,int write) {
    auto*p=static_cast<Player*>(handle);if(!p||!data||size!=p->ctx->eram_size)return 0;
    if(write)std::memcpy(p->ctx->eram,data,size);else std::memcpy(data,p->ctx->eram,size);
    return 1;
}
void pinball_gbc_close(void* handle) {
    std::lock_guard<std::recursive_mutex> lock(runtime_mutex);
    auto*p=static_cast<Player*>(handle);if(!p)return;
    p->ctx->platform=nullptr;p->ctx->joypad=nullptr;gb_context_destroy(p->ctx);delete p;
}
// Shared Pinball ABI: the existing threaded player, duel protocol, transport,
// live-view encoder and input/display tools use the same host contract.
int ascendant_pinball_rumble(void*h){auto*p=static_cast<Player*>(h);return p&&p->rumble;}
int ascendant_pinball_priority(int active) {
#ifdef __APPLE__
    if(active>=0&&pthread_set_qos_class_self_np(active?QOS_CLASS_USER_INTERACTIVE:QOS_CLASS_UTILITY,0)!=0)return 0;
    qos_class_t current=QOS_CLASS_UNSPECIFIED;
    if(pthread_get_qos_class_np(pthread_self(),&current,nullptr)!=0)return 0;
    return static_cast<int>(current);
#else
    (void)active;return 0;
#endif
}
const char* ascendant_pinball_error(){return pinball_gbc_error();}
void* ascendant_pinball_open(const char*rom,const char*,const char*save) {
    std::lock_guard<std::recursive_mutex> lock(runtime_mutex);
    auto*p=static_cast<Player*>(pinball_gbc_open(rom));if(!p)return nullptr;
    if(save&&*save) {
        p->path=save;
        if(std::filesystem::exists(save)) {
            std::ifstream f(save,std::ios::binary);p->original.assign(std::istreambuf_iterator<char>(f),{});
            if(p->original.size()!=8192) {error="GBC Pinball battery file must contain 8192 bytes";pinball_gbc_close(p);return nullptr;}
            std::memcpy(p->ctx->eram,p->original.data(),8192);
        }
    }
    return p;
}
int ascendant_pinball_step_present(void*handle,uint16_t keys,int present) {
    std::lock_guard<std::recursive_mutex> lock(runtime_mutex);
    auto*p=static_cast<Player*>(handle);if(!p)return 0;
    auto begin=std::chrono::steady_clock::now();
    int ok=pinball_gbc_step(p,uint8_t(~(keys>>4)),uint8_t(~keys));
    auto simulated=std::chrono::steady_clock::now();
    if(present)p->composed=p->full&&p->table.compose(p->ctx,p->expanded);
    auto composed=std::chrono::steady_clock::now();
    p->timings={std::chrono::duration<double>(simulated-begin).count(),std::chrono::duration<double>(composed-simulated).count(),0,0};
    return ok;
}
int ascendant_pinball_step(void*h,uint16_t keys){return ascendant_pinball_step_present(h,keys,1);}
int ascendant_pinball_view(void*h,int mode) {auto*p=static_cast<Player*>(h);if(!p)return 0;p->full=mode!=0;p->composed=false;p->table.reset_layout();return 1;}
const uint8_t* ascendant_pinball_picture(void*h,uint32_t*w,uint32_t*height) {
    auto*p=static_cast<Player*>(h);if(!p||!w||!height)return nullptr;
    *w=p->composed?192:160;*height=p->composed?285:144;
    return p->composed?p->expanded.data():p->rgba.data();
}
const int16_t* ascendant_pinball_audio(void*h,size_t*count,uint32_t*rate) {
    auto*p=static_cast<Player*>(h);if(!p||!count||!rate)return nullptr;
    *count=p->pcm.size()/2;*rate=44100;p->mono.resize(*count);
    for(size_t i=0;i<*count;i++)p->mono[i]=(int(p->pcm[i*2])+int(p->pcm[i*2+1]))/2;
    return p->mono.data();
}
int ascendant_pinball_state(void*h,const char*path,int load) {
    std::lock_guard<std::recursive_mutex> lock(runtime_mutex);
    auto*p=static_cast<Player*>(h);if(!p||!path)return 0;
    bool ok=load?gb_context_load_state_file(p->ctx,path):gb_context_save_state_file(p->ctx,path);
    if(!ok)error="GBC Pinball quick state rejected or unavailable";
    if(load&&ok){p->pcm.clear();p->composed=false;p->table.reset_layout();}
    return ok;
}
uint64_t ascendant_pinball_frame(void*h){return pinball_gbc_counter(h,0);}
uint64_t ascendant_pinball_interpreted(void*h){return pinball_gbc_counter(h,1);}
uint32_t ascendant_pinball_read(void*h,uint32_t addr,uint32_t width) {
    auto*p=static_cast<Player*>(h);if(!p||addr>0xffff||width<1||width>4||addr+width>0x10000)return 0;
    uint32_t result=0;
    for(unsigned i=0;i<width;i++) {
        unsigned a=addr+i;uint8_t value;
        // WRAM metadata always belongs to bank 1, independent of a transient
        // audio-engine WRAM bank at the end of a native run slice.
        if(a>=0xd000&&a<0xe000)value=p->ctx->wram[0x1000+a-0xd000];
        else value=gb_read8(p->ctx,a);
        result|=uint32_t(value)<<(i*8);
    }
    return result;
}
const char* ascendant_pinball_checkpoint(void*h) {
    auto*p=static_cast<Player*>(h);if(!p)return nullptr;
    SHA1_CTX sha;SHA1Init(&sha);SHA1Update(&sha,p->ctx->wram,0x8000);
    SHA1Update(&sha,p->ctx->hram,127);SHA1Update(&sha,p->ctx->eram,p->ctx->eram_size);
    uint8_t digest[20];SHA1Final(digest,&sha);char hex[41];
    for(unsigned i=0;i<20;i++)std::snprintf(hex+i*2,3,"%02x",digest[i]);
    p->checkpoint=hex;return p->checkpoint.c_str();
}
int ascendant_pinball_table_stats(void*h,uint32_t*reused,uint32_t*rendered) {
    auto*p=static_cast<Player*>(h);if(!p||!reused||!rendered)return 0;
    *reused=0;*rendered=p->composed?272:0;return 1;
}
int ascendant_pinball_diagnostics(void*h,double*values) {
    auto*p=static_cast<Player*>(h);if(!p)return 0;
    if(values)std::copy(p->timings.begin(),p->timings.end(),values);return 1;
}
int ascendant_pinball_close(void*h) {
    std::lock_guard<std::recursive_mutex> lock(runtime_mutex);
    auto*p=static_cast<Player*>(h);if(!p)return 0;
    bool ok=true;
    if(!p->path.empty()) {
        std::string latest;
        if(std::filesystem::exists(p->path)) {std::ifstream f(p->path,std::ios::binary);latest.assign(std::istreambuf_iterator<char>(f),{});}
        const std::string bytes(reinterpret_cast<char*>(p->ctx->eram),p->ctx->eram_size);
        if(bytes!=p->original) {
            if(latest!=p->original){ok=false;error="GBC Pinball battery file changed in another session; previous data preserved";}
            else try {
                const std::string pending=p->path+".pending";
                {std::ofstream f(pending,std::ios::binary|std::ios::trunc);if(!f.write(bytes.data(),bytes.size()))throw std::runtime_error("Could not write GBC Pinball battery file");}
                std::filesystem::rename(pending,p->path);
            }catch(const std::exception&why){ok=false;error=why.what();}
        }
    }
    pinball_gbc_close(p);return ok;
}
}
