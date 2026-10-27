// Read-only host presentation by Roxas2712. Guest timing/state stay canonical.
#pragma once
#include "gba_bus.h"
#include "gba_ppu.h"
#include <array>
#include <memory>
#include <vector>
class PinballTableView {
public:
 PinballTableView();
 bool render(gba::GbaBus&,const gba::GbaPpu&,uint64_t native_frame,
             std::vector<uint8_t>& rgba,uint32_t& width,uint32_t& height);
 unsigned reused_rows=0,rendered_rows=0;
 void reset_layout(){expanded_once_=false;stable_frames_=30;last_frame_=~uint64_t(0);bands_valid_.fill(false);}
private:
 // Exact dependency bytes, not hashes: unchanged bands retain identical pixels.
 bool cache_enabled_=true,global_valid_=false;
 uint8_t cached_field_=0;
 std::array<uint8_t,18> cached_io_{};
 std::array<bool,56> bands_valid_{};
 std::array<std::vector<uint8_t>,56> bands_;
 std::vector<uint8_t> dependency_;
 uint64_t last_frame_=~uint64_t(0);
 unsigned stable_frames_=30;
 bool expanded_once_=false;
 bool unchanged_band(unsigned band,unsigned first,unsigned end,uint16_t display,const uint8_t* palette);
 std::unique_ptr<gba::GbaPpu> surface_,hud_;
 std::array<uint8_t,96*1024> vram_{};
 std::array<uint8_t,1024> oam_{};
 std::array<uint8_t,0x60> io_{};
 std::array<int,128> x_{},y_{};
 std::array<bool,128> authored_{};
 static PinballTableView* rendering_;
 static int tilemap(int,int,int,uint16_t*);
 static int object_x(int,uint16_t,uint16_t,uint16_t,int*);
 static int object_y(int,uint16_t,uint16_t,uint16_t,int*);
};
