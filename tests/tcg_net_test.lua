-- Partial writes, delayed frames and malformed peers; no ROM/save input.
local N=require('src.tcg.Net');local Json=require('src.link.Json')
local clock=0;local listener;local pending
local function endpoint()
 local p={bytes='',closed=false}
 function p:settimeout()end;function p:setoption()end
 function p:getpeername()if self.other then return '127.0.0.1'end end
 function p:send(s)
  local n=math.min(#s,333);self.other.bytes=self.other.bytes..s:sub(1,n)
  if n==#s then return n end;return nil,'timeout',n
 end
 function p:receive(n)local s=self.bytes:sub(1,577);self.bytes=self.bytes:sub(#s+1);return nil,'timeout',s end
 function p:close()self.closed=true end
 function p:connect()
  local other=endpoint();self.other=other;other.other=self;pending=other;return nil,'timeout'
 end
 return p
end
local socket={gettime=function()return clock end,tcp=endpoint,bind=function()
 listener={accept=function()local p=pending;pending=nil;return p end,settimeout=function()end,close=function()end};return listener
end}
local ram0=string.rep('\0',32768);local ram1=string.rep('\255',32768)
local host=N.new('host',nil,8766,'same',ram0,{socket=socket})
local join=N.new('join','127.0.0.1',8766,'same',ram1,{socket=socket})
for i=1,300 do host:update();join:update();clock=clock+.001 end
assert(host.remote==ram1 and join.remote==ram0,'Battery handshake must preserve every byte')
local hash=string.rep('a',64);local completed={0,0}
for t=1,3000 do
 clock=clock+.001
 for i,peer in ipairs{host,join}do
  peer:update();assert(not peer.error,peer.error)
  if completed[i]<120 then
   local d,b,c,e=peer:inputs(i==1 and 254 or 253,i==1 and 251 or 247,hash)
   if d then assert(completed[i]<6 and d==255 and b==255 and c==255 and e==255 or completed[i]>=6 and d==254 and b==251 and c==253 and e==247,'Both hosts need canonical seat order');completed[i]=completed[i]+1 end
  end
 end
end
assert(completed[1]==120 and completed[2]==120,'Partial writes must finish every frame')
assert(not pcall(host.accept,host,{type='input',frame=999,d=255,b=255,digest=hash}),'Reject sequence jumps')
assert(not pcall(host.accept,host,{type='input',frame=120,d=999,b=255,digest=hash}),'Reject invalid inputs')
assert(not pcall(host.accept,host,{type='hello',protocol=1,identity='same',seat=1,ram=N.hex(ram1)}),'Reject duplicate hello')
local probe=setmetatable({seat=0,identity='a',frame=0,incoming={},localFrames={},hashes={},checks={},tx=''},N)
assert(not pcall(probe.accept,probe,{type='hello',protocol=1,identity='b',seat=1,ram=N.hex(ram1)}),'Reject mixed builds')
probe.remote=ram1;probe:accept({type='input',frame=6,d=255,b=255,check=0,digest=string.rep('b',64)})
assert(not pcall(probe.inputs,probe,255,255,hash),'Desync must stop before advancing')
clock=clock+61;host:update();assert(host.error and host.state=='closed','Timeout must close both sockets')
join:close();assert(not host.peer and not join.peer)
assert(N.unhex('00')==nil and N.unhex(string.rep('gg',32768))==nil)
print('TCG network: 120 synchronized frames; partial IO, save handshake, build/sequence/desync rejection, timeout: PASS')
