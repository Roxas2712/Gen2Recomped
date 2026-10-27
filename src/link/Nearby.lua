-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Explicitly enabled LAN discovery. Broadcasts contain no account tokens,
-- party data or saves. Both users consent before the normal link handshake.
local N={};N.__index=N
local Json=require('src.link.Json')
local Net=require('src.link.Net')
N.PORT=17779
local function clean(s)return tostring(s or ''):gsub('[%c]',''):sub(1,64)end
function N.new(game,mode,options)
 options=options or {}
 local socket=options.socket
 if not socket then local ok,s=pcall(require,'socket');if not ok then return nil,'Local network discovery is unavailable on this device.'end;socket=s end
 local udp,why=(socket.udp4 or socket.udp)();if not udp then return nil,tostring(why)end
 udp:settimeout(0);pcall(udp.setoption,udp,'reuseaddr',true);pcall(udp.setoption,udp,'reuseport',true)
 local ok,err=udp:setsockname('*',N.PORT);if not ok then udp:close();return nil,tostring(err)end
 udp:setoption('broadcast',true)
 local hello=require('src.link.Handshake').hello(game,mode)
 local clock=options.clock or function()return love.timer.getTime()end
 local self=setmetatable({udp=udp,clock=clock,makeNet=options.makeNet or Net.new,peers={},mode=mode,
  id=options.id or require('src.core.PlaythroughIdentity').newId(),
  edition=require('src.core.GameVersion').get(),fingerprint=hello.fingerprint,name=clean(game.save.player.name),nextSend=0},N)
 if not self:listen()then udp:close();return nil,self.error end
 return self
end
function N:listen()
 self.net=self.makeNet()
 if not self.net:host(0)then self.error=self.net.error;return false end
 self.port=self.net.port
 self.phase='listening';self.incoming=nil;self.target=nil;self.requestSent=nil;self.deadline=nil
 return true
end
function N:close()
 if self.udp then self.udp:close();self.udp=nil end
 if self.net then self.net:close();self.net=nil end
 self.closed=true
end
function N:reset()
 if self.net then self.net:close()end
 return self:listen()
end
function N:request(id)
 local p=self.peers[id]
 if self.phase~='listening' or not p or self.clock()-p.seen>5 then return nil,'This nearby player is no longer ready.'end
 self.net:close();self.net=self.makeNet()
 if not self.net:join(p.address..':'..p.port)then self.error=self.net.error;self:reset();return nil,self.error end
 self.target=p;self.phase='requesting';self.deadline=self.clock()+25
 return true
end
function N:respond(accept)
 if self.phase~='incoming' then return end
 if accept then
  self.net:send({type='near_accept',target=self.incoming.id,mode=self.mode})
  self.phase='accepted';self.isHost=true
 else self.net:send({type='near_decline'});self:reset()end
end
function N:take()
 if self.phase~='accepted' then return end
 local net=self.net;self.net=nil
 if self.udp then self.udp:close();self.udp=nil end
 self.closed=true
 return net,self.isHost,self.mode
end
function N:update()
 if self.closed then return end
 local now=self.clock()
 if self.phase=='listening' and now>=self.nextSend then
  self.nextSend=now+1
  local bytes,why=self.udp:sendto(Json.encode({protocol='retro-near-1',id=self.id,name=self.name,edition=self.edition,fingerprint=self.fingerprint,mode=self.mode,port=self.port}),'255.255.255.255',N.PORT)
  if not bytes then self.error=tostring(why)end
 end
 for _=1,32 do
  local bytes,address=self.udp:receivefrom();if not bytes then break end
  if #bytes<=1024 then
   local ok,p=pcall(Json.decode,bytes)
   if ok and type(p)=='table' and p.protocol=='retro-near-1' and type(p.id)=='string' and #p.id<=80 and p.id~=self.id and p.edition==self.edition and p.fingerprint==self.fingerprint and p.mode==self.mode and type(p.port)=='number' and p.port%1==0 and p.port>=1024 and p.port<=65535 then
    local count=0;for _ in pairs(self.peers)do count=count+1 end
    if count<32 or self.peers[p.id]then self.peers[p.id]={id=p.id,name=clean(p.name),address=address,port=p.port,seen=now}end
   end
  end
 end
 for id,p in pairs(self.peers)do if now-p.seen>5 then self.peers[id]=nil end end
 self.net:update()
 if self.net.closed or self.net.error or self.deadline and now>self.deadline then self.error='The nearby connection ended. Try again.';self:reset();return end
 if self.phase=='requesting' and self.net.paired and not self.requestSent then
  self.requestSent=true;self.net:send({type='near_request',target=self.target.id,id=self.id,name=self.name,mode=self.mode,edition=self.edition,fingerprint=self.fingerprint})
 end
 local keep={}
 for _,m in ipairs(self.net:poll())do
  if m.type=='near_request' and self.phase=='listening' and m.target==self.id and type(m.id)=='string' and m.mode==self.mode and m.edition==self.edition and m.fingerprint==self.fingerprint then
   self.incoming={id=m.id,name=clean(m.name)};self.phase='incoming';self.deadline=now+25
  elseif m.type=='near_accept' and self.phase=='requesting' and m.target==self.id and m.mode==self.mode then self.phase='accepted';self.isHost=false
  elseif m.type=='near_decline' then self.error='The nearby player declined.';self:reset();return
  else keep[#keep+1]=m end
 end
 for _,m in ipairs(keep)do self.net.inbox[#self.net.inbox+1]=m end
end
return N
