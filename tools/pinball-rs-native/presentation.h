// Read-only host presentation by Roxas2712. Guest timing/state stay canonical.
#pragma once
#include "gba_bus.h"
#include "gba_ppu.h"
#include <array>
#include <memory>
#include <vector>
class PinballTableView {
public:
 bool render(gba::GbaBus&,const gba::GbaPpu&,const uint8_t* native_rgb,
             std::vector<uint8_t>& rgba,uint32_t& width,uint32_t& height);
private:
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
