-- Opt-in protocol-3 trade codecs. Native protocol-2/battle negotiation stays native.
-- Contributions by Roxas2712; see NOTICE.md. Wire reference: gen1_gsc/provenance.json.
local Version=require('src.core.GameVersion')
local Release=require('src.core.Version')
local Protocol=require('src.link.Protocol')
local Handshake=require('src.link.Handshake')
local Serializer=require('src.core.SaveSerializer')
local LuaData=require('src.storage.LuaData')
local M={REVISION=1,PROTOCOL=3,MAX_BYTES=8*1024*1024}
local keys={'hp','attack','defense','speed','spatk','spdef'}
local short={'hp','atk','def','spe','spa','spd'}
local toStatus={sleep='SLP',poison='PSN',burn='BRN',freeze='FRZ',paralyze='PAR'}
local fromStatus={SLP='sleep',PSN='poison',BRN='burn',FRZ='freeze',PAR='paralyze'}
local function copy(t)
  if type(t)~='table'then return t end
  local o={};for k,v in pairs(t)do o[k]=copy(v)end;return o
end
local function num(n,hi,label,lo)
  assert(type(n)=='number'and n==n and n%1==0 and n>=(lo or 0)and n<=hi,'invalid '..label)
  return n
end
local function array(t,max,label)
  assert(type(t)=='table','invalid '..label)
  local n=0;for k in pairs(t)do num(k,max,label,1);n=n+1 end
  for i=1,n do assert(t[i]~=nil,'sparse '..label)end
  return n
end
local function nativePlain(value,seen,depth)
  if type(value)~='table'then return value end
  assert((depth or 0)<=LuaData.MAX_DEPTH,'native record exceeds traversal depth')
  local meta=getmetatable(value)
  assert(meta==nil or require('src.pokemon.Gen2MonFields').plainKind(value),'custom native metatable needs an explicit adapter')
  seen=seen or{};if seen[value]then return seen[value]end
  local out={};seen[value]=out
  for k,v in pairs(value)do out[k]=nativePlain(v,seen,(depth or 0)+1)end
  return out
end
local function checked(value,allowNative)
  if allowNative then value=nativePlain(value)end
  local report=LuaData.inspect(value);assert(report.serializable,report.reason)
  local encoded,why=LuaData.encode(value,M.MAX_BYTES);assert(encoded,why)
  return encoded
end
local function extra(value,depth)
  if value==nil then return end
  assert(type(value)=='table','extra mod fields must be a table')
  assert((depth or 0)<=8,'peer extra fields exceed the source codec depth')
  for _,child in pairs(value)do
    if type(child)=='table'then extra(child,(depth or 0)+1)
    elseif type(child)=='string'then assert(#child<=64,'source transport clips extra strings beyond 64 bytes')end
  end
end
local function attempt(fn,...)
  local ok,a,b=pcall(fn,...);if not ok then return nil,tostring(a)end;return a,b
end
function M.codec(data,generation,loader)
  assert(type(data)=='table'and generation>=1 and generation<=3,'Gen1/2/3 dataset required')
  local synthetic={content={}}
  for _,kind in ipairs{'pokemon','moves','items'}do
    local rows=data[kind]or{}
    synthetic.content[kind]={base=function()return rows end,each=function()return pairs(rows)end}
  end
  local ids=require('src.mods.UnifiedIds').new(loader or synthetic)
  local numeric=require('src.compat.gen1.BattleIds').new(data)
  local edition=Version.get()
  local function name(kind,key)
    if key==nil or key==0 or key==false then return nil end
    local id=ids:read(kind,key);local group,why=ids:resolve(kind,id);assert(group,why)
    assert(#id<=64,'portable identity exceeds source transport limit')
    return id
  end
  local function native(kind,id)
    if id==nil or id==0 then return nil end
    local group,why=ids:resolve(kind,id);assert(group,why);return group.key
  end
  local function number(kind,id)
    local n=numeric:read(kind,id);assert(n~=nil,'unknown cartridge '..kind..' id: '..tostring(id));return n
  end
  local function physical(kind,n)
    if kind=='items'and(n==nil or n==0)then return nil end
    local id=numeric:native(kind,n);assert(id~=nil,'unknown cartridge '..kind..' number: '..tostring(n));return id
  end
  local function common(p)
    assert(Version.get()==edition and numeric:valid(),'link codec belongs to a retired cartridge')
    checked(p);assert(type(p)=='table','party record required')
    num(p.level,100,'level',1);num(p.hp,65535,'HP')
    if p.otId~=nil then num(p.otId,65535,'OT id')end
    assert(p.nickname==nil or type(p.nickname)=='string'and #p.nickname<=40,'invalid nickname')
    assert(p.ot==nil or type(p.ot)=='string','invalid OT name')
    local n=array(p.moves,4,'moves');assert(n>0,'empty move list')
    for _,move in ipairs(p.moves)do
      assert(type(move)=='table','move record required');num(move.pp,255,'PP')
      if move.ppUps~=nil then num(move.ppUps,3,'PP Ups')end
    end
  end
  local function decode(p)
    common(p)
    local packet=copy(p)
    if generation<3 then
      extra(p.extra)
      if generation==2 then
        for _,spec in ipairs{{'caughtLevel',100},{'caughtTime',3},{'caughtLocation',127}}do
          if p[spec[1]]~=nil then num(p[spec[1]],spec[2],spec[1])end
        end
        assert(p.caughtByGender==nil or p.caughtByGender=='boy'or p.caughtByGender=='girl','invalid caught gender')
        assert(p.isEgg==nil or type(p.isEgg)=='boolean','invalid egg flag')
      end
      packet.species=native('pokemon',p.species)
      packet.item=native('items',p.item)
      for i,move in ipairs(p.moves)do packet.moves[i].id=native('moves',move.id)end
      num(generation==2 and p.experience or p.exp,2147483647,'experience')
      packet.exp=generation==2 and p.experience or p.exp
      assert(type(p.dvs)=='table'and type(p.statExp)=='table','classic genetics required')
      for _,key in ipairs{'attack','defense','speed','special'}do num(p.dvs[key],15,'DV '..key)end
      for _,key in ipairs{'hp','attack','defense','speed','special'}do num(p.statExp[key]or 0,65535,'stat experience '..key)end
      packet.dvs.hp=require('src.pokemon.Stats').hpDV(packet.dvs)
      if generation==1 then
        assert(p.item==nil,'Gen1 source wire has no held item field')
        assert(p.dvs.hp==nil or p.dvs.hp==packet.dvs.hp,'HP DV differs from its derived value')
      end
      if generation==2 then
        assert(p.status==nil or toStatus[p.status],'invalid Gen2 status')
        packet.status=p.status and toStatus[p.status]
        if p.happiness~=nil then num(p.happiness,255,'happiness')end
        if p.pokerus~=nil then num(p.pokerus,255,'pokerus')end
      else assert(p.status==nil or fromStatus[p.status],'invalid Gen1 status')end
      local mon,why=Protocol.unpackMon(data,packet,{strict=true});assert(mon,why)
      if p.level==1 then
        mon.level=1;mon.stats=require('src.pokemon.Stats').calc(data.pokemon[mon.species],1,mon.dvs,mon.statExp)
      end
      assert(p.hp<=mon.stats.hp,'HP exceeds the receiver species')
      for i,move in ipairs(p.moves)do assert(mon.moves[i]and mon.moves[i].pp==move.pp,'invalid move PP for target dataset')end
      assert(mon.ot==p.ot,'OT name cannot be represented without clipping')
      mon.hp=p.hp;mon.exp=packet.exp;mon.extra=copy(p.extra)
      if generation==1 and p.status=='SLP'then mon.sleepTurns=num(p.sleepTurns,7,'sleep turns',1)end
      if generation==2 then
        for _,key in ipairs{'happiness','pokerus','caughtLevel','caughtTime','caughtLocation','caughtByGender','isEgg','eggSteps'}do mon[key]=copy(p[key])end
        if p.isEgg then mon.eggSteps=num(p.eggSteps,255,'egg cycles',1)*256 end
      end
      if generation==2 then require('src.pokemon.Gen2MonFields').bind(data,mon)end
      return mon
    end
    for _,spec in ipairs{{'language',255},{'pokerus',255},{'markings',15},{'metLocation',255},{'metLevel',100},{'metGame',15},{'eggCycles',255},{'otGender',1},{'friendship',255}}do
      num(p[spec[1]],spec[2],spec[1])
    end
    assert(type(p.contest)=='table','contest conditions required')
    for _,key in ipairs{'cool','beauty','cute','smart','tough','sheen'}do num(p.contest[key],255,'contest '..key)end
    assert(type(p.isEgg)=='boolean','egg flag required')
    num(p.personality,4294967295,'personality');num(p.otId,65535,'OT id');num(p.otSecretId,65535,'secret id')
    num(p.abilityNum,1,'ability number');num(p.ribbons,4294967295,'ribbons')
    num(p.pokeball,12,'capture ball',1)
    num(p.species,411,'species number',1);num(p.item,374,'held item')
    assert(p.status==nil or p.status==''or p.status=='TOX'or fromStatus[p.status],'invalid Gen3 status')
    assert(p.gender=='M'or p.gender=='F'or p.gender=='U','invalid Gen3 gender')
    assert(p.extra==nil or next(p.extra)==nil,'Gen1 Gen3 wire cannot preserve extra mod fields')
    packet={gen3Codec=1,species=physical('pokemon',p.species),level=p.level,exp=p.exp,hp=p.hp,
      status=p.status=='TOX'and'PSN'or(p.status~=''and p.status or nil),toxic=p.status=='TOX'or nil,
      personality=p.personality,nature=p.nature,abilitySlot=p.abilityNum+1,
      ivs={},evs={},nickname=p.nickname,ot=p.otName,otId=p.otId,secretId=p.otSecretId,
      otGender=p.otGender,happiness=p.friendship,gen3Language=p.language,gen3Pokerus=p.pokerus,
      gen3Markings=p.markings,contest=copy(p.contest),ribbons=p.ribbons,
      metLocation=p.metLocation,metLevel=p.metLevel,metGame=p.metGame,ball=physical('items',p.pokeball),item=physical('items',p.item),
      isEgg=p.isEgg,eggCycles=p.eggCycles,modernFatefulEncounter=p.modernFatefulEncounter,
      fatefulEncounter=p.fatefulEncounter,gender=({M='male',F='female',U='unknown'})[p.gender],moves={}}
    for i,key in ipairs(keys)do
      packet.ivs[key]=num((p.ivs or{})[short[i]],31,'IV '..short[i])
      packet.evs[key]=num((p.evs or{})[short[i]],255,'EV '..short[i])
    end
    for i,move in ipairs(p.moves)do
      num(move.id,354,'move number',1)
      packet.moves[i]={id=physical('moves',move.id),pp=move.pp,ppUps=move.ppUps}
    end
    local def=data.pokemon[packet.species]
    local ability=(def.abilities or{})[packet.abilitySlot]
    assert(p.ability==(ability and number('abilities',ability)or 0),'ability does not match species and slot')
    local mon,why=require('src.link.Gen3Party').unpack(data,packet,{strict=true},copy);assert(mon,why)
    assert(mon.hp==p.hp,'HP exceeds the receiver species')
    return mon
  end
  local function encode(mon)
    checked(mon,true)
    if generation<3 then
      extra(mon.extra)
      assert(not mon.toxic,'classic source wire cannot preserve a native toxic counter flag')
      local p=Protocol.packMon(mon)
      p.ot=mon.ot or mon.otName
      p.extra=copy(mon.extra);p.species=name('pokemon',mon.species);p.item=name('items',mon.item)
      for i,move in ipairs(mon.moves)do p.moves[i].id=name('moves',move.id)end
      if generation==2 then
        assert(mon.caughtData==nil or mon.caughtData==0,'opaque caughtData requires explicit hydrated source fields')
        p.experience=mon.exp;p.exp=nil;p.status=mon.status and assert(fromStatus[mon.status],'invalid native status')
        p.dvs=copy(p.dvs);p.dvs.hp=nil
        assert(not(mon.status=='SLP'and mon.sleepTurns~=nil),'source GSC codec cannot preserve a native sleep counter')
        for _,key in ipairs{'happiness','pokerus','caughtLevel','caughtTime','caughtLocation','caughtByGender','isEgg','eggSteps'}do p[key]=copy(mon[key])end
        if require('src.pokemon.Party').isEgg(mon)then
          p.isEgg=true;p.eggSteps=num((mon.eggSteps or 0)/256,255,'whole egg cycles',1)
        end
      else
        assert(not mon.item,'Gen1 source wire has no held item field')
        p.sleepTurns=mon.status=='SLP'and mon.sleepTurns or nil
      end
      decode(p);return p
    end
    assert(mon.extra==nil or next(mon.extra)==nil,'Gen1 Gen3 wire cannot preserve extra mod fields')
    for i,key in ipairs(keys)do num((mon.ivs or{})[key],31,'native IV');num((mon.evs or{})[key],255,'native EV')end
    for _,spec in ipairs{{'gen3Language',255},{'language',255},{'gen3Pokerus',255},{'pokerus',255},{'gen3Markings',15},{'markings',15},{'metLocation',255},{'metLevel',100},{'metGame',15},{'eggCycles',255},{'otGender',1},{'friendship',255},{'happiness',255}}do
      if mon[spec[1]]~=nil then num(mon[spec[1]],spec[2],spec[1])end
    end
    for _,value in pairs(mon.contest or{})do num(value,255,'contest condition')end
    assert(mon.mail==nil,'mail needs the source mail-block adapter')
    assert(mon.sleepTurns==nil,'source Game3 wire cannot preserve a sleep counter')
    local p=require('src.link.Gen3Party').pack(mon,copy)
    assert(mon.nickname==nil or p.nickname==mon.nickname,'nickname cannot be represented without clipping')
    assert(p.ot==(mon.gen3OtName or mon.otName or mon.ot or ''),'OT name cannot be represented without clipping')
    p.gender=require('src.pokemon.IdentityRolls').gender(data,mon,3)
    local wire={species=number('pokemon',mon.species),nickname=p.nickname,level=p.level,exp=p.exp,hp=p.hp,
      status=p.toxic and'TOX'or p.status or '',personality=p.personality,otId=p.otId,otSecretId=p.secretId,otName=p.ot,
      otGender=p.otGender,nature=p.nature,abilityNum=p.abilitySlot-1,language=p.gen3Language,
      contest=p.contest,gender=({male='M',female='F',unknown='U'})[p.gender],ivs={},evs={},moves={},
      item=mon.item and number('items',mon.item)or 0,friendship=p.happiness,pokerus=p.gen3Pokerus,
      metLocation=p.metLocation,metLevel=p.metLevel,metGame=p.metGame,pokeball=number('items',mon.ball),
      ribbons=p.ribbons,markings=p.gen3Markings,isEgg=p.isEgg,
      fatefulEncounter=p.fatefulEncounter,modernFatefulEncounter=p.modernFatefulEncounter,eggCycles=p.eggCycles or 0}
    local ability=(data.pokemon[mon.species].abilities or{})[p.abilitySlot]
    wire.contest=wire.contest or{}
    for _,key in ipairs{'cool','beauty','cute','smart','tough','sheen'}do wire.contest[key]=wire.contest[key]or 0 end
    wire.ability=ability and number('abilities',ability)or 0
    for i,key in ipairs(keys)do wire.ivs[short[i]],wire.evs[short[i]]=p.ivs[key],p.evs[key]end
    for i,move in ipairs(p.moves)do wire.moves[i]={id=number('moves',move.id),pp=move.pp,ppUps=move.ppUps}end
    decode(wire);return wire
  end
  local codec={generation=generation}
  function codec.packMon(mon)return attempt(encode,mon)end
  function codec.unpackMon(_,packet)return attempt(decode,packet)end
  function codec.packParty(party,indices)
    local out={};for _,index in ipairs(indices or(function()local t={};for i=1,#party do t[i]=i end;return t end)())do
      local p,why=codec.packMon(party[index]);assert(p,why);out[#out+1]=p
    end;return out
  end
  return codec
end
function M.hello(game)
  if Version.generation()==3 then return nil,'Game3 uses its own block/commit envelope; this hello is the GB trade profile'end
  local hello=Handshake.hello(game,'trade')
  hello.protocol=3;hello.generation=Version.generation();hello.tradeOnly=true
  hello.fingerprint='gen2recomped.native.link3-trade-v1:'..tostring(hello.fingerprint)
  return hello
end
function M.negotiate(game,peer)
  if type(peer)~='table'or peer.protocol~=3 then return nil,'protocol 3 hello required'end
  if (peer.generation or 1)~=Version.generation()then return nil,'generation mismatch'end
  if Version.generation()>3 then return nil,'unsupported generation'end
  if Handshake.linkModified(game)or peer.linkModified then return nil,'cross-engine trade requires unmodified simulation data'end
  if type(peer.engineVersion)~='string'or peer.engineVersion==Release.engine then
    return nil,'a verified foreign engine release is required'
  end
  if peer.engineVersion:match('^(%d+)')~=Release.engine:match('^(%d+)')then return nil,'engine major mismatch'end
  return 'engine_skew','trade only; independent engines cannot promise battle lockstep'
end
function M.newTrade(game,peer,options)
  options=options or{}
  local verdict,why=M.negotiate(game,peer);if not verdict then return nil,why end
  if Version.generation()==3 then return nil,'Game3 requires its block/commit envelope; use the Gen3 packet codec, not the GB trade state machine'end
  if game.linkSession then return nil,'another link session is active'end
  local data,save,mods,edition=game.data,game.save,game.mods,Version.get()
  local party=save and save.party;if type(party)~='table'or #party<1 or #party>6 then return nil,'invalid local party'end
  local codec=M.codec(data,Version.generation(),mods)
  for _,mon in ipairs(party)do local p,reason=codec.packMon(mon);if not p then return nil,reason end end
  local original=checked(party,true)
  local function currentParty()local ok,bytes=pcall(checked,party,true);return ok and bytes or nil end
  local s=Protocol.TradeSession.new(data,party,{strict=true,peerName=peer.name,codec=codec})
  local baseHandle,baseApply,baseConfirm=s.handle,s.apply,s.confirm
  local function valid()
    return(not options.checkOwner or options.checkOwner())and game.data==data and game.save==save and game.mods==mods and save.party==party
      and package.loaded['src.core.Game']==game and Version.get()==edition and game.linkSession==s and currentParty()==original
  end
  function s:close()if game.linkSession==self then game.linkSession=nil end;self.closed=true end
  function s:handle(msg)
    if self.closed or not valid()then self:close();self.stage='cancelled';self.error='native trade owner changed';return nil end
    local ok,reason=pcall(checked,msg)
    if not ok or type(msg)~='table'then self:close();self.stage='cancelled';self.error=tostring(reason);return nil end
    if msg.type=='party'and(self.stage~='waitParty'or self.theirParty~=nil)then
      self:close();self.stage='cancelled';self.error='duplicate or out-of-phase peer party';return nil
    end
    if msg.type=='party'and(not pcall(array,msg.mons,6,'party')or #msg.mons<1)then
      self:close();self.stage='cancelled';self.error='invalid peer party';return nil
    end
    if msg.type=='pick'and(self.stage~='picking'and self.stage~='waitPick')then self:close();self.stage='cancelled';self.error='out-of-phase peer pick';return nil end
    if msg.type=='pick'and(self.theirPick~=nil or self.theirCancel)then self:close();self.stage='cancelled';self.error='duplicate peer pick';return nil end
    if msg.type=='pick'and msg.cancel then self.theirCancel=true;self:advance();return nil end
    if msg.type=='pick'and not self.theirParty then self:close();self.stage='cancelled';self.error='peer pick precedes party';return nil end
    if msg.type=='pick'and(not(type(msg.index)=='number'and msg.index%1==0 and msg.index>=1 and msg.index<=6))then
      self:close();self.stage='cancelled';self.error='invalid peer pick';return nil
    end
    if msg.type=='confirm'and(type(msg.ok)~='boolean'or self.stage~='confirming'or self.theirConfirm~=nil)then self:close();self.stage='cancelled';self.error='invalid confirmation';return nil end
    local result=baseHandle(self,msg)
    if self.stage=='cancelled'then self:close()end
    return result
  end
  function s:advance()
    if self.theirPick and self.theirParty and not self.theirParty[self.theirPick]then self.stage='cancelled';self.error='peer picked an absent party slot';self:close();return end
    if self.stage=='picking'and(self.myPick or self.myCancel)then self.stage='waitPick'end
    if self.stage=='waitPick'then
      if(self.myCancel or self.theirCancel)and(self.myPick or self.myCancel)and(self.theirPick or self.theirCancel)then
        self.stage=self.myCancel and self.theirCancel and'cancelled'or'restart'
      elseif self.myPick and self.theirPick then self.stage='confirming'end
    end
    if self.stage=='confirming'and self.myConfirm~=nil and self.theirConfirm~=nil then
      self.stage=self.myConfirm and self.theirConfirm and'done'or'declined'
    end
    if self.stage=='cancelled'then self:close()end
  end
  function s:pick(index)
    if self.closed or not valid()then return nil,'native trade owner changed'end
    if self.stage~='picking'and self.stage~='waitPick'then return nil,'trade is not selecting'end
    if self.myPick or self.myCancel then return nil,'local selection already sent'end
    if not(type(index)=='number'and index%1==0 and party[index])then return nil,'invalid local pick'end
    self.myPick=index;self:advance();return {type='pick',index=self:wireIndex(index)}
  end
  function s:cancelPick()
    if self.closed or not valid()then return nil,'native trade owner changed'end
    if self.myPick or self.myCancel then return nil,'local selection already sent'end
    if self.stage~='picking'and self.stage~='waitPick'then return nil,'trade is not selecting'end
    self.myCancel=true;self:advance();return {type='pick',cancel=true}
  end
  function s:confirm(ok)
    if self.closed or not valid()then return nil,'native trade owner changed'end
    if self.myConfirm~=nil then return nil,'local confirmation already sent'end
    if self.stage~='confirming'or type(ok)~='boolean'then return nil,'trade is not confirming'end
    return baseConfirm(self,ok)
  end
  function s:reset()
    if self.closed or not valid()then return nil,'native trade owner changed'end
    if self.stage~='restart'and self.stage~='declined'then return nil,'trade cannot restart'end
    self.myPick,self.theirPick,self.myCancel,self.theirCancel,self.myConfirm,self.theirConfirm=nil,nil,nil,nil,nil,nil
    self.stage='picking';return true
  end
  function s:apply(owner)
    if owner~=game or self.stage~='done'or not valid()then return nil,'trade is incomplete or native party changed'end
    local received,evolve,row=baseApply(self,game)
    self.stage='applied';self:close();return received,evolve,row
  end
  game.linkSession=s
  return s,verdict
end
return M
