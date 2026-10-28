-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The bridge queues native-thread callbacks; only this polling code enters Lua.
local N={};N.__index=N
local checked,ffi,lib,ca
local function load()
 if checked then return lib end;checked=true
 local ok;ok,ffi=pcall(require,'ffi');if not ok then return end
 ffi.cdef[[int rr_version(void);int rr_open(const char*,const char*,const char*);int rr_start(int,int,const char*);void rr_drop(int);int rr_signal(int,int,const char*,const char*);int rr_send(int,int,const char*,int);int rr_poll(int,int*,char*,int,char*,int);void rr_close(int);]]
 local base=love and love.filesystem and love.filesystem.getSourceBaseDirectory and love.filesystem.getSourceBaseDirectory()
 local source=love and love.filesystem and love.filesystem.getSource and love.filesystem.getSource()
 local parent=source and source:match('^(.*)[/\\][^/\\]+$')
 local osname=love and love.system and love.system.getOS and love.system.getOS()or''
 local name=osname=='Windows'and'retro_peer.dll'or osname=='OS X'and'libretro_peer.dylib'or'libretro_peer.so'
 local explicit=os.getenv('POKEPORT_PEER_LIBRARY');local selected
 for _,path in ipairs{explicit or false,not explicit and parent and(parent..'/peer-native/'..name)or false,not explicit and base and(base..'/peer-native/'..name)or false}do
  if path then
   ok,lib=pcall(ffi.load,path)
   if ok then local valid,version=pcall(function()return lib.rr_version()end);if valid and version==1 then selected=path;break end end
   lib=nil
  end
 end
 if not selected then return end
 local directory=selected:match('^(.*)[/\\][^/\\]+$')
 ca=os.getenv('POKEPORT_PEER_CA')or directory and(directory..'/ca.pem')
 return lib
end
function N.available()return load()~=nil end
function N.open(doc)
 if not load()then return nil,'The native direct-connection module is unavailable.'end
 if type(doc)~='table'or doc.schema~=1 or type(doc.url)~='string'or not doc.url:match('^wss://[%w%.:%-%[%]]+/v1/rooms/[a-z]+:[a-f0-9%-]+$')or type(doc.ticket)~='string'or #doc.ticket>4096 then return nil,'Invalid direct-connection ticket.'end
 local id=lib.rr_open(doc.url,doc.ticket,ca or'');if id<0 then return nil,'Could not open the secure relay.'end
 return setmetatable({id=id,a=ffi.new('char[131073]'),b=ffi.new('char[1025]'),kind=ffi.new('int[1]')},N)
end
function N:start(offer,stun)return lib.rr_start(self.id,offer and 1 or 0,stun or'')==0 end
function N:drop()lib.rr_drop(self.id)end
function N:restart(offer,stun)self:drop();return self:start(offer,stun)end
function N:signal(kind,a,b)return lib.rr_signal(self.id,kind,a,b)==0 end
function N:send(body,direct)return lib.rr_send(self.id,direct and 1 or 0,body,#body)==0 end
function N:poll()
 if not self.id then return end
 local status=lib.rr_poll(self.id,self.kind,self.a,131073,self.b,1025)
 if status==1 then return {kind=tonumber(self.kind[0]),a=ffi.string(self.a),b=ffi.string(self.b)}end
 if status<0 then return {kind=9,a='Invalid native receive queue.'}end
end
function N:close()if self.id then lib.rr_close(self.id);self.id=nil end end
return N
