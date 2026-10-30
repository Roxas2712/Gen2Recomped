-- Private native cartridge bridge. Contributions by Roxas2712.
local ffi=require('ffi')
ffi.cdef[[
const char* ascendant_pinball_error(void);
void* ascendant_pinball_open(const char*,const char*,const char*);
int ascendant_pinball_step(void*,uint16_t);
int ascendant_pinball_step_present(void*,uint16_t,int);
int ascendant_pinball_view(void*,int);
const uint8_t* ascendant_pinball_picture(void*,uint32_t*,uint32_t*);
const int16_t* ascendant_pinball_audio(void*,size_t*,uint32_t*);
int ascendant_pinball_state(void*,const char*,int);
uint64_t ascendant_pinball_frame(void*);
uint64_t ascendant_pinball_interpreted(void*);
int ascendant_pinball_table_stats(void*,uint32_t*,uint32_t*);
int ascendant_pinball_diagnostics(void*,double*);
int ascendant_pinball_priority(int);
int ascendant_pinball_rumble(void*);
const char* ascendant_pinball_checkpoint(void*);
uint32_t ascendant_pinball_read(void*,uint32_t,uint32_t);
int ascendant_pinball_close(void*);
]]
local M={ffi=ffi}
function M.load(path)return ffi.load(assert(path,'Pinball runtime has not been prepared.'))end
return M
