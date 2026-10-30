-- Explicit opt-in TCP relay connection with durable seat recovery.
-- Contributions by Roxas2712; see NOTICE.md.
local Net=require('compat.gen1_session.Tcp')
local C={PROFILE='gen1-session-v1:2aec7650cb01845a4e98f1dbcf8a5c652990d984'}
function C.new(journal,options)
  options=options or{}
  assert(options.mode=='trade'or options.mode=='battle','session mode required')
  local doc,problem
  if options.room then doc,problem=journal:credentials(options.room);if problem then return nil,problem end end
  local address=options.address or doc and doc.address or os.getenv('GEN1_FEATURE_RELAY')or '127.0.0.1:7780'
  local room,token=options.room,doc and doc.token
  local net,clock,retry=nil,0,0
  local self={mode=options.mode,room=room,seat=doc and doc.seat,paired=false,closed=false,inbox={},outbox={},ordinal=0}
  local function connect()
    net=options.netFactory and options.netFactory()or Net.new()
    if not net:connectTCP(address)then return false end
    net:send{type='session_open',profile=C.PROFILE,mode=options.mode,room=room,token=token}
    return true
  end
  function self:publish(key,body)
    if self.closed then return nil,'relay channel closed'end
    if not self.seat then return nil,'wait for relay seat'end
    local prior=self.outbox[key]
    local S={encodeExact=require('compat.gen1_session.Sync').signature}
    if prior and S.encodeExact(prior)~=S.encodeExact(body)then return nil,'sent message cannot change'end
    local ok,frozen=pcall(require('compat.gen1_session.Sync').clone,body)
    if not ok then return nil,tostring(frozen)end
    self.outbox[key]=frozen
    if self.paired then net:send{type='session_publish',key=key,body=frozen}end
    return true
  end
  function self:update(dt)
    if self.closed then return end
    clock=clock+dt
    if not net or net.closed or net.error then
      if clock<retry then return end
      if net then net:close()end
      self.paired=false;retry=clock+2
      if not connect()then self.notice='Relay unavailable; recovery credentials retained.';return end
    end
    net:update()
    for _,msg in ipairs(net:poll())do
      if msg.type=='session_error'then self.error=msg.message or 'Relay refused this session';self:close();return
      elseif msg.type=='session_welcome'then
        if msg.profile~=C.PROFILE or msg.mode~=options.mode or(msg.seat~=0 and msg.seat~=1)or type(msg.token)~='string'then self.error='relay profile/seat mismatch';self:close();return end
        room,token,self.room,self.seat=msg.room,msg.token,msg.room,msg.seat
        local ok,why=journal:credentials(room,{token=token,seat=msg.seat,mode=options.mode,address=address})
        if not ok then self.error=why;self:close();return end
        self.paired=true;self.notice=nil;self.seed=msg.seed
        for key,body in pairs(self.outbox)do net:send{type='session_publish',key=key,body=body}end
      elseif msg.type=='session_event'then
        if msg.room~=room or type(msg.ordinal)~='number'or msg.ordinal%1~=0 then self.error='foreign relay event';self:close();return end
        if msg.ordinal>self.ordinal then
          if msg.ordinal~=self.ordinal+1 then self.error='relay transcript gap';self:close();return end
          self.ordinal=msg.ordinal;self.inbox[#self.inbox+1]=msg
        end
      elseif msg.type=='session_presence'then if msg.seat~=self.seat then self.peerOnline=msg.online end end
    end
  end
  function self:poll()local out=self.inbox;self.inbox={};return out end
  function self:close(finished)
    if self.closed then return end
    self.closed=true;self.paired=false
    if net then net:close()end
    if finished and room then journal:credentials(room,{token=token,seat=self.seat,mode=options.mode,finished=true})end
  end
  return self
end
return C
