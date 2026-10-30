-- NAS-only Linux POSIX adapter if the verifier image has no LuaSocket package.
-- Exercises the production TCP framing/channel with actual kernel sockets.
local ok,Socket=pcall(require,'socket');if ok then return Socket end
local ffi=require('ffi')
ffi.cdef[[
struct cable_addr { unsigned short family; unsigned short port; unsigned int address; unsigned char zero[8]; };
int socket(int,int,int); int connect(int,const void*,unsigned int); int close(int);
int fcntl(int,int,...); int inet_pton(int,const char*,void*); unsigned short htons(unsigned short);
long send(int,const void*,unsigned long,int); long recv(int,void*,unsigned long,int);
int getpeername(int,void*,unsigned int*); int usleep(unsigned int);
struct cable_time {long seconds;long nanoseconds;}; int clock_gettime(int,struct cable_time*);
]]
local C=ffi.C
local A={}
function A.gettime()local t=ffi.new('struct cable_time[1]');assert(C.clock_gettime(1,t)==0);return tonumber(t[0].seconds)+tonumber(t[0].nanoseconds)/1e9 end
function A.select(_,writers)return{},writers end
function A.sleep(seconds)C.usleep(seconds*1000000)end
function A.tcp()
 local fd=assert(C.socket(2,1,0));assert(fd>=0)
 local self={}
 function self:settimeout()assert(C.fcntl(fd,4,ffi.new('int',2048))==0)end
 function self:connect(host,port)
  local address=ffi.new('struct cable_addr[1]');address[0].family=2;address[0].port=C.htons(port)
  assert(C.inet_pton(2,host,ffi.cast('char*',address)+4)==1,'numeric loopback IPv4 required in NAS fixture')
  local result=C.connect(fd,address,16)
  if result==0 then return true end
  return nil,ffi.errno()==115 and'timeout'or'connect error'
 end
 function self:getpeername()local a=ffi.new('struct cable_addr[1]');local n=ffi.new('unsigned int[1]',16);if C.getpeername(fd,a,n)==0 then return '127.0.0.1',0 end end
 function self:send(bytes)local n=tonumber(C.send(fd,bytes,#bytes,16384));if n>=0 then return n end;return nil,ffi.errno()==11 and'timeout'or'send error',0 end
 function self:receive(size)local buffer=ffi.new('char[?]',size);local n=tonumber(C.recv(fd,buffer,size,0));if n>0 then return ffi.string(buffer,n)end;return nil,n==0 and'closed'or ffi.errno()==11 and'timeout'or'receive error',''end
 function self:close()if fd>=0 then C.close(fd);fd=-1 end end
 return self
end
return A
