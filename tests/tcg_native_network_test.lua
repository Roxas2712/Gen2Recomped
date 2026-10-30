-- Actual TCP inputs applied to independent native two-device sessions.
local ffi=require('ffi');local socket=require('socket');local N=require('src.tcg.Net')
ffi.cdef[[
void* tcg_gbc_open(const char*,int);void tcg_gbc_close(void*);
int tcg_gbc_step(void*,uint8_t,uint8_t,uint8_t,uint8_t);
int tcg_gbc_ram(void*,int,uint8_t*,size_t,int);void tcg_gbc_digest(void*,char*);
const char* tcg_gbc_error(void);
]]
local lib=ffi.load(assert(os.getenv('TCG_QA_LIBRARY')));local rom=assert(os.getenv('TCG_QA_ROM'))
local handles={};for i=1,2 do handles[i]=lib.tcg_gbc_open(rom,2);assert(handles[i]~=nil,ffi.string(lib.tcg_gbc_error()))end
local bind=assert(socket.bind('127.0.0.1',0));local _,port=bind:getsockname();bind:close()
local ram0=string.char(66)..string.rep('\0',32767);local ram1=string.char(99)..string.rep('\0',32767)
local peers={N.new('host',nil,port,'native-tcg',ram0),N.new('join','127.0.0.1',port,'native-tcg',ram1)}
local deadline=socket.gettime()+25;local frames={0,0};local hashes={{},{}};local started={};local buffer=ffi.new('uint8_t[32768]');local digest=ffi.new('char[65]')
while frames[1]<600 or frames[2]<600 do
 for i,peer in ipairs(peers)do
  peer:update();assert(not peer.error,peer.error)
  if peer.remote and frames[i]<600 then
   if not started[i]then
    local saves={};saves[peer.seat+1]=peer.ram;saves[2-peer.seat]=peer.remote
    for seat=0,1 do ffi.copy(buffer,saves[seat+1],32768);assert(lib.tcg_gbc_ram(handles[i],seat,buffer,32768,1)==1)end
    started[i]=true
   end
   lib.tcg_gbc_digest(handles[i],digest)
   local frame=frames[i];local buttons=(frame>=360 and frame<365)and 247 or 255
   local d0,b0,d1,b1=peer:inputs(255,buttons,ffi.string(digest))
   if d0 then
    assert(lib.tcg_gbc_step(handles[i],d0,b0,d1,b1)==1,ffi.string(lib.tcg_gbc_error()))
    frames[i]=frames[i]+1;lib.tcg_gbc_digest(handles[i],digest);hashes[i][frames[i]]=ffi.string(digest)
    if hashes[3-i][frames[i]]then assert(hashes[i][frames[i]]==hashes[3-i][frames[i]],'Native TCP clients diverged')end
   end
  end
 end
 assert(socket.gettime()<deadline,'Native TCP qualification timed out')
end
assert(hashes[1][600]==hashes[2][600])
for i,p in ipairs(peers)do p:close();lib.tcg_gbc_close(handles[i])end
print('TCG native TCP: 600 matching frames, full battery seat ordering and input delay: PASS')
