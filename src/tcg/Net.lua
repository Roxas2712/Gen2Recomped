-- Bounded nonblocking input lockstep for two original cartridges. By Roxas2712.
local Json=require('src.link.Json')
local N={};N.__index=N
local LIMIT=70000
local DELAY=6
local function hex(s)return(s:gsub('.',function(c)return string.format('%02x',c:byte())end))end
local function unhex(s)
 if type(s)~='string'or #s~=65536 or s:find('[^0-9a-f]')then return end
 return(s:gsub('..',function(c)return string.char(tonumber(c,16))end))
end
local function digest(s)return type(s)=='string'and #s==64 and not s:find('[^0-9a-f]')end
function N.new(mode,address,port,identity,ram,options)
 options=options or{};local socket=options.socket or require('socket')
 assert(mode=='host'or mode=='join','Invalid network mode')
 port=tonumber(port);assert(port and port%1==0 and port>=1 and port<=65535,'Invalid TCP port')
 assert(type(ram)=='string'and #ram==32768,'Invalid TCG save')
 local self=setmetatable({mode=mode,seat=mode=='host'and 0 or 1,identity=identity,ram=ram,socket=socket,rx='',tx='',frame=0,incoming={},localFrames={},hashes={},checks={},clock=socket.gettime,last=socket.gettime(),state='connecting'},N)
 if mode=='host'then
  self.listener=assert(socket.bind('*',port,1));self.listener:settimeout(0)
 else
  assert(type(address)=='string'and #address>0 and #address<=253 and not address:find('[%c%s]'),'Invalid peer address')
  self.peer=assert(socket.tcp());self.peer:settimeout(0)
  local ok,why=self.peer:connect(address,port)
  assert(ok or why=='timeout'or why=='Operation already in progress',why)
 end
 return self
end
function N:send(value)
 local data=Json.encode(value)..'\n';assert(#self.tx+#data<=LIMIT,'TCG send queue exceeded');self.tx=self.tx..data
end
function N:hello()
 if self.sentHello then return end;self.sentHello=true
 self:send({type='hello',protocol=1,identity=self.identity,seat=self.seat,ram=hex(self.ram)})
end
function N:accept(row)
 assert(type(row)=='table','Invalid TCG packet')
 if row.type=='hello'then
  assert(not self.remote and row.protocol==1 and row.identity==self.identity and row.seat==1-self.seat,'TCG build or protocol differs')
  self.remote=assert(unhex(row.ram),'Invalid peer battery data');self.state='ready';return
 end
 assert(self.remote and row.type=='input'and type(row.frame)=='number'and row.frame%1==0 and row.frame>=self.frame and row.frame<=self.frame+2*DELAY+1 and not self.incoming[row.frame],'Unexpected TCG input frame')
 assert(type(row.d)=='number'and row.d%1==0 and row.d>=240 and row.d<=255 and type(row.b)=='number'and row.b%1==0 and row.b>=240 and row.b<=255 and digest(row.digest),'Invalid TCG input')
 assert(type(row.check)=='number'and row.check==(row.frame<DELAY and -1 or row.frame-DELAY),'Invalid TCG checkpoint')
 if row.check>=0 then self.checks[row.check]=row.digest end
 self.incoming[row.frame]=row
end
function N:update()
 if self.error then return end
 local ok,why=pcall(function()
  if self.listener and not self.peer then self.peer=self.listener:accept();if self.peer then self.peer:settimeout(0);self.peer:setoption('tcp-nodelay',true);self.listener:close();self.listener=nil end end
  if self.peer then
   if not self.sentHello then
    local ip=self.peer:getpeername()
    if ip then self.peer:setoption('tcp-nodelay',true);self:hello()end
   end
   if self.sentHello then
    if #self.tx>0 then
     local sent,err,partial=self.peer:send(self.tx);local n=sent or partial or 0;self.tx=self.tx:sub(n+1)
     assert(sent or err=='timeout',err)
    end
    local data,err,partial=self.peer:receive(8192);local bytes=data or partial or''
    if #bytes>0 then self.last=self.clock();self.rx=self.rx..bytes;assert(#self.rx<=LIMIT,'TCG receive queue exceeded')end
    while true do
     local pos=self.rx:find('\n',1,true);if not pos then break end
     local line=self.rx:sub(1,pos-1);self.rx=self.rx:sub(pos+1);self:accept(Json.decode(line))
    end
    assert(data or err=='timeout',err)
   end
  end
  assert(self.clock()-self.last<60,'TCG peer timeout')
 end)
 if not ok then self.error=tostring(why);self:close()end
end
function N:inputs(d,b,hash)
 if not self.remote or self.error then return end
 self.hashes[self.frame]=hash
 for frame,remote in pairs(self.checks)do
  if self.hashes[frame]then
   assert(remote==self.hashes[frame],'TCG synchronization mismatch; session stopped')
   self.checks[frame]=nil
  end
 end
 if not self.bootstrapped then
  self.bootstrapped=true
  for f=0,DELAY-1 do
   local row={type='input',frame=f,d=255,b=255,check=-1,digest=string.rep('0',64)}
   self.localFrames[f]=row;self:send(row)
  end
 end
 local future=self.frame+DELAY
 if not self.localFrames[future]then
  local row={type='input',frame=future,d=d,b=b,check=self.frame,digest=hash}
  self.localFrames[future]=row;self:send(row)
 end
 local incoming=self.incoming[self.frame];if not incoming then return end
 local a,c=self.localFrames[self.frame],incoming
 if self.seat==1 then a,c=c,a end
 self.localFrames[self.frame]=nil;self.incoming[self.frame]=nil
 self.hashes[self.frame-DELAY-2]=nil;self.frame=self.frame+1
 return a.d,a.b,c.d,c.b
end
function N:close()
 if self.peer then self.peer:close();self.peer=nil end
 if self.listener then self.listener:close();self.listener=nil end
 self.state='closed'
end
N.hex=hex;N.unhex=unhex
return N
