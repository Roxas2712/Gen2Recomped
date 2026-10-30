-- Durable opt-in session credentials and exactly-once native trade receipts.
-- Contributions by Roxas2712; see NOTICE.md.
local S=require('src.core.SaveSerializer')
local Safety=require('src.core.SaveSafety')
local Saves=require('src.core.SaveData')
local V=require('src.core.GameVersion')
local J={REVISION=1,DIR='link/gen1-sessions'}
local function clone(value)return S.decode(S.encodeExact(value))end
local function roomId(id)return type(id)=='string'and #id==8 and id:match('^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]+$')end
function J.new(game,options)
  options=options or{}
  local fs=options.fs or Saves.persistenceFs()
  local version,slot=V.get(),options.slot or Saves.activeSlot(V.get())
  local player=game.save.player or{}
  local identity=S.encodeExact{edition=version,slot=slot,id=player.id,name=player.name,playthroughId=game.save.meta and game.save.meta.playthroughId}
  local data=game.data
  local function valid()
    local p=game.save.player or{}
    return game.data==data and V.get()==version and(options.slot or Saves.activeSlot(version))==slot
      and S.encodeExact{edition=version,slot=slot,id=p.id,name=p.name,playthroughId=game.save.meta and game.save.meta.playthroughId}==identity
  end
  local self={revision=1}
  local function file(id,kind)assert(roomId(id),'invalid room id');return J.DIR..'/'..id..'-'..kind..'.lua'end
  local function read(id,kind)
    if not valid()then return nil,'session save/profile retired'end
    local bytes=fs.read(file(id,kind));if bytes==nil then return nil end
    if type(bytes)~='string'or #bytes>4*1024*1024 then return nil,'invalid recovery record'end
    local ok,value=pcall(S.decode,bytes)
    if not ok or type(value)~='table'or value.schema~=1 or value.identity~=identity then return nil,'foreign or invalid recovery record'end
    return value
  end
  local function write(id,kind,value)
    if not valid()then return nil,'session save/profile retired'end
    value.schema,value.identity=1,identity
    local ok,why=fs.createDirectory(J.DIR);if ok==false then return nil,why end
    local bytes=S.encodeExact(value)
    if #bytes>4*1024*1024 then return nil,'recovery record budget exceeded'end
    return Safety.atomicWrite(fs,file(id,kind),bytes,{decode=S.decode})
  end
  function self:credentials(id,value)
    if value then return write(id,'channel',clone(value))end
    return read(id,'channel')
  end
  function self:list()
    local out={}
    if not valid()then return out end
    for _,name in ipairs(fs.getDirectoryItems(J.DIR)or{})do
      local id=name:match('^([23456789ABCDEFGHJKMNPQRSTUVWXYZ]+)%-channel%.lua$')
      if id and roomId(id)then local row=read(id,'channel');if row then
        local md=game.save.modData;local state=type(md)=='table'and md.gen1Sessions
        local pending=type(state)=='table'and type(state.receipts)=='table'and state.receipts[id]and not(type(state.learning)=='table'and state.learning[id])
        if not row.finished or pending then out[#out+1]={room=id,mode=row.mode}end
      end end
    end
    table.sort(out,function(a,b)return a.room<b.room end);return out
  end
  function self:isApplied(id)
    local doc=read(id,'trade')
    local md=game.save.modData
    local marks=type(md)=='table'and type(md.gen1Sessions)=='table'and md.gen1Sessions.receipts
    return doc and type(marks)=='table'and marks[id]==doc.digest or false
  end
  function self:prepare(id,index,received,digest,codec)
    if type(index)~='number'or index%1~=0 or not game.save.party[index]then return nil,'invalid native party slot'end
    local mon,why=codec.unpackMon(nil,received);if not mon then return nil,why end
    local prior,problem=read(id,'trade')
    if problem then return nil,problem end
    local record={slot=index,received=clone(received),digest=digest,before=S.encodeExact(game.save.party),stage='prepared'}
    if prior then
      if prior.slot~=index or prior.digest~=digest or S.encodeExact(prior.received)~=S.encodeExact(received)then return nil,'a prepared trade cannot change its offer'end
      return true
    end
    return write(id,'trade',record)
  end
  function self:recover(id,codec)
    local doc,why=read(id,'trade');if not doc then return nil,why or 'no prepared trade'end
    if doc.stage~='committed'and doc.stage~='applied'then return nil,'waiting for the durable relay decision'end
    local md=game.save.modData
    if md~=nil and type(md)~='table'then return nil,'native mod data requires repair before recovery'end
    local feature=md and md.gen1Sessions
    if feature~=nil and type(feature)~='table'then return nil,'native session markers require repair'end
    local receipts=feature and feature.receipts
    if receipts~=nil and type(receipts)~='table'then return nil,'native receipt markers require repair'end
    if feature and feature.learning~=nil and type(feature.learning)~='table'then return nil,'native learning markers require repair'end
    if receipts and receipts[id]then
      if receipts[id]~=doc.digest then return nil,'receipt digest differs'end
      return true,'already applied'
    end
    if S.encodeExact(game.save.party)~=doc.before then return nil,'the native party changed; recovery kept the existing save'end
    local received,err=codec.unpackMon(nil,doc.received);if not received then return nil,err end
    local candidate=clone(game.save)
    received.traded=true;candidate.party[doc.slot]=received
    if candidate.pokedex then
      candidate.pokedex.seen[received.species]=true;candidate.pokedex.owned[received.species]=true
    end
    local context={data=data,save=candidate}
    local E=require('src.pokemon.Evolution')
    local species,row=E.pendingFor(context,received,{kind='trade'})
    if species then E.apply(context,received,species,'TRADE',row)end
    require('src.pokemon.Gen3GameStats').increment(candidate,21)
    candidate.modData=candidate.modData or{}
    candidate.modData.gen1Sessions=candidate.modData.gen1Sessions or{receipts={}}
    candidate.modData.gen1Sessions.receipts=candidate.modData.gen1Sessions.receipts or{}
    local marks=candidate.modData.gen1Sessions.receipts
    local count=0;for _ in pairs(marks)do count=count+1 end
    if count>=64 then return nil,'native receipt budget full; preserve recovery records before maintenance'end
    marks[id]=doc.digest
    candidate.modData.gen1Sessions.learning=candidate.modData.gen1Sessions.learning or{}
    if not species then candidate.modData.gen1Sessions.learning[id]=true end
    local original=game.save;game.save=candidate
    local ok,saved,problem=pcall(game.writeSave,game)
    if not ok or not saved then game.save=original;return nil,tostring(ok and problem or saved)end
    -- Keep the live native save/player/party owners. Only the received slot
    -- changes identity; captureSave/metadata updates are merged in place.
    game.save=original
    local function merge(target,source)
      for key in pairs(target)do if source[key]==nil then target[key]=nil end end
      for key,value in pairs(source)do
        if type(value)=='table'and type(target[key])=='table'then merge(target[key],value)else target[key]=value end
      end
    end
    for key in pairs(original)do if key~='party'and candidate[key]==nil then original[key]=nil end end
    for key,value in pairs(candidate)do
      if key~='party'then
        if type(value)=='table'and type(original[key])=='table'then merge(original[key],value)else original[key]=value end
      end
    end
    original.party[doc.slot]=candidate.party[doc.slot]
    doc.stage='applied'
    local kept,note=write(id,'trade',doc)
    if not kept then return nil,'save committed; recovery record still pending: '..tostring(note)end
    return true,'applied'
  end
  function self:pendingLearning(id,codec)
    if not self:isApplied(id)then return nil end
    local doc=read(id,'trade')
    local metadata=game.save.modData.gen1Sessions
    if metadata.learning~=nil and type(metadata.learning)~='table'then return nil,nil,'invalid learning receipt map'end
    if metadata.learning and metadata.learning[id]then return nil end
    local incoming,why=codec.unpackMon(nil,doc.received);if not incoming then return nil,nil,why end
    local E=require('src.pokemon.Evolution')
    local target=E.pendingFor({data=data,save=game.save},incoming,{kind='trade'})
    if not target then return nil end
    local mon=game.save.party[doc.slot]
    if not mon or mon.species~=target or mon.personality~=incoming.personality or mon.otId~=incoming.otId then
      return nil,nil,'the evolved recipient moved; its learning receipt was retained'
    end
    return mon,require('src.battle.Experience').movesLearnedAt(data.pokemon[target],mon.level)
  end
  function self:finishLearning(id)
    if not self:isApplied(id)then return nil,'trade is not saved'end
    local metadata=game.save.modData.gen1Sessions
    if metadata.learning~=nil and type(metadata.learning)~='table'then return nil,'invalid learning receipt map'end
    metadata.learning=metadata.learning or{}
    local prior=metadata.learning[id];metadata.learning[id]=true
    local ok,saved,why=pcall(game.writeSave,game)
    if not ok or not saved then metadata.learning[id]=prior;return nil,tostring(ok and why or saved)end
    return true
  end
  function self:commit(id,message,codec)
    local doc,why=read(id,'trade');if not doc then return nil,why or 'no prepared trade'end
    if type(message)~='table'or message.type~='trade_commit'or message.n~=1 or type(message.digests)~='table'
      or message.digests[1]~=doc.digest or message.digests[2]~=doc.digest then return nil,'unverified relay commit'end
    if doc.stage=='prepared'then
      doc.stage='committed';doc.commit=clone(message)
      local ok,problem=write(id,'trade',doc);if not ok then return nil,problem end
    end
    return self:recover(id,codec)
  end
  return self
end
return J
