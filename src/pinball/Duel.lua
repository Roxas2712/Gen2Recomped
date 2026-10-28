-- Independent score duels; no fictitious GBA link-cable emulation.
-- Contributions by Roxas2712. Each peer runs its own unmodified physics.
local Duel={};Duel.__index=Duel
local MAX_SCORE=999999999999
local function integer(v,lo,hi)return type(v)=='number' and v==v and v%1==0 and v>=lo and v<=hi end
local function score(v)
 if type(v)~='string' or not v:match('^%d+$') or #v>12 then return end
 local n=tonumber(v);if n>MAX_SCORE or tostring(n):find('e') then return end
 return n
end
local function equal(a,b)
 return type(b)=='table' and a.rom==b.rom and a.backend==b.backend and a.content==b.content
  and a.field==b.field and a.frames==b.frames and a.seed==b.seed
end
function Duel.new(net,host,rules,options)
 assert(net and type(rules)=='table','Duel transport and rules required')
 assert(type(rules.rom)=='string' and type(rules.backend)=='string' and type(rules.content)=='string','Missing build identity')
 assert(integer(rules.field,0,1) and integer(rules.frames,600,215019) and rules.seed==0,'Invalid duel rules')
 local copy={};for _,k in ipairs{'rom','backend','content','field','frames','seed'}do copy[k]=rules[k] end
 return setmetatable({net=net,host=host==true,rules=copy,state='connecting',localFrame=0,remoteFrame=0,
  localScore=0,remoteScore=0,localDone=false,remoteDone=false,sequence=0,remoteSequence=0,
  viewRequested=options and options.view==true,localPictureFrame=0,remotePictureFrame=0},Duel)
end
function Duel:picture(packet)
 if not self.viewEnabled or self.state~='playing'or self.localDone then return false end
 if self.net.outbox and #self.net.outbox>3 then return false end
 if not integer(packet.frame,self.localPictureFrame+1,25000)or type(packet.png)~='string'or #packet.png>27000 then return false end
 self.localPictureFrame=packet.frame
 self:send('picture',{frame=packet.frame,width=packet.width,height=packet.height,png=packet.png});return true
end
function Duel:pollPicture()local picture=self.remotePicture;self.remotePicture=nil;return picture end
function Duel:send(kind,body)
 local msg=body or {};msg.type='pinball_duel';msg.protocol=1;msg.kind=kind;self.net:send(msg)
end
function Duel:fail(reason)
 self.error=reason;self.state='cancelled';self.result=nil
end
function Duel:ready(checkpoint)
 if self.state~='lobby' or self.localReady then return false end
 if type(checkpoint)~='string' or #checkpoint~=40 or not checkpoint:match('^%x+$')then return false end
 self.checkpoint=checkpoint;self.localReady=true;self:send('ready',{checkpoint=checkpoint});return true
end
function Duel:finishIfBoth()
 if self.localDone and self.remoteDone then
  self.state='finished';self.result=self.localScore==self.remoteScore and 'draw' or self.localScore>self.remoteScore and 'win' or 'loss'
 end
end
-- frame counts the agreed gameplay window, not intro/menu/loading time.
function Duel:progress(frame,points,done)
 if self.state~='playing' then return false end
 local n=score(tostring(points))
 if not integer(frame,self.localFrame,self.rules.frames) or not n or n<self.localScore then return false end
 if self.localDone then return false end
 self.localFrame=frame;self.localScore=n;self.localDone=done==true or frame==self.rules.frames
 self.sequence=self.sequence+1
 self:send('score',{seq=self.sequence,frame=frame,score=string.format('%.0f',n),done=self.localDone})
 self:finishIfBoth();return true
end
function Duel:update(dt)
 if self.state=='cancelled' or self.state=='finished' then return end
 self.net:update()
 if self.net.error then self:fail(self.net.error);return end
 if self.net.paired and not self.helloSent then self.helloSent=true;self:send('hello',{rules=self.rules,host=self.host,view=self.viewRequested and 2 or nil})end
 for _,msg in ipairs(self.net:poll())do
  if type(msg)~='table' or msg.type~='pinball_duel' or msg.protocol~=1 then self:fail('Incompatible duel protocol.');return end
  if msg.kind=='hello' and not self.helloReceived then
   if type(msg.host)~='boolean' or msg.host==self.host or not equal(self.rules,msg.rules) then self:fail('Different ROM, build, content or duel rules.');return end
   self.viewEnabled=self.viewRequested and msg.view==2
   self.helloReceived=true;self.state='lobby'
  elseif msg.kind=='ready' and self.helloReceived and self.state=='lobby' then
   if type(msg.checkpoint)~='string' or #msg.checkpoint~=40 or not msg.checkpoint:match('^%x+$')then self:fail('Invalid starting checkpoint.');return end
   self.remoteCheckpoint=msg.checkpoint;self.remoteReady=true
  elseif msg.kind=='ping' then -- keep an idle paired lobby alive through its relay
  elseif msg.kind=='start' and not self.host and self.state=='lobby' and self.localReady and self.remoteReady then self.state='playing';self.started=true
  elseif msg.kind=='picture'and self.state=='playing'and self.viewEnabled then
   if not integer(msg.frame,self.remotePictureFrame+1,25000)or not integer(msg.width,1,512)or not integer(msg.height,1,512)
    or type(msg.png)~='string'or #msg.png<44 or #msg.png>27000 then self:fail('Invalid opponent live picture.');return end
   self.remotePictureFrame=msg.frame;self.remotePicture={frame=msg.frame,width=msg.width,height=msg.height,png=msg.png}
  elseif msg.kind=='score' and self.state=='playing' then
   local n=score(msg.score)
   if not integer(msg.seq,self.remoteSequence+1,2147483647) or not integer(msg.frame,self.remoteFrame,self.rules.frames)
    or not n or n<self.remoteScore or type(msg.done)~='boolean' or self.remoteDone
    or (msg.frame==self.rules.frames and not msg.done) then self:fail('Invalid duel score update.');return end
   self.remoteSequence=msg.seq;self.remoteFrame=msg.frame;self.remoteScore=n;self.remoteDone=msg.done
   self:finishIfBoth()
  elseif msg.kind=='cancel' then self:fail('The other player left the duel.');return
  else self:fail('Unexpected duel message.');return end
 end
 -- A clean close may arrive in the same HTTP page as the final score.
 -- Drain that page before deciding whether the duel lost its connection.
 if self.net.closed and self.state~='finished'then self:fail('Connection lost; no duel result awarded.');return end
 if self.state=='finished'then return end
 if self.localReady and self.remoteReady and self.checkpoint~=self.remoteCheckpoint then self:fail('Different starting game state.');return end
 self.heartbeat=(self.heartbeat or 0)+(dt or 0)
 if self.net.paired and self.helloSent and self.heartbeat>=2 then self.heartbeat=0;self:send('ping')end
 if self.host and self.state=='lobby' and self.localReady and self.remoteReady then
  self:send('start');self.state='playing';self.started=true
 end
end
function Duel:close()
 if self.state~='finished' and self.state~='cancelled' then self:send('cancel');self:fail('Duel cancelled.')end
 self.net:close()
end
return Duel
