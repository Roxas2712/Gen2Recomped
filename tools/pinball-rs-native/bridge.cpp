// Same-window Pokémon Pinball R/S integration by Roxas2712.
// Links the separately licensed, pinned GBARecomp runtime and user-generated
// cartridge code. Cartridge bytes and generated code never belong in Git.
#include "runtime_arm.h"
#include "runtime_bus_bridge.h"
#include "runtime_context.h"
#include "bios_hle.h"
#include "gba_bus.h"
#include "gba_ppu.h"
#include "sha1.h"
#include "snapshot.h"
#include "self_heal.h"
#include "presentation.h"
#include <array>
#include <algorithm>
#include <filesystem>
#include <fstream>
#include <memory>
#include <mutex>
#include <string>
#include <vector>
#include <stdexcept>
#include <cstring>
#include <unordered_set>
#include <chrono>
#ifdef __APPLE__
#include <mach/mach.h>
#include <pthread.h>
#else
#include <time.h>
#endif

namespace {
#ifdef PINBALL_EU_VARIANT
constexpr const char* rom_sha1="b8b7881eaa9856b5ada99078ad1053d31cb79827";
constexpr size_t rom_size=16*1024*1024;
constexpr const char* cartridge_code="BPPP";
#else
constexpr const char* rom_sha1="9fec81ce2c5df589e0371a0bf2f92a5fe8db730b";
constexpr size_t rom_size=8*1024*1024;
constexpr const char* cartridge_code="BPPE";
#endif
std::mutex ownership;
thread_local std::string error;
std::vector<uint8_t> bytes(const char* path) {
 std::ifstream file(path,std::ios::binary|std::ios::ate);
 if(!file)throw std::runtime_error("Input file cannot be opened");
 const auto count=file.tellg();
 if(count<0||count>32*1024*1024)throw std::runtime_error("Invalid input size");
 std::vector<uint8_t> result(static_cast<size_t>(count));file.seekg(0);
 if(!file.read(reinterpret_cast<char*>(result.data()),count))throw std::runtime_error("Input file was truncated");
 return result;
}
double thread_seconds() {
#ifdef __APPLE__
 thread_basic_info_data_t info{};mach_msg_type_number_t count=THREAD_BASIC_INFO_COUNT;
 if(thread_info(pthread_mach_thread_np(pthread_self()),THREAD_BASIC_INFO,reinterpret_cast<thread_info_t>(&info),&count)!=KERN_SUCCESS)return 0;
 return info.user_time.seconds+info.system_time.seconds+(info.user_time.microseconds+info.system_time.microseconds)*1e-6;
#elif defined(CLOCK_THREAD_CPUTIME_ID)
 timespec t{};clock_gettime(CLOCK_THREAD_CPUTIME_ID,&t);return t.tv_sec+t.tv_nsec*1e-9;
#else
 return 0;
#endif
}
struct Machine {
 gba::GbaBios bios;
 gba::GbaBus bus;
 gba::GbaPpu ppu;
 std::vector<uint8_t> rom,rgba;
 std::string checkpoint;
 std::array<int16_t,8192> samples{};
 size_t sample_count=0;
 uint32_t sample_rate=32768;
 std::string save;
 uint64_t calls=0,cycles=0,frames=0;
 uint64_t picture_frame=~uint64_t(0);
 uint64_t interpreted=0;
 gbarecomp::RuntimeArmContext execution;
 gbarecomp::RuntimeTimingContext timing;
 uint16_t buttons=0;
 bool full_table=false;
 bool diagnostics=false;
 std::array<double,4> timings{};
 uint32_t width=240,height=160;
 PinballTableView table_view;
 void picture() {
  const uint32_t w=ppu.render_width(),h=ppu.render_height();
  const uint8_t* rgb=ppu.latched_framebuffer();
  std::vector<uint8_t> fallback;
  if(!ppu.has_latched_framebuffer()) {
   fallback.resize(ppu.render_bytes());
   ppu.render(fallback.data(),bus.read16(0x04000000),bus.io().raw(),bus.vram_ptr(),bus.oam_ptr(),bus.pal_ptr());rgb=fallback.data();
  }
  if(full_table&&table_view.render(bus,ppu,frames,rgba,width,height)){picture_frame=frames;return;}
  width=w;height=h;
  rgba.resize(static_cast<size_t>(w)*h*4);
  for(size_t i=0;i<static_cast<size_t>(w)*h;i++) {
   rgba[i*4]=rgb[i*3];rgba[i*4+1]=rgb[i*3+1];rgba[i*4+2]=rgb[i*3+2];rgba[i*4+3]=255;
  }
  picture_frame=frames;
 }
 bool flush() {
  if(save.empty()||!bus.save().dirty())return true;
  const auto& content=bus.save().sram_bytes();
  const auto pending=save+".pending";
  {std::ofstream f(pending,std::ios::binary|std::ios::trunc);if(!f.write(reinterpret_cast<const char*>(content.data()),content.size()))return false;}
  std::filesystem::rename(pending,save);bus.save().clear_dirty();return true;
 }
 gbarecomp::debug::SnapshotContext snapshot() {
  gbarecomp::debug::SnapshotContext context;
  context.bus=&bus;context.ppu=&ppu;context.rom_sha1=rom_sha1;
  context.taken=&calls;context.cycles_elapsed=&cycles;context.vblank_count=&frames;return context;
 }
};
Machine* active=nullptr;
std::unordered_set<Machine*> machines;
Machine& machine(void* handle) {
 auto* m=static_cast<Machine*>(handle);
 if(!m||!machines.count(m))throw std::runtime_error("No active Pinball machine");
 return *m;
}
void capture(Machine& m) {
 gbarecomp::runtime_capture_arm_context(m.execution);
 gbarecomp::runtime_capture_timing_context(m.timing);
 m.cycles=m.timing.cycles;m.frames=m.timing.vblank_starts;
 gbarecomp::runtime_set_resumable_context(nullptr);
}
void bind(Machine& m) {
 if(active!=&m) {
  gbarecomp::runtime_restore_arm_context(m.execution);
  gbarecomp::runtime_restore_timing_context(m.timing);
  gbarecomp::set_active_bus(&m.bus);gbarecomp::set_active_ppu(&m.ppu);
  active=&m;
 }
 // Independent score games exchange contexts only after complete dispatches.
 // Do not enable the cycle-sliced link-cable scheduler here: it intentionally
 // rejects interpreter fallback, which this integration reports explicitly.
}
}
extern "C" {
// The caller is the single game worker. Foreground animation is latency
// sensitive; paused/background work must not retain that scheduling class.
// A negative value only queries the current class for qualification.
int ascendant_pinball_priority(int foreground) {
#ifdef __APPLE__
 if(foreground>=0&&pthread_set_qos_class_self_np(foreground?QOS_CLASS_USER_INTERACTIVE:QOS_CLASS_UTILITY,0)!=0)return 0;
 qos_class_t current=QOS_CLASS_UNSPECIFIED;
 if(pthread_get_qos_class_np(pthread_self(),&current,nullptr)!=0)return 0;
 return static_cast<int>(current);
#else
 (void)foreground;return 0;
#endif
}
const char* ascendant_pinball_error(){return error.c_str();}
const char* ascendant_pinball_coverage(){std::lock_guard<std::mutex> lock(ownership);static std::string report;report=gbarecomp::self_heal_misses_json();return report.c_str();}
void* ascendant_pinball_open(const char* rom,const char* bios,const char* save) {
 std::lock_guard<std::mutex> lock(ownership);
 if(machines.size()>=2){error="Both Pinball seats are already active";return nullptr;}
 try {
  auto m=std::make_unique<Machine>();m->rom=bytes(rom);
  if(m->rom.size()!=rom_size||gba::sha1(m->rom.data(),m->rom.size()).hex()!=rom_sha1)throw std::runtime_error("The matching verified Pinball cartridge revision is required");
  if(!m->bios.load_from_file(bios,"",&error))return nullptr;
  m->bus.set_bios(&m->bios);m->bus.set_rom(m->rom.data(),m->rom.size());
  m->bus.io().set_ppu(&m->ppu);m->bus.io().set_bus(&m->bus);m->bus.save().configure_sram(32768);
  if(save&&*save) {
   m->save=save;
   if(std::filesystem::exists(save)) {
    const auto saved=bytes(save);
    if(saved.size()!=32768||!m->bus.save().load_sram_bytes(saved.data(),saved.size()))throw std::runtime_error("Existing SRAM must be exactly 32768 bytes");
   }
  }
  gbarecomp::runtime_restore_arm_context(m->execution);
  gbarecomp::runtime_restore_timing_context(m->timing);
  gbarecomp::set_active_bus(&m->bus);gbarecomp::set_active_ppu(&m->ppu);
  runtime_init(&m->bus);
  m->ppu.set_presentation_observer(&m->table_view);
  gba::bios_hle_set_mode(gba::BiosHleMode::Off);gba::bios_hle_boot_skip(0x08000000);
  if(machines.empty()){gbarecomp::self_heal_reset();gbarecomp::self_heal_set_program_identity("Pokemon Pinball R/S",cartridge_code,rom_sha1);}
  capture(*m);m->picture();active=m.release();machines.insert(active);error.clear();return active;
 }catch(const std::exception& ex){error=ex.what();active=nullptr;gbarecomp::set_active_bus(nullptr);gbarecomp::set_active_ppu(nullptr);return nullptr;}
}
int ascendant_pinball_step_present(void* handle,uint16_t buttons,int present) {
 std::lock_guard<std::mutex> lock(ownership);
 Machine* current=nullptr;
 try {
  auto& m=machine(handle);current=&m;bind(m);m.buttons=buttons&1023;m.bus.io().set_keyinput(1023^m.buttons);
  using Clock=std::chrono::steady_clock;
  const auto start=m.diagnostics?Clock::now():Clock::time_point{};
  const double cpu=m.diagnostics?thread_seconds():0;
  const uint64_t before=g_runtime_vblank_starts;
  const uint64_t interp=gbarecomp::self_heal_interpreted_insns();
  uint64_t dispatches=0;
  while(g_runtime_vblank_starts==before) {
   if(++dispatches>2000000)throw std::runtime_error("The cartridge did not reach the next frame boundary");
   try {
    if(m.bus.io().halted())runtime_tick(64);else runtime_dispatch(g_cpu.R[15]);
   }catch(const gbarecomp::RuntimeDispatchYield&){}
  }
  m.interpreted+=gbarecomp::self_heal_interpreted_insns()-interp;
  m.calls+=dispatches;capture(m);
  const auto simulated=m.diagnostics?Clock::now():Clock::time_point{};
  if(present)m.picture();
  m.sample_count=m.bus.audio().drain_sample_block(m.samples.data(),m.samples.size(),m.sample_rate);
  if(m.diagnostics){const auto end=Clock::now();m.timings={std::chrono::duration<double>(simulated-start).count(),std::chrono::duration<double>(end-simulated).count(),thread_seconds()-cpu,double(gbarecomp::self_heal_interpreted_insns()-interp)};}
  return 1;
 }catch(const std::exception& ex){if(current)capture(*current);error=ex.what();return 0;}
}
int ascendant_pinball_step(void* handle,uint16_t buttons) {
 return ascendant_pinball_step_present(handle,buttons,1);
}
const uint8_t* ascendant_pinball_picture(void* handle,uint32_t* width,uint32_t* height) {
 std::lock_guard<std::mutex> lock(ownership);
 auto* m=static_cast<Machine*>(handle);if(!machines.count(m)||!width||!height)return nullptr;
 try {if(m->picture_frame!=m->frames)m->picture();}
 catch(const std::exception& ex){error=ex.what();return nullptr;}
 *width=m->width;*height=m->height;return m->rgba.data();
}
int ascendant_pinball_view(void* handle,int full_table) {
 std::lock_guard<std::mutex> lock(ownership);
 auto* m=static_cast<Machine*>(handle);if(!machines.count(m))return 0;
 try{m->full_table=full_table!=0;m->picture();return 1;}
 catch(const std::exception& ex){error=ex.what();return 0;}
}
const int16_t* ascendant_pinball_audio(void* handle,size_t* count,uint32_t* rate) {
 std::lock_guard<std::mutex> lock(ownership);
 auto* m=static_cast<Machine*>(handle);if(!machines.count(m)||!count||!rate)return nullptr;
 *count=m->sample_count;*rate=m->sample_rate;return m->samples.data();
}
int ascendant_pinball_state(void* handle,const char* path,int load) {
 std::lock_guard<std::mutex> lock(ownership);
 auto* m=static_cast<Machine*>(handle);if(!machines.count(m)||!path)return 0;
 try {
  bind(*m);if(!load)m->picture();auto context=m->snapshot();bool ok=false;
  if(load) {
   const auto content=bytes(path);
   if(content.size()<64||std::memcmp(content.data(),"APRSTATE",8))throw std::runtime_error("Unsupported Pinball quick state");
   auto value=[&](size_t at,unsigned count){uint64_t v=0;for(unsigned i=0;i<count;i++)v|=uint64_t(content[at+i])<<(i*8);return v;};
   const auto flags=value(52,8),payload_size=value(60,4);
   const size_t host_bytes=flags==1?PinballTableView::hud_bytes:0;
   if(value(8,4)!=1||flags>1||content.size()!=64+host_bytes+payload_size)throw std::runtime_error("Invalid Pinball quick state length/version");
   gbarecomp::RuntimeTimingContext timing;
   timing.cycles=value(12,8);timing.vblank_starts=value(20,8);timing.yielded_vblank=value(28,8);
   timing.pending_cycles=value(36,8);timing.event_budget=static_cast<int64_t>(value(44,8));

   ok=gbarecomp::debug::load_state_bytes(content.data()+64+host_bytes,payload_size,context,&error);
   if(ok){gbarecomp::runtime_restore_timing_context(timing);m->bus.io().set_keyinput(1023^m->buttons);m->bus.audio().discard_playback();m->table_view.reset_layout();m->table_view.restored();if(host_bytes)m->table_view.load_hud(content.data()+64);m->picture();}
  }else {
   std::vector<uint8_t> payload;
   ok=gbarecomp::debug::save_state_bytes(&payload,context,&error);
   if(ok) {
    gbarecomp::RuntimeTimingContext t;gbarecomp::runtime_capture_timing_context(t);
    std::vector<uint8_t> content{'A','P','R','S','T','A','T','E'};
    auto append=[&](uint64_t v,unsigned count){for(unsigned i=0;i<count;i++)content.push_back(v>>(i*8));};
    append(1,4);append(t.cycles,8);append(t.vblank_starts,8);append(t.yielded_vblank,8);
    append(t.pending_cycles,8);append(static_cast<uint64_t>(t.event_budget),8);append(1,8);append(payload.size(),4);
    const auto hud=m->table_view.save_hud();content.insert(content.end(),hud.begin(),hud.end());
    content.insert(content.end(),payload.begin(),payload.end());
    const std::string pending=std::string(path)+".pending";
    {std::ofstream file(pending,std::ios::binary|std::ios::trunc);if(!file.write(reinterpret_cast<const char*>(content.data()),content.size()))throw std::runtime_error("Quick state could not be written");}
    std::filesystem::rename(pending,path);
   }
  }
  capture(*m);return ok;
 }catch(const std::exception& ex){capture(*m);error=ex.what();return 0;}
}
uint64_t ascendant_pinball_frame(void* handle){std::lock_guard<std::mutex> lock(ownership);auto* m=static_cast<Machine*>(handle);return machines.count(m)?m->frames:0;}
uint64_t ascendant_pinball_interpreted(void* handle){std::lock_guard<std::mutex> lock(ownership);auto* m=static_cast<Machine*>(handle);return machines.count(m)?m->interpreted:0;}
int ascendant_pinball_table_stats(void* handle,uint32_t* reused,uint32_t* rendered) {
 std::lock_guard<std::mutex> lock(ownership);auto* m=static_cast<Machine*>(handle);
 if(!machines.count(m)||!reused||!rendered)return 0;
 *reused=m->table_view.reused_rows;*rendered=m->table_view.rendered_rows;return 1;
}
int ascendant_pinball_diagnostics(void* handle,double* values) {
 std::lock_guard<std::mutex> lock(ownership);auto* m=static_cast<Machine*>(handle);
 if(!machines.count(m))return 0;
 m->diagnostics=true;if(values)std::copy(m->timings.begin(),m->timings.end(),values);return 1;
}
const char* ascendant_pinball_checkpoint(void* handle) {
 std::lock_guard<std::mutex> lock(ownership);
 auto* m=static_cast<Machine*>(handle);if(!machines.count(m))return nullptr;
 // Guest RAM only; no ROM, saved user data or host pointers go over the wire.
 // The duel worker opens an empty, nonpersistent SRAM before booting here.
 std::vector<uint8_t> ram;ram.reserve(0x48000);
 for(uint32_t a=0x02000000;a<0x02040000;a++)ram.push_back(m->bus.read8(a));
 for(uint32_t a=0x03000000;a<0x03008000;a++)ram.push_back(m->bus.read8(a));
 m->checkpoint=gba::sha1(ram.data(),ram.size()).hex();return m->checkpoint.c_str();
}
uint32_t ascendant_pinball_read(void* handle,uint32_t address,uint32_t width) {
 std::lock_guard<std::mutex> lock(ownership);
 auto* m=static_cast<Machine*>(handle);if(!machines.count(m))return 0;
 bind(*m);auto value=width==1?m->bus.read8(address):width==2?m->bus.read16(address):m->bus.read32(address);capture(*m);return value;
}
int ascendant_pinball_close(void* handle) {
 std::lock_guard<std::mutex> lock(ownership);
 auto* m=static_cast<Machine*>(handle);if(!machines.count(m))return 0;
 bool ok=false;
 try{ok=m->flush();if(!ok)error="The SRAM save could not be written";}catch(const std::exception& ex){error=ex.what();}
 if(m==active){gbarecomp::runtime_set_resumable_context(nullptr);gbarecomp::set_active_bus(nullptr);gbarecomp::set_active_ppu(nullptr);active=nullptr;}
 machines.erase(m);delete m;return ok;
}
}
