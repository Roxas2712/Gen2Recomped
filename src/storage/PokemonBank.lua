-- Immutable copies, never withdrawals. Saves and network records are parsed as
-- data; only locally extracted ROM definitions are loaded as Lua modules.
local B={DIRECTORY='bank/entries',MAX_BYTES=512*1024}
local S=require('src.core.SaveSerializer')
local Safety=require('src.core.SaveSafety')
local Saves=require('src.core.SaveData')
local Versions=require('src.core.GameVersion')
local Stats=require('src.pokemon.Stats')
local function clone(value) return S.decode(S.encode(value)) end
local function hash(bytes) return love.data.encode('string','hex',love.data.hash('sha256',bytes)) end
local function fs() return Saves.persistenceFs() end
local function validId(id) return type(id)=='string' and #id==64 and id:match('^[a-f0-9]+$') end
local function integer(n,lo,hi) return type(n)=='number' and n%1==0 and n>=lo and n<=hi end
local function key(value) return tostring(value or ''):upper():gsub('[^A-Z0-9]','') end
local function shape(version,data)
  local gen=Versions.generation(version)
  local storage=data and data.save_layout and data.save_layout.fields and data.save_layout.fields.storage or {}
  return tonumber(storage.boxCount) or (gen==5 and 24 or gen==4 and 18 or gen>=2 and 14 or 12),
    tonumber(storage.boxCapacity) or (gen>=3 and 30 or 20)
end
local function boxes(save)
  local list=save.boxes or (save.box and (save.box.boxes or {save.box.mons or save.box})) or {}
  return list
end
local function mons(box) return type(box)=='table' and (box.mons or box) or {} end
function B.scan(save,version)
  local out={}
  local function add(mon,place)
    if type(mon)=='table' and (type(mon.species)=='string' or type(mon.species)=='number') then out[#out+1]={mon=mon,place=place} end
  end
  for i=1,6 do add((save.party or {})[i],'Party '..i) end
  local count,capacity=shape(version)
  for box=1,count do for slot=1,capacity do add(mons(boxes(save)[box])[slot],'Box '..box..' / '..slot) end end
  return out
end
function B.readSave(version,slot)
  local path=Saves.slotDiskPath(version,slot)
  if not path then return nil,'Save location is unavailable.' end
  local file=io.open(path,'rb');if not file then return nil,'This save slot is empty or unavailable.' end
  local bytes=file:read(8*1024*1024+1);file:close()
  if #bytes>8*1024*1024 then return nil,'Save is too large.' end
  local ok,save=pcall(Safety.decodeSave,bytes)
  if not ok or not save then return nil,'This slot is not a readable save.' end
  return save
end
local function cacheTable(version,name)
  local Cache=require('src.import.CacheFs');local previous=Cache.prefix
  Cache.prefix=Versions.VERSIONS[version].cachePrefix
  local ok,bytes=pcall(Cache.read,'data/generated/'..name..'.lua');Cache.prefix=previous
  if not ok or type(bytes)~='string' then return nil end
  local chunk=loadstring(bytes,'@bank-rom-'..version..'-'..name)
  if not chunk then return nil end
  local good,value=pcall(chunk);return good and type(value)=='table' and value or nil
end
local datasets={}
function B.data(version)
  if not Versions.VERSIONS[version] then return nil,'Unknown game.' end
  if datasets[version] then return datasets[version] end
  local data={}
  for _,name in ipairs({'pokemon','moves','items','constants','save_layout'}) do data[name]=cacheTable(version,name) end
  if not data.pokemon or not data.moves then return nil,'Import this game before using its Bank.' end
  data.items=data.items or {};data.constants=data.constants or {}
  local Records=require('src.pokemon.SpeciesRecords');Records.species(data.pokemon);Records.constants(data.constants)
  datasets[version]=data;return data
end
local function canonical(mon,data)
  local def=data.pokemon[mon.species] or {}
  local info={dex=def.dex or def.nationalDex or tonumber(tostring(mon.species):match('(%d+)$')),moves={}}
  for i,move in ipairs(mon.moves or {}) do
    local record=data.moves[move.id] or {}
    info.moves[i]={name=key(record.name or move.id)}
  end
  if mon.heldItem and mon.heldItem~='' then info.item=key((data.items[mon.heldItem] or {}).name or mon.heldItem) end
  return info
end
function B.decode(bytes,id)
  if type(bytes)~='string' or #bytes>B.MAX_BYTES then return nil,'Invalid Bank entry size.' end
  local ok,value=pcall(S.decode,bytes)
  if not ok or type(value)~='table' or value.schema~=1 or type(value.source)~='table'
    or not Versions.VERSIONS[value.source.version] or type(value.mon)~='table'
    or (type(value.mon.species)~='string' and type(value.mon.species)~='number')
    or not integer(value.mon.level,1,100) or type(value.mon.moves)~='table' or #value.mon.moves>4
    or type(value.canonical)~='table' or type(value.canonical.moves)~='table' then return nil,'Invalid Bank entry.' end
  for _,move in ipairs(value.mon.moves) do
    if type(move)~='table' or (type(move.id)~='string' and type(move.id)~='number') then return nil,'Invalid Bank move.' end
  end
  if value.origin and (type(value.origin)~='table' or not validId(value.origin.recordId)) then return nil,'Invalid Bank origin.' end
  if value.mon.retroBankOrigin and (type(value.mon.retroBankOrigin)~='table' or not validId(value.mon.retroBankOrigin.recordId)) then return nil,'Invalid Pokémon origin.' end
  for _,origin in ipairs({value.source,value.origin or {},value.mon.retroBankOrigin or {}}) do
    if origin.version and not Versions.VERSIONS[origin.version] then return nil,'Unknown Bank origin game.' end
    for _,field in ipairs({'slot','place','saveId'}) do
      if origin[field]~=nil and (type(origin[field])~='string' or #origin[field]>160) then return nil,'Invalid Bank origin details.' end
    end
  end
  if value.mon.nickname~=nil and (type(value.mon.nickname)~='string' or #value.mon.nickname>160) then return nil,'Invalid Pokémon nickname.' end
  if id and (not validId(id) or hash(S.encode(value))~=id) then return nil,'Bank entry fingerprint does not match.' end
  return value
end
function B.makeEntry(mon,version,slot,place,data,save)
  local source={version=version,slot=slot,place=place,saveId=save and save.meta and save.meta.playthroughId,
    trainerId=mon.ot and (mon.ot.id or mon.ot.trainerId) or save and save.player and save.player.id}
  local origin=clone(mon.retroBankOrigin or source)
  if not origin.recordId then origin.recordId=hash(S.encode({source=source,species=mon.species,ot=mon.ot,personality=mon.personality,dvs=mon.dvs,ivs=mon.ivs})) end
  return {schema=1,source=source,origin=clone(origin),mon=clone(mon),canonical=canonical(mon,data)}
end
function B.deposit(mon,version,slot,place,data,save)
  data=data or B.data(version)
  if not data then return nil,'Source game data is unavailable.' end
  local value=B.makeEntry(mon,version,slot,place,data,save)
  return B.keep(value)
end
function B.keep(value)
  value=clone(value);value.id=nil
  local bytes=S.encode(value);local id=hash(bytes)
  local good,why=B.decode(bytes,id);if not good then return nil,why end
  local disk=fs();disk.createDirectory(B.DIRECTORY)
  local path=B.DIRECTORY..'/'..id..'.lua';local prior=disk.read(path)
  if prior then return prior==bytes and id or nil,'An entry fingerprint is already occupied.' end
  local ok,err=Safety.atomicWrite(disk,path,bytes,{decode=function(s) return B.decode(s,id) end})
  return ok and id or nil,err
end
function B.list()
  local out={};local disk=fs()
  for _,name in ipairs(disk.getDirectoryItems(B.DIRECTORY) or {}) do
    local id=name:match('^([a-f0-9]+)%.lua$')
    if validId(id) then
      local value=B.decode(disk.read(B.DIRECTORY..'/'..name),id)
      if value then value.id=id;out[#out+1]=value end
    end
  end
  table.sort(out,function(a,b) return a.id<b.id end);return out
end
local function named(registry,name)
  local found
  for id,def in pairs(registry) do
    if type(def)=='table' and key(def.name or id)==name then
      if found and found~=id then return nil end
      found=id
    end
  end
  return found
end
local function clamp(n,hi) return math.max(0,math.min(hi,math.floor(tonumber(n) or 0))) end
function B.convert(entry,version,data,allowAdaptation)
  if not Versions.VERSIONS[version] or type(entry)~='table' then return nil,'Unknown destination.' end
  local mon=clone(entry.mon);local info=entry.canonical or {};local original=mon.species
  local def=data.pokemon[original]
  if def and info.dex and (def.dex or def.nationalDex) and (def.dex or def.nationalDex)~=info.dex then def=nil end
  if not def and info.dex then
    for id,row in pairs(data.pokemon) do
      local dex=row.dex or row.nationalDex or tonumber(tostring(id):match('(%d+)$'))
      if dex==info.dex then mon.species=id;def=row;break end
    end
  end
  if not def then return nil,'Species '..tostring(original)..' is unavailable in this game.' end
  local gen=Versions.generation(version)
  if gen==1 and (mon.isEgg or mon.egg or (tonumber(mon.eggSteps) or 0)>0) then return nil,'Generation 1 cannot represent eggs.' end
  local origin=clone(entry.origin or mon.retroBankOrigin or entry.source)
  if not origin.recordId then origin.recordId=entry.id or hash(S.encode({source=entry.source,mon=entry.mon})) end
  mon.retroBankOrigin=clone(origin)
  local Items=require('src.storage.BankItems')
  local heldNote
  if mon.retroBankHeld and not mon.heldItem then
    local _,state=Items.returnable(mon.retroBankHeld)
    if state=='assigned' then
      mon.retroBankHeld=nil
      heldNote='The associated item is already assigned from your Item Bank; this copy travels without it.'
    end
  end
  if mon.heldItem and mon.heldItem~='' and (gen==1 or not data.items[mon.heldItem] and not named(data.items,info.item)) then
    local held=Items.custody(origin,mon.heldItem,info.item or key(mon.heldItem),entry.source.version)
    if not held then return nil,'Could not preserve the held-item identity.' end
    if mon.retroBankItem then held.id=mon.retroBankItem end
    mon.retroBankHeld=held;mon.retroBankItem=nil;mon.heldItem=nil
    heldNote='Held item goes into your Item Bank when this save copy is committed.'
  elseif not mon.heldItem and mon.retroBankHeld and gen>=2 and Items.returnable(mon.retroBankHeld) then
    local item=named(data.items,mon.retroBankHeld.canonical)
    if item then mon.heldItem=item;mon.retroBankItem=mon.retroBankHeld.id;mon.retroBankItemRecord=clone(mon.retroBankHeld);mon.retroBankHeld=nil end
  end
  local form=mon.form or mon.gen4Form
  if form~=nil and form~=0 and form~='base' and entry.source.version~=version then
    return nil,'This form cannot be transferred safely between these games.'
  end
  for i,move in ipairs(mon.moves) do
    if type(move)~='table' or (type(move.id)~='string' and type(move.id)~='number') then return nil,'Invalid move record.' end
    local id=data.moves[move.id] and move.id or named(data.moves,(info.moves[i] or {}).name)
    if not id then return nil,'Move '..tostring(move.id)..' is unavailable in this game.' end
    move.id=id;move.ppUps=clamp(move.ppUps,3)
    local pp=data.moves[id].pp
    if not tonumber(pp) then return nil,'Move PP data is unavailable.' end
    move.pp=clamp(move.pp,pp+move.ppUps*math.floor(pp/5))
  end
  if mon.heldItem and mon.heldItem~='' then
    local id=data.items[mon.heldItem] and mon.heldItem or named(data.items,info.item)
    if not id then return nil,'Held item '..tostring(mon.heldItem)..' is unavailable in this game.' end
    mon.heldItem=id
  end
  local modern=Stats.isGen3(def)
  local adapt=modern~=(type(mon.ivs)=='table')
  if adapt and not allowAdaptation then return nil,'This copy needs IV/DV and training adaptation for the destination generation.' end
  local note=heldNote
  if adapt then
    note=(note and note..' ' or '')..'IV/DV and training adapted; nature and ability follow the destination. The original remains in your Bank.'
    if modern then
      mon.ivs={};mon.evs={};local sum=0
      for _,stat in ipairs(Stats.ORDER_GEN3) do
        local old=(stat=='spatk' or stat=='spdef') and 'special' or stat
        mon.ivs[stat]=clamp((mon.dvs or {})[old],15)*2+1
        mon.evs[stat]=clamp(math.sqrt(clamp((mon.statExp or {})[old],65535)),252);sum=sum+mon.evs[stat]
      end
      if sum>510 then for stat,n in pairs(mon.evs) do mon.evs[stat]=math.floor(n*510/sum) end end
      mon.personality=0;mon.nature=(data.constants.natureOrder or {})[1]
      mon.abilitySlot=type(def.abilities)=='table' and def.abilities[1] and 1 or nil
      mon.dvs=nil;mon.statExp=nil
    else
      mon.dvs={};mon.statExp={}
      for _,stat in ipairs(Stats.ORDER) do
        local old=stat=='special' and 'spatk' or stat
        mon.dvs[stat]=math.floor(clamp((mon.ivs or {})[old],31)/2)
        mon.statExp[stat]=math.min(65535,clamp((mon.evs or {})[old],255)^2)
      end
      local d=mon.dvs;d.hp=(d.attack%2)*8+(d.defense%2)*4+(d.speed%2)*2+d.special%2
      mon.ivs=nil;mon.evs=nil;mon.personality=nil;mon.nature=nil;mon.abilitySlot=nil
    end
  end
  mon.stats=Stats.withNatures(data.constants and data.constants.natures,function()
    if modern then return Stats.calcGen3(def,mon.level,mon.ivs,mon.evs,mon.nature) end
    return Stats.calc(def,mon.level,mon.dvs or {},mon.statExp)
  end)
  mon.hp=clamp(mon.hp or mon.stats.hp,mon.stats.hp)
  return mon,note
end
function B.deliver(entries,version,slot,allowAdaptation,data)
  if #entries==0 then return nil,'Select Pokémon first.' end
  data=data or B.data(version);if not data then return nil,'Destination game data is unavailable.' end
  if Saves.slotOpenElsewhere(version,slot) then return nil,'Close this save in the running game before copying.' end
  local save,why=B.readSave(version,slot);if not save then return nil,why end
  local copy=clone(save);local count,capacity=shape(version,data)
  copy.boxes=clone(boxes(copy));copy.box=nil;copy.boxNames=copy.boxNames or {}
  local free={}
  for box=1,count do
    if copy.boxes[box] and copy.boxes[box].name then copy.boxNames[box]=copy.boxNames[box] or copy.boxes[box].name end
    copy.boxes[box]=clone(mons(copy.boxes[box]))
    for pos=1,capacity do if copy.boxes[box][pos]==nil then free[#free+1]={box,pos} end end
  end
  if #free<#entries then return nil,'Not enough empty PC slots. No save was changed.' end
  local converted={}
  for i,entry in ipairs(entries) do
    local mon,err=B.convert(entry,version,data,allowAdaptation)
    if not mon then return nil,err end
    converted[i]=mon
  end
  for i,mon in ipairs(converted) do local p=free[i];copy.boxes[p[1]][p[2]]=mon end
  local id,err=B.commitDraft(version,slot,copy);if not id then return nil,err end
  Saves.renameSlot(version,id,slot..' · Bank copy')
  return id
end
function B.commitDraft(version,slot,draft)
  if Saves.slotOpenElsewhere(version,slot) then return nil,'Close this save in the running game first.' end
  local bytes=S.encode(draft)
  if not Safety.decodeSave(bytes) then return nil,'The copied save is invalid.' end
  local custodyDraft=clone(draft);custodyDraft.version=version
  return require('src.storage.BankItems').transaction(custodyDraft,function()
    local id=Saves.createSlot(version);if not id then return nil,'Could not create a save slot.' end
    local ok,why=Saves.writeSlot(version,id,clone(draft));if not ok then return nil,why end
    Saves.renameSlot(version,id,slot..' · Bank copy');return id
  end)
end
B.boxes=boxes
B.boxMons=mons
B.shape=shape
function B.sync(target)
  local store=type(target)=='table' and target or require('src.import.CloudSync').folderStore(target)
  local localById={};local disk=fs();disk.createDirectory(B.DIRECTORY)
  for _,entry in ipairs(B.list()) do localById[entry.id]=true end
  local total=0
  for _,name in ipairs(store.list(B.DIRECTORY) or {}) do
    local id=name:match('^([a-f0-9]+)%.lua$')
    if validId(id) then
      local bytes=store.read(B.DIRECTORY..'/'..name)
      local value,why=B.decode(bytes,id);if not value then return nil,why end
      local prior=disk.read(B.DIRECTORY..'/'..name)
      if prior and prior~=bytes then return nil,'Conflicting Bank entry. Both copies are preserved.' end
      if not prior then
        local ok,err=Safety.atomicWrite(disk,B.DIRECTORY..'/'..name,bytes,{decode=function(s) return B.decode(s,id) end})
        if not ok then return nil,err end
      end
      localById[id]=nil;total=total+1
    end
  end
  for id in pairs(localById) do
    local path=B.DIRECTORY..'/'..id..'.lua'
    local ok,why=store.write(path,disk.read(path));if not ok then return nil,why end
    total=total+1
  end
  local items,why=require('src.storage.BankItems').sync(store);if not items then return nil,why end
  local dex,err=require('src.storage.GlobalPokedex').sync(store);if not dex then return nil,err end
  return total
end
return B
