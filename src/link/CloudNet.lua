-- Authenticated, ordered Arena transport over the account's HTTPS service.
-- Only battle protocol data crosses this boundary; ROMs and login tokens are
-- never put inside peer messages. Requests retry the same sequence and bytes.
local N={};N.__index=N
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local Json=require('src.link.Json')
local retiring={}
local BATCH_SIZE=8
local function now() return love.timer.getTime() end
function N.new(cup,match,battle,ticket,request,options)
 return setmetatable({cup=cup,match=match,battle=battle,ticket=ticket,account=Auth.accountId(),
  paired=true,mode='cloudArena',inbox={},outbox={},sequence=0,received=0,accepted=0,
  nextPoll=0,lastSuccess=now(),closed=false,request=request,drainPeer=options and options.drainPeer==true},N)
end
function N:send(message)
 if self.closed then return end
 local body=Json.encode(message)
 if #body>32768 or #self.outbox>=128 then self.error='Battle message queue exceeded its limit.';self.closed=true;return end
 self.sequence=self.sequence+1
 self.outbox[#self.outbox+1]={sequence=self.sequence,body=body}
end
function N:poll() local messages=self.inbox;self.inbox={};return messages end
function N:fail(why)
 self.transferred=type(why)=='string' and why:find('transferred to another device',1,true)~=nil
 self.error=why;self.closed=true;self.finished=true
 if self.job then self.job:cancel();self.job=nil end
end
function N:exchange()
 if self.finished then return end
 if not Auth.signedIn() or Auth.accountId()~=self.account then return self:fail('The account changed during the battle.') end
 if self.job then
  local response=self.job:poll()
  if not response then return end
  self.job=nil
  if response.kind~='done' or not response.first then
   local failure=response.second
   if type(failure)=='table' and type(failure.status)=='number' and failure.status>=400 and failure.status<500 and failure.status~=408 and failure.status~=429 then
    return self:fail(failure.message or 'This Arena connection is no longer active. Reopen the lobby.')
   end
   self.nextPoll=now()+1
   if now()-self.lastSuccess>45 then self:fail('The Arena connection stopped answering. No result was invented.') end
   return
  end
  local doc=response.first
  if doc.battle~=self.battle or type(doc.sent)~='number' or doc.sent<self.accepted or doc.sent>self.sequence then return self:fail('Invalid Arena message acknowledgement.') end
  if self.hasPeer and doc.peer_online==false and not doc.peer_closed then return self:fail('Your rival disconnected from the Arena.') end
  self.accepted=doc.sent;self.lastSuccess=now();self.peerClosed=doc.peer_closed
  while self.outbox[1] and self.outbox[1].sequence<=doc.sent do table.remove(self.outbox,1) end
  local messages=doc.messages or {}
  for _,row in ipairs(messages) do
   if row.sequence~=self.received+1 or type(row.body)~='string' or #row.body>32768 then return self:fail('The Arena message stream is out of order.') end
   local message=Json.decode(row.body)
   if type(message)~='table' or type(message.type)~='string' then return self:fail('Invalid Arena battle message.') end
   if #self.inbox>=128 then return self:fail('Too many unread Arena messages.') end
   self.inbox[#self.inbox+1]=message;self.received=row.sequence;self.hasPeer=true
  end
  -- A full page can still have a tail. Keep fetching until a short page
  -- proves that the closed peer stream is drained; then flush our final ACK.
  if self.peerClosed and #messages<BATCH_SIZE then self:close() end
  if self.sentClose and #self.outbox==0 and (not self.drainPeer or
   self.peerClosed and #messages<BATCH_SIZE and self.closeAfter==self.received)then
   self.finished=true;return
  end
 end
 if now()<self.nextPoll then return end
 self.nextPoll=now()+.4
 local batch,total={},0
 for i=1,math.min(BATCH_SIZE,#self.outbox) do
  local row=self.outbox[i];if total+#row.body>96*1024 then break end
  batch[#batch+1]=row;total=total+#row.body
 end
 local closing=self.closing and #batch==#self.outbox or false
 local payload={battle=self.battle,ticket=self.ticket,after=self.received,messages=batch,close=closing}
 local cup,match=self.cup,self.match
 self.sentClose=closing
 self.closeAfter=closing and payload.after or nil
 self.job=Task.new(function()
  local doc,why,status
  if self.request then doc,why,status=self.request(payload)
  else doc,why,status=require('src.cloud.Tournaments').request('POST',cup,'battle-wire',payload,match) end
  if doc then return doc end
  return nil,{message=why,status=status}
 end)
 if not self.job then self:fail('Background Arena networking is unavailable.') end
end
function N:update() if not self.closed then self:exchange() end end
function N:close()
 if self.closing or self.finished then return end
 self.closing=true;self.closed=true;retiring[#retiring+1]=self
end
function N.pump()
 for i=#retiring,1,-1 do
  local net=retiring[i];net:exchange()
  if net.finished then table.remove(retiring,i) end
 end
end
return N
