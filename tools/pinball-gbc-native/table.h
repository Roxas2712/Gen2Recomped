#pragma once
#include "gbrt.h"
#include <vector>
// Separate host presentation: scratch guest calls never touch the live guest.
class GBCTable {
    friend struct GBCTableRenderTest;
    static void draw_half(GBContext*,std::vector<uint8_t>&,unsigned,bool);
    static void draw_hud(GBContext*,std::vector<uint8_t>&);
    GBContext* scratch=nullptr;
    std::vector<uint8_t> last_board,last_picture;
    bool retain(GBContext*,std::vector<uint8_t>&,bool loading);
    unsigned last_field=~0u,sampled_stage=~0u;
    bool stage_loading=false;
public:
    ~GBCTable();
    bool compose(GBContext*,std::vector<uint8_t>&);
    unsigned failures=0,transition_holds=0,failure_holds=0;
    void reset_layout(){last_board.clear();last_picture.clear();last_field=sampled_stage=~0u;stage_loading=false;}
};
