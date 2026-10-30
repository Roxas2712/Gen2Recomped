#pragma once
#include "gbrt.h"
#include <vector>
#include <array>
// Separate host presentation: scratch guest calls never touch the live guest.
class GBCTable {
    friend struct GBCTableRenderTest;
    struct Ball {
        bool valid=false,has_pose=false;
        int x=0,y=0;unsigned stage=0;
        std::array<uint8_t,16*16*4> pixels{};
    } ball;
    static bool ball_object(const uint8_t*);
    static void draw_half(GBContext*,std::vector<uint8_t>&,unsigned,bool,uint8_t* blockers=nullptr);
    static unsigned draw_ball(const Ball&,std::vector<uint8_t>&,const std::vector<uint8_t>&,unsigned);
    void sample_ball(GBContext*);
    void finish_ball(std::vector<uint8_t>&);
    unsigned window_top=272;
    std::vector<uint8_t> ball_blockers;
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
    unsigned ball_pixels=0,seam_ball_frames=0;
    int ball_x=0,ball_y=0;bool ball_visible=false;
    void reset_layout(){last_board.clear();last_picture.clear();ball_blockers.clear();ball=Ball{};window_top=272;last_field=sampled_stage=~0u;stage_loading=false;}
};
