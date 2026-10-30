-- Opt-in lobby controller. Relay transcript is the single ordered input log.
-- Contributions by Roxas2712; see NOTICE.md.
local M={REVISION=1}
local S=require('src.core.SaveSerializer')
local V=require('src.core.GameVersion')
local Data=require('src.storage.LuaData')
local function copy(v)return S.decode(S.encodeExact(v))end
function M.new(game,channel,options)
  options=options or{}
  if game.linkSession then return nil,'another native link owns the game'end
  local data,edition=game.data,V.get()
  local originalParty=S.encodeExact(game.save.party)
  local journal=options.journal or require('src.features.Gen1SessionJournal').new(game)
  local self={game=game,channel=channel,phase='connecting',parties={},picks={},blocks={},hellos={},mode=channel.mode,journal=journal}
  if self.mode=='trade'and V.generation()~=3 then return nil,'this cable trade profile requires a GBA host'end
  if self.mode=='trade'and require('src.link.Handshake').linkModified(game)then return nil,'cable trade requires unmodified simulation catalogs'end
  local codec=self.mode=='trade'and require('src.features.Gen1Link3').codec(data,3,game.mods)
  self.codec=codec
  local battleTable,makeParty=options.table,options.records and function()return copy(options.records)end
  local function fail(why)self.error=tostring(why);self.phase='recovery';return nil,self.error end
  function self:valid()
    return not self.closed and game.data==data and V.get()==edition and game.linkSession==self
      and(not options.checkOwner or options.checkOwner())
  end
  function self:close(finished)
    self.closed=true;channel:close(finished)
    if game.linkSession==self then game.linkSession=nil end
  end
  local function send(key,body)local ok,why=channel:publish(key,body);if not ok then return fail(why)end;return true end
  local function outbound()
    if self.battle then
      for _,row in ipairs(self.battle:poll())do send(row.key,row.body)end
      self.events=self.events or{}
      for _,event in ipairs(self.battle:takeEvents())do self.events[#self.events+1]=event;if #self.events>32 then table.remove(self.events,1)end end
    end
  end
  local function buildBattle()
    if not self.table or not self.parties[0]or not self.parties[1]or self.battle then return true end
    local ok,value=pcall(require('src.features.Gen1SyncBattle').new,{table=self.table,parties=self.parties,seat=channel.seat,seed=channel.seed})
    if not ok then return fail(value)end
    self.battle=value;self.phase='battle';outbound();return true
  end
  local function startExchange()
    if self.exchange or not self.picks[0]or not self.picks[1]then return true end
    local seat=channel.seat;local peer=1-seat
    local mine=self.parties[seat]and self.parties[seat][self.picks[seat]]
    local theirs=self.parties[peer]and self.parties[peer][self.picks[peer]]
    if not mine or not theirs then return fail('selected party slot is absent')end
    local why;self.exchange,why=require('src.features.Gen1GbaExchange').new(codec,mine,theirs,{seat=seat})
    if not self.exchange then return fail(why)end
    self.myBlock=assert(self.exchange:block{name=(game.save.player or{}).name,trainerId=(game.save.player or{}).id})
    self.phase='confirm';return true
  end
  function self:pick(index)
    if not self:valid()or self.phase~='select'or self.picks[channel.seat]then return nil,'party selection is not active'end
    if type(index)~='number'or index%1~=0 or not self.parties[channel.seat][index]then return nil,'invalid party slot'end
    return send('pick',{type='game3_trade_pick',index=index})
  end
  function self:confirm()
    if not self:valid()or self.phase~='confirm'then return nil,'trade confirmation is not active'end
    return send('block',self.myBlock)
  end
  function self:cancel()
    if self.prepared then return nil,'confirmation is durable; reconnect to learn the relay decision'end
    if not self:valid()then return nil,'session retired'end
    return send('abort',{type='trade_abort',why='Player cancelled.'})
  end
  function self:choose(action)
    if not self:valid()or not self.battle then return nil,'battle is not active'end
    local key,body=self.battle:choose(action);if not key then return nil,body end
    return send(key,body)
  end
  function self:handle(event)
    if not Data.encode(event,65536)or type(event)~='table'or type(event.body)~='table'then return fail('invalid relay transcript')end
    local seat,body=event.seat,event.body
    if seat==-1 then
      if body.type=='trade_abort'then self.phase='cancelled';self:close(true);return true end
      if body.type~='trade_commit'or not self.exchange or not self.prepared then return fail('commit arrived before a verified offer')end
      local received,why=self.exchange:accept(body);if not received then return fail(why)end
      local ok,problem=journal:commit(channel.room,body,codec)
      if not ok then return fail(problem)end
      self.phase='done';self:close(true);return true
    end
    if seat~=0 and seat~=1 then return fail('invalid transcript seat')end
    if body.type=='session_hello'then
      if self.hellos[seat]then return fail('duplicate hello')end
      if body.profile~=require('src.features.Gen1RelayChannel').PROFILE or body.mode~=self.mode then return fail('peer did not select the same feature profile')end
      self.hellos[seat]=copy(body)
    elseif body.type=='game3_trade_party'and self.mode=='trade'then
      if self.parties[seat]then return fail('party offer changed')end
      local mons=body.mons
      if type(mons)~='table'or #mons<1 or #mons>6 then return fail('invalid cable party')end
      for _,packet in ipairs(mons)do local mon,why=codec.unpackMon(nil,packet);if not mon then return fail(why)end end
      if seat==channel.seat then
        local ok,own=pcall(codec.packParty,game.save.party)
        if not ok or S.encodeExact(own)~=S.encodeExact(mons)then return fail('native party differs from the recorded offer')end
      end
      self.parties[seat]=copy(mons)
      if self.parties[0]and self.parties[1]then self.phase='select'end
    elseif body.type=='game3_trade_pick'and self.mode=='trade'then
      if self.picks[seat]or not self.parties[0]or not self.parties[1]or type(body.index)~='number'or body.index%1~=0 or not self.parties[seat][body.index]then return fail('invalid or repeated party selection')end
      self.picks[seat]=body.index;return startExchange()
    elseif body.type=='game3_trade_mon'and self.mode=='trade'then
      if not self.exchange or self.blocks[seat]then return fail('out-of-phase trade block')end
      if seat==channel.seat and S.encodeExact(body.mon)~=S.encodeExact(self.myBlock.mon)then return fail('local exchange block changed')end
      self.blocks[seat]=copy(body)
      if self.blocks[0]and self.blocks[1]then
        local confirmation,why=self.exchange:receive(self.blocks[1-channel.seat])
        if not confirmation then return fail(why)end
        if S.encodeExact(game.save.party)~=originalParty then return fail('native party changed during confirmation')end
        local ok,problem=journal:prepare(channel.room,self.picks[channel.seat],self.parties[1-channel.seat][self.picks[1-channel.seat]],confirmation.digest,codec)
        if not ok then return fail(problem)end
        self.prepared=true;self.phase='committing';return send('confirm',confirmation)
      end
    elseif body.type=='game3_trade_confirm'and self.mode=='trade'then
      if not self.prepared then return fail('confirmation preceded durable preparation')end
    elseif body.type=='g3u_table'and self.mode=='battle'then
      if seat~=0 or self.table then return fail('only the host publishes the common rules once')end
      local b=require('src.features.gen1_gsc.Bundle').new{profile='g3u'}
      local ok,why=b:require('src.battle.g3u.Wire').validate(body,{bytes=#require('src.link.Json').encode(body)})
      if not ok then return fail(why)end
      self.table=copy(body.table);return buildBattle()
    elseif body.type=='g3u_party'and self.mode=='battle'then
      if self.parties[seat]or not self.table then return fail('battle party preceded rules or repeated')end
      local b=require('src.features.gen1_gsc.Bundle').new{profile='g3u'}
      local ok,why=b:require('src.battle.g3u.Wire').validate(body,{table=self.table})
      if not ok then return fail(why)end
      self.parties[seat]=copy(body.records);return buildBattle()
    elseif body.type=='session_battle_frame'or body.type=='session_battle_hash'then
      if not self.battle then return fail('battle action preceded setup')end
      local ok,why=self.battle:handle(seat,body);if not ok then return fail(why)end
      outbound()
      if self.battle:result()then self.result=self.battle:result();self.phase='done';self:close(true)end
    elseif body.type=='trade_abort'then self.phase='cancelled';self:close(true)
    else return fail('unsupported session message: '..tostring(body.type))end
    return true
  end
  function self:update(dt)
    if self.closed then return end
    if not self:valid()then self:close();return fail('native session owner retired')end
    channel:update(dt)
    if channel.error then return fail(channel.error)end
    for _,event in ipairs(channel:poll())do
      local ok,why=self:handle(event);if not ok then return nil,why end
      if self.closed then return end
    end
    if not channel.paired then return end
    local seat=channel.seat
    if not self.hellos[seat]then
      send('hello',{type='session_hello',profile=require('src.features.Gen1RelayChannel').PROFILE,mode=self.mode,generation=V.generation(),engineVersion=require('src.core.Version').engine})
      return
    end
    if not self.parties[seat]then
      if self.mode=='trade'then
        local ok,party=pcall(codec.packParty,game.save.party)
        if not ok then return fail(party)end
        return send('party',{type='game3_trade_party',mons=party})
      end
      if not makeParty then
        local why;battleTable,makeParty=require('src.features.Gen1BattleCatalog').build(data,V.generation())
        if not battleTable then return fail(makeParty)end
      end
      if seat==0 and not self.table then return send('table',{type='g3u_table',table=battleTable})end
      if self.table then
        local records,why=makeParty(game.save.party,self.table)
        if not records then return fail(why)end
        return send('party',{type='g3u_party',records=records})
      end
    end
  end
  game.linkSession=self
  if self.mode=='trade'and channel.room and journal:isApplied(channel.room)then self.phase='done';self:close(true)end
  return self
end
return M
