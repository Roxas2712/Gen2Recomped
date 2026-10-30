// Original 192x272 table from cartridge VRAM and stage draw routines.
// Host integration by Roxas2712. Addresses validated against pret/pokepinball.
#include "table.h"
#include "gb_snapshot.h"
#include "ppu.h"
#include <array>
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <cstdio>

namespace {
constexpr unsigned W=192,H=285;
thread_local GBContext* graphics_guest=nullptr;
uint8_t& ram(GBContext*c,unsigned a){return c->wram[0x1000+a-0xd000];}
// Call a cartridge graphics routine in a bounded, disposable context. The
// sentinel return is intercepted before fetch; interrupts cannot run here.
bool call(GBContext*c,unsigned bank,unsigned pc) {
    c->pc=pc;c->rom_bank=bank;c->hram[0x78]=bank;c->sp=0xdff0;
    c->ime=0;c->ime_pending=0;c->halted=0;c->stopped=0;c->stop_mode_active=0;
    c->frame_done=0;c->run_cycle_budget=0;
    gb_write16(c,c->sp,0xfffe);
    const uint32_t start=c->cycles;c->run_cycle_budget=2000000;c->run_cycle_budget_start=start;
    auto*previous=graphics_guest;graphics_guest=c;
    for(unsigned slice=0;slice<32&&c->pc!=0xfffe&&uint32_t(c->cycles-start)<2000000;slice++) {
        c->stopped=0;c->frame_done=0;gbrt_dispatch(c,c->pc);
        if(c->has_unimplemented_interpreter_opcode)break;
    }
    graphics_guest=previous;c->run_cycle_budget=0;
    return c->pc==0xfffe&&!c->has_unimplemented_interpreter_opcode;
}
void color(uint8_t*out,const uint8_t*pal,unsigned index) {
    unsigned v=pal[index*2]|unsigned(pal[index*2+1])<<8;
    out[0]=(v&31)*255/31;out[1]=((v>>5)&31)*255/31;out[2]=((v>>10)&31)*255/31;out[3]=255;
}
}
void GBCTable::draw_half(GBContext*c,std::vector<uint8_t>&out,unsigned first,bool canonical) {
    const auto*ppu=static_cast<GBPPU*>(c->ppu);
    std::array<uint8_t,W*136> ids{},priority{};
    const unsigned lcd=c->hram[0x1e],map=(lcd&8)?0x1c00:0x1800;
    for(unsigned y=0;y<136;y++)for(unsigned x=0;x<W;x++) {
        const unsigned cell=map+(y/8)*32+x/8;
        const unsigned attr=c->vram[0x2000+cell],tile=c->vram[cell];
        const int base=(lcd&16)?tile*16:0x1000+int(int8_t(tile))*16;
        const unsigned ty=(attr&64)?7-y%8:y%8,tx=(attr&32)?x%8:7-x%8;
        const unsigned off=((attr&8)?0x2000:0)+base+ty*2;
        const unsigned id=((c->vram[off]>>tx)&1)|(((c->vram[off+1]>>tx)&1)<<1);
        ids[y*W+x]=id;priority[y*W+x]=attr&128;
        color(&out[((first+y)*W+x)*4],ppu->bg_palette_ram,(attr&7)*4+id);
    }
    // Software OAM and hSCX/hSCY describe the same freshly drawn frame.
    // Hardware OAM can still belong to the preceding DMA/camera position.
    const uint8_t*oam=c->wram+0x1000;
    const int sx=canonical?int(int8_t(c->hram[0x21])):0;
    const int sy=canonical?int(int8_t(c->hram[0x20])):0;
    const unsigned sh=(lcd&4)?16:8;
    // Resolve one winning object by OAM order before testing BG priority,
    // matching the GBA compositor correction; hidden objects do not leak through.
    std::array<uint8_t,W*136> occupied{};
    for(int i=0;i<40;i++) {
        const auto*o=oam+i*4;
        int px=int(o[1])-8+sx,py=int(o[0])-16+sy;
        if(o[0]==0||o[0]>=160||o[1]==0||o[1]>=200)continue;
        const unsigned attr=o[3],tile=sh==16?(o[2]&254):o[2];
        for(unsigned yy=0;yy<sh;yy++)for(unsigned xx=0;xx<8;xx++) {
            int x=px+xx,y=py+yy;if(x<0||x>=int(W)||y<0||y>=136)continue;
            unsigned ty=(attr&64)?sh-1-yy:yy,tx=(attr&32)?xx:7-xx;
            unsigned off=((attr&8)?0x2000:0)+tile*16+ty*2;
            unsigned id=((c->vram[off]>>tx)&1)|(((c->vram[off+1]>>tx)&1)<<1);
            unsigned at=y*W+x;
            if(!id||occupied[at])continue;
            occupied[at]=1;
            if(ids[at]&&((attr&128)||priority[at]))continue;
            color(&out[((first+y)*W+x)*4],ppu->obj_palette_ram,(attr&7)*4+id);
        }
    }
}
// The runtime's documented game hook terminates a scratch-only graphics call
// before fetching its synthetic return PC. Canonical dispatch is untouched.
extern "C" int game_dispatch_override(GBContext*c,uint16_t pc) {
    if(c==graphics_guest&&pc==0xfffe){c->stopped=1;return 1;}return 0;
}
GBCTable::~GBCTable(){if(scratch)gb_context_destroy(scratch);}
void GBCTable::draw_hud(GBContext*live,std::vector<uint8_t>&out) {
    // Isolate the authored window layer. Copying framebuffer rows 131..143
    // also copied the board/flippers whenever the native window slid down.
    // The full-table HUD stays fixed; no camera pixels enter the black strip.
    const auto*ppu=static_cast<GBPPU*>(live->ppu);
    // The cartridge STAT routine toggles LCDC bit 4 for the text window.
    const unsigned hud_lcd=(live->hram[0x1e]^16)&live->hram[0x2f];
    const unsigned map=(hud_lcd&64)?0x1c00:0x1800;
    // Ball-bonus and Save/Cancel are authored multi-row window overlays.
    // Keep them at native pixel scale on the fixed board, never zoom the camera.
    const unsigned wy=live->hram[0x26];
    const unsigned rows=wy<134?std::min(144u,144-wy):8;
    const unsigned top=wy<134?H-rows:274;
    for(unsigned y=wy<134?top:272;y<H;y++)for(unsigned x=16;x<176;x++) {
        auto*dst=&out[(y*W+x)*4];dst[0]=dst[1]=dst[2]=0;dst[3]=255;
    }
    for(unsigned y=0;y<rows;y++)for(unsigned x=0;x<160;x++) {
        const unsigned cell=map+(y/8)*32+x/8,attr=live->vram[0x2000+cell],tile=live->vram[cell];
        const int base=(hud_lcd&16)?tile*16:0x1000+int(int8_t(tile))*16;
        const unsigned ty=(attr&64)?7-y%8:y%8,tx=(attr&32)?x%8:7-x%8;
        const unsigned off=((attr&8)?0x2000:0)+base+ty*2;
        const unsigned id=((live->vram[off]>>tx)&1)|(((live->vram[off+1]>>tx)&1)<<1);
        color(&out[((top+y)*W+16+x)*4],ppu->bg_palette_ram,(attr&7)*4+id);
    }
    for(unsigned i=0;i<W*H;i++)out[i*4+3]=255;
}
bool GBCTable::retain(GBContext*live,std::vector<uint8_t>&out,bool loading) {
    // A transition invalidates camera/VRAM pairing before the LCD turns off.
    // Never publish the original half-table as a fallback, even on the very
    // first loading frame. Preserve the entire completed picture during DMA.
    if(loading&&!last_picture.empty())out=last_picture;
    else {
        if(last_board.empty())out.assign(W*H*4,0);else out=last_board;
        if(!loading)draw_hud(live,out);
        for(unsigned i=0;i<W*H;i++)out[i*4+3]=255;
    }
    last_picture=out;return true;
}
bool GBCTable::compose(GBContext*live,std::vector<uint8_t>&out) {
    const unsigned stage=ram(live,0xd4ac);
    const bool standard=ram(live,0xd8f1)==4&&stage<=5&&!(stage&2);
    if(!standard){reset_layout();return false;}
    if(last_field!=(stage&4)){reset_layout();last_field=stage&4;}
    // FieldVerticalTransition changes wCurrentStage, zeros hBGP and waits a
    // VBlank BEFORE loading the other half's tiles. LCDC alone is too late:
    // the new stage id can still be paired with the old half's live VRAM.
    // CGB's initial fade can legitimately leave the DMG palette at zero.
    // Use it as a transition latch only after a complete stage was rendered.
    const bool changed=sampled_stage!=~0u&&sampled_stage!=stage&&!last_board.empty();
    sampled_stage=stage;
    if(changed)stage_loading=true;
    const bool loading=changed||(stage_loading&&!live->hram[0x23])||!(live->hram[0x1e]&128)||!(live->io[0x40]&128);
    if(!loading)stage_loading=false;
    if(loading){transition_holds++;return retain(live,out,true);}
    if(ram(live,0xd8f2)!=2)return retain(live,out,false);
    if(!scratch) {
        scratch=gb_context_create(&live->config);
        if(!scratch){failures++;failure_holds++;return retain(live,out,true);}
        scratch->hardware_mode_pref=GB_HARDWARE_MODE_CGB;scratch->mbc_type=live->mbc_type;
        if(!gb_context_load_rom(scratch,live->rom,live->rom_size)){failures++;failure_holds++;return retain(live,out,true);}
    }
    uint8_t*blob=nullptr;size_t size=0;
    if(!gb_snapshot_serialize(live,&blob,&size)){failures++;failure_holds++;return retain(live,out,true);}
    bool restored=gb_snapshot_deserialize(scratch,blob,size);std::free(blob);
    if(!restored){if(failures++==0)std::fprintf(stderr,"[GBC table] scratch snapshot rejected\n");failure_holds++;return retain(live,out,true);}
    const unsigned other=stage^1;
    ram(scratch,0xd4ac)=other;
    ram(scratch,0xd548)=0; // one ball only: the canonical live half owns it
    ram(scratch,0xd57d)=0; // the live half owns the authored timer overlay
    // A host snapshot may land during the cartridge's OAM DMA. Scratch
    // rendering has no bus arbitration with the live LCD; stale DMA must not
    // discard the synthetic call stack or graphics writes.
    scratch->dma.active=0;scratch->dma.pending=0;scratch->hdma.active=0;scratch->wram_bank=1;
    scratch->hram[0x20]=0;scratch->hram[0x21]=0;
    gb_write8(scratch,0xff40,scratch->io[0x40]&127);
    if(!call(scratch,3,0x66c2)||!call(scratch,0,0x0916)||!call(scratch,2,0x44b7)) {
        if(failures++==0)std::fprintf(stderr,"[GBC table] scratch graphics call failed at %02x:%04x sp=%04x\n",scratch->rom_bank,scratch->pc,scratch->sp);
        failure_holds++;return retain(live,out,true);
    }
    // LoadStageData writes the selected half's CGB palette directly to the
    // PPU. wPaletteData is a fade backup, not its current palette: copying it
    // here recolored Voltorb, Ditto, Bellsprout and the billboard incorrectly.
    out.assign(W*H*4,0);
    draw_half(scratch,out,(other&1)?136:0,false);
    draw_half(live,out,(stage&1)?136:0,true);
    last_board=out;draw_hud(live,out);last_picture=out;
    return true;
}
