-- Same pinned kernel on both peers; canonical seats and per-step hash barriers.
-- Contributions by Roxas2712; source kernel retains gen1_gsc/LICENSE.MD.
local M={REVISION=1,PROFILE='g3u-common-v1:2aec7650cb01845a4e98f1dbcf8a5c652990d984'}
-- This module also loads in the pinned Gen1 engine without Gen2 service imports.
local function signature(value,active,depth)
  active=active or{};depth=depth or 0;assert(depth<=96,'record depth exceeded')
  local kind=type(value)
  if kind=='nil'then return 'z'end
  if kind=='boolean'then return value and 'b1'or 'b0'end
  if kind=='number'then assert(value==value and math.abs(value)<math.huge,'nonfinite record');return 'n'..string.format('%.17g',value)..';'end
  if kind=='string'then return 's'..#value..':'..value end
  assert(kind=='table'and getmetatable(value)==nil and not active[value],'plain acyclic record required')
  active[value]=true;local keys={};for key in pairs(value)do assert(type(key)=='number'or type(key)=='string','invalid record key');keys[#keys+1]=key end
  table.sort(keys,function(a,b)if type(a)==type(b)then return a<b end;return type(a)<type(b)end)
  local out={'t'};for _,key in ipairs(keys)do out[#out+1]=signature(key,active,depth+1);out[#out+1]=signature(value[key],active,depth+1)end
  out[#out+1]='e';active[value]=nil;return table.concat(out)
end
local function copy(value)
  if type(value)~='table'then return value end
  local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out
end
local S={encodeExact=signature}
local Data={encode=function(value,limit)local ok,bytes=pcall(signature,value);return ok and #bytes<=limit and bytes or nil end}
M.signature=signature
function M.clone(value)signature(value);return copy(value)end
function M.new(options,namespace)
  assert(options.seat==0 or options.seat==1,'canonical seat required')
  assert(Data.encode({options.table,options.parties},256*1024))
  local b=namespace or{require=function(_,name)return require(name)end}
  local Wire,Match,Hash=b:require('src.battle.g3u.Wire'),b:require('src.battle.g3u.Match'),b:require('src.battle.g3u.Hash')
  assert(b:require('src.battle.g3u.Table').validate(options.table))
  for seat=0,1 do assert(Wire.validate({type='g3u_party',records=options.parties[seat]},{table=options.table}))end
  assert(type(options.seed)=='number'and options.seed%1==0 and options.seed>=1 and options.seed<=2147483646,'shared seed required')
  local match=Match.new{table=copy(options.table),parties=copy(options.parties),seed=options.seed,names=options.names}
  local self={seat=options.seat,step=0,match=match,events=match:start(),outbox={},seen={},hashes={},actions={}}
  local function hash()return Hash.value(Hash.parts(match.st,match.draws))end
  local function checkpoint()
    self.hash=hash();self.hashes={};self.actions={}
    self.outbox[#self.outbox+1]={key='hash:'..self.step,body={type='session_battle_hash',step=self.step,hash=self.hash}}
  end
  local function fail(why)self.error=why;self.closed=true;return nil,why end
  function self:ready()return not self.closed and self.hashes[0]==self.hash and self.hashes[1]==self.hash end
  function self:legal()
    if not self:ready()or self.actions[self.seat]then return{}end
    return match:legalActions(self.seat)
  end
  function self:choose(action)
    if not self:ready()or self.actions[self.seat]then return nil,'wait for both peer hashes and the next decision'end
    if not match:isLegal(self.seat,action)then return nil,'illegal shared-kernel action'end
    local wire=match.phase=='replace'and Wire.replace(match.turn,action.index)or Wire.action(match.turn+1,action)
    return 'action:'..self.step,{type='session_battle_frame',step=self.step,wire=wire}
  end
  function self:handle(seat,message)
    if self.closed then return nil,self.error end
    if seat~=0 and seat~=1 then return fail('invalid battle seat')end
    if not Data.encode(message,1024)or type(message)~='table'or type(message.step)~='number'or message.step%1~=0 then return fail('invalid battle frame')end
    local kind=message.type
    if kind~='session_battle_hash'and kind~='session_battle_frame'then return fail('unsupported battle message')end
    local key=seat..':'..kind..':'..message.step;local encoded=S.encodeExact(message)
    if self.seen[key]then if self.seen[key]~=encoded then return fail('a battle frame changed after confirmation')end;return true end
    if message.step~=self.step or self.step>4096 then return fail('out-of-order battle step')end
    if kind=='session_battle_hash'then
      if message.hash~=self.hash then return fail('synchronous battle desynchronized')end
      self.hashes[seat]=message.hash
    else
      if not self:ready()then return fail('action preceded the peer hash barrier')end
      local wire,why=Wire.validate(message.wire)
      if not wire then return fail(why)end
      local replacing=match.phase=='replace'
      if replacing and(wire.type~='g3u_replace'or wire.turn~=match.turn)or not replacing and(wire.type~='g3u_action'or wire.turn~=match.turn+1)then return fail('wrong battle phase/turn')end
      local action=replacing and{kind='switch',index=wire.index}or Wire.toAction(wire)
      if not match:isLegal(seat,action)then return fail('peer submitted an illegal action')end
      self.actions[seat]=action
    end
    self.seen[key]=encoded
    if kind=='session_battle_frame'then
      local complete=true
      for side=0,1 do if(match.phase~='replace'or match:needs(side))and not self.actions[side]then complete=false end end
      if complete then
        local events
        if match.phase=='replace'then
          local picks={};for side=0,1 do if self.actions[side]then picks[side]=self.actions[side].index end end
          events=match:replace(picks)
        else events=match:submit(self.actions)end
        for _,event in ipairs(events)do self.events[#self.events+1]=event end
        self.step=self.step+1;checkpoint()
      end
    end
    return true
  end
  function self:poll()local out=self.outbox;self.outbox={};return out end
  function self:takeEvents()local out=self.events;self.events={};return out end
  function self:result()if self:ready()and match.phase=='over'then return copy(match.result)end end
  checkpoint();return self
end
return M
