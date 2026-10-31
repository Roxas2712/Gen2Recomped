-- Integration by Roxas2712. The runtime stays in the fork's ignored data.
local ffi=require('ffi')
local declarations=[[
 typedef struct Ascendant3DS Ascendant3DS;
 typedef struct {double fps,p95_ms,target_fps;uint32_t status,samples;} AscendantAssessment;
 bool ascendant_3ds_assess(const double*,size_t,bool,bool,uint32_t,AscendantAssessment*);
 typedef struct {const unsigned char *data;uint32_t width,height;size_t bytes;} AscendantPicture;
 typedef struct {float x,y,width,height;uint32_t screen;} AscendantPlace;
 Ascendant3DS *ascendant_3ds_open(const char *json);
 const char *ascendant_3ds_error(void);
 int ascendant_3ds_step(Ascendant3DS*,uint32_t,float,float,int,int,bool);
 const char *ascendant_3ds_keyboard(Ascendant3DS*);
 bool ascendant_3ds_answer_keyboard(Ascendant3DS*,const char*,uint32_t);
 uint32_t ascendant_3ds_language_prompt(Ascendant3DS*);
 uint64_t ascendant_3ds_revision(Ascendant3DS*,uint32_t);
 bool ascendant_3ds_blank(Ascendant3DS*,uint32_t);
 bool ascendant_3ds_picture(Ascendant3DS*,uint32_t,AscendantPicture*);
 const int16_t *ascendant_3ds_audio(Ascendant3DS*,size_t*);
 const char *ascendant_3ds_status(Ascendant3DS*);
 void ascendant_3ds_slider(Ascendant3DS*,float);
 bool ascendant_3ds_state(Ascendant3DS*,const char*,bool);
 void ascendant_3ds_close(Ascendant3DS*);
 size_t ascendant_3ds_layout(uint32_t,uint32_t,uint32_t,uint32_t,bool,bool,AscendantPlace*,size_t);
]]
ffi.cdef(declarations)
local M={ffi=ffi}
function M.load(path)return require('src.core.NativeLibrary').load(path,declarations)end
return M
