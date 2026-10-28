-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Reliable application sequence spans WebRTC and WSS, so failover cannot
-- apply a trade/action twice. ModCompass keeps the independent durable journal.
local N={};N.__index=N
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local Json=require('src.link.Json')
local Native=require('src.link.NativePeer')
local retiring={}
local function now()return love.timer.getTime()end
local function integer(n)return type(n)=='number'and n>=0 and n==math.floor(n)and n<=40000 end
function N.available()return Native.available()end
function N.new(ticket,journal,options)
 if not Native.available()then return journal end
 options=options or{}
 if journal then journal.journalOnly=true end
 return setmetatable({ticket=ticket,journal=journal,options=options,account=Auth.accountId(),mode='peer-v1',path='connecting',
  inbox={},outbox={},buffer={},history={},shadow={},sequence=journal and journal.sequence or 0,received=journal and journal.received or 0,accepted=journal and journal.accepted or 0,liveAck=journal and journal.accepted or 0,nextTicket=0,nextSend=0,deadline=now()+12,lastPeer=now()},N)
end
function N:fail(why)
 self.error=why;self.transferred=tostring(why):find('transferred to another device',1,true)~=nil;self.closed=true
 if self.job then self.job:cancel();self.job=nil end
 if self.native then self.native:close();self.native=nil end
 if self.journal then self.journal:close()end
end
function N:send(message)
 if self.closed or self.closing then return end
 local body=Json.encode(message)
 if #body>32768 or #self.outbox>=128 then return self:fail('The direct message queue exceeded its limit.')end
 if self.journal then
  -- Arena reconstruction can install a persisted cursor before first send.
  if self.journal.sequence<self.sequence then self.journal.sequence=self.sequence;self.journal.accepted=self.accepted;self.journal.received=self.received end
  self.journal:send(message);self.sequence=self.journal.sequence
 else self.sequence=self.sequence+1 end
 self.outbox[#self.outbox+1]={sequence=self.sequence,body=body}
 self.nextSend=0
end
function N:emit(frame,direct)
 return self.native and self.native:send(Json.encode(frame),direct)
end
function N:frame(frame)
 if type(frame)~='table'then return self:fail('Invalid direct message.')end
 if frame.t=='packet'then
  if not integer(frame.sequence)or frame.sequence<1 or type(frame.body)~='string'or #frame.body>32768 then return self:fail('Invalid direct message sequence.')end
  if frame.sequence>self.received+128 then return self:fail('The direct receive window exceeded its limit.')end
  if self.history[frame.sequence]and self.history[frame.sequence]~=frame.body then return self:fail('A direct message changed its sequence data.')end
  if frame.sequence>self.received then
   local old=self.buffer[frame.sequence];if old and old~=frame.body then return self:fail('A direct message changed its sequence data.')end
   self.buffer[frame.sequence]=frame.body
  end
  while self.buffer[self.received+1]do
   local body=self.buffer[self.received+1];self.buffer[self.received+1]=nil
   local msg=Json.decode(body);if type(msg)~='table'or type(msg.type)~='string'or #self.inbox>=128 then return self:fail('Invalid direct game message.')end
   self.inbox[#self.inbox+1]=msg;self.received=self.received+1
   self.history[self.received]=body;self.history[self.received-128]=nil;self.shadow[self.received]=nil
  end
  if self.journal then self.journal.nextPoll=0 end
  self:emit({t='ack',after=self.received},self.direct)
 elseif frame.t=='ack'then
  if not integer(frame.after)or frame.after>self.sequence then return self:fail('Invalid direct acknowledgement.')end
  self.liveAck=math.max(self.liveAck,frame.after)
  while self.outbox[1]and self.outbox[1].sequence<=self.liveAck do table.remove(self.outbox,1)end
 elseif frame.t=='bye'then self.peerClosed=true
 end
end
function N:event(e)
 if e.kind==1 then self.ws=true
 elseif e.kind==2 then
  local f=Json.decode(e.a);if type(f)~='table'then return self:fail('Invalid relay message.')end
  if f.t=='ready'then
   local changed=self.peerConnection and self.peerConnection~=f.peer
   self.paired=true;self.lastPeer=now();self.peerConnection=f.peer
   if not self.options.forceRelay then
    if changed then self.direct=false;self.native:restart(self.doc.role=='left',self.doc.stun)
    elseif not self.rtcStarted then self.rtcStarted=true;self.native:start(self.doc.role=='left',self.doc.stun)end
   end
   self.path=self.direct and'p2p'or'relay';self.nextSend=0
   self:emit({t='ack',after=self.received},false)
  elseif f.t=='waiting'then self.paired=false;self.direct=false;self.path='waiting';self.waitUntil=now()+90
  elseif f.t=='signal'then
   if self.native and self.rtcStarted then self.native:signal(f.kind,f.a,f.b)end
  else self:frame(f)end
 elseif e.kind==4 or e.kind==5 then self:emit({t='signal',kind=e.kind,a=e.a,b=e.b},false)
 elseif e.kind==6 then self.direct=true;self.path='p2p';self.nextSend=0
 elseif e.kind==7 then local f=Json.decode(e.a);self:frame(f)
 elseif e.kind==8 then self.direct=false;if self.paired then self.path='relay';self.nextSend=0 end
 elseif e.kind==3 or e.kind==9 then
  if self.native then self.native:close();self.native=nil end
  self.ws=false;self.direct=false;self.paired=false;self.rtcStarted=nil;self.nextTicket=now()+1;self.path='reconnecting'
 end
end
function N:update()
 if self.closed then return end
 if not Auth.signedIn()or Auth.accountId()~=self.account then return self:fail('The account changed during the connection.')end
 if self.journal then
  local before=self.journal.received
  self.journal:update();self.accepted=self.journal.accepted
  if self.journal.error then return self:fail(self.journal.error)end
  for i,msg in ipairs(self.journal:poll())do if before+i>self.received then self.shadow[before+i]=msg end end
  if self.path=='https'then
   self.paired=true
   while self.outbox[1]and self.outbox[1].sequence<=self.accepted do table.remove(self.outbox,1)end
   return
  end
 end
 if self.job then
  local r=self.job:poll()
  if r then
   self.job=nil
   if r.kind=='done'and r.first and r.first.transport then
    self.doc=r.first.transport;self.authUntil=now()+(self.doc.expires_in or 75);self.nextTicket=now()+40
    if self.native then self:emit({t='renew',ticket=self.doc.ticket},false)
    else self.native,self.openError=Native.open(self.doc)end
   else
    local why=type(r.second)=='table'and r.second or{message=r.second or r.error}
    if why.status==503 and self.journal then self.path='https';self.journal.journalOnly=false;return end
    if why.status and why.status>=400 and why.status<500 and why.status~=429 then return self:fail(why.message or'The connection authorization ended.')end
    self.nextTicket=now()+2
   end
  end
 elseif now()>=self.nextTicket then
  self.job=Task.new(function()
   local d,why,status=self.ticket();if d then return d end;return nil,{message=why,status=status}
  end)
 end
 if self.native then for _=1,128 do local e=self.native:poll();if not e then break end;self:event(e);if self.closed or not self.native then break end end end
 if self.authUntil and now()>=self.authUntil then return self:fail('The connection authorization expired. Reconnect through ModCompass.')end
 if not self.paired and now()>self.deadline and not self.peerConnection then
  if self.journal then if self.native then self.native:close();self.native=nil end;self.path='https';self.journal.journalOnly=false;self.paired=true
  else return self:fail('The other player did not open the direct connection.')end
 end
 if self.waitUntil and not self.paired and now()>self.waitUntil then return self:fail('The other player did not reconnect. No result was invented.')end
 if self.paired and now()>=self.nextSend then
  self.nextSend=now()+.5
  for i=1,math.min(8,#self.outbox)do
   local row=self.outbox[i]
   if not self:emit({t='packet',sequence=row.sequence,body=row.body},self.direct)then self.direct=false;self.path='relay';break end
  end
 end
end
function N:poll()
 if self.path=='https'and self.journal then
  while self.shadow[self.received+1]do
   self.received=self.received+1;self.inbox[#self.inbox+1]=self.shadow[self.received];self.shadow[self.received]=nil
  end
 end
 local a=self.inbox;self.inbox={};return a
end
function N:checkpoint()
 return not self.journal or self.journal.accepted==self.sequence and self.journal.received>=self.received
end
function N:close()
 if self.closed or self.closing then return end
 if not self.options.ephemeral then self.closing=true;self.closeUntil=now()+15;retiring[#retiring+1]=self;return end
 self:finish()
end
function N:finish()
 self:emit({t='bye'},self.direct);self.closed=true;self.finished=true
 if self.job then self.job:cancel();self.job=nil end
 if self.native then self.native:close();self.native=nil end
 if self.journal then self.journal:close()end
end
function N.pump()
 for i=#retiring,1,-1 do
  local net=retiring[i];net:update()
  if net.closed or #net.outbox==0 and net:checkpoint()or now()>net.closeUntil then if not net.closed then net:finish()end;table.remove(retiring,i)end
 end
end
return N
