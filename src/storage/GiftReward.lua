-- Materialize a server-issued gift using this cartridge's native definitions.
local G={POOL='native-gifts-v1'}
local S=require('src.core.SaveSerializer')
local function key(value) return tostring(value or ''):upper():gsub('[^A-Z0-9]','') end
function G.build(entry,species,data,version)
 local o=entry.origin or {};local gen=require('src.core.GameVersion').generation(version)
 if o.kind~='retrorecomp_gift' or o.pool~=G.POOL or type(o.generation)~='number' or o.generation<1 or o.generation>5
  or o.generation~=require('src.core.GameVersion').generation(entry.source.version)
  or type(o.shiny)~='boolean' or type(o.isEgg)~='boolean' or o.generation==1 and (o.shiny or o.isEgg) then
  return nil,'Invalid gift receipt or generation.'
 end
 if gen==1 and o.isEgg then return nil,'Generation 1 cannot represent eggs. Keep this gift in your Bank.' end
 local copy=S.decode(S.encode(entry));copy.origin.kind='retrorecomp_wonder';copy.origin.pool=require('src.storage.WonderReward').POOL
 local mon,why=require('src.storage.WonderReward').build(copy,species,data);if not mon then return nil,why end
 local state=tonumber(o.seed:sub(8,14),16)%2147483646+1
 local function rng(lo,hi) state=state*48271%2147483647;return lo+state%(hi-lo+1) end
 local reward=o.reward or {}
 if reward.preset then
  local Ev=require('src.pokewalker.WalkerEvents');local ev=Ev.get(reward.preset);local supported=false
  for _,v in ipairs(ev and ev.games or {}) do if v==version then supported=true end end
  if not ev or ev.kind~='mon' or not supported then return nil,'This historical template is unavailable in this edition.' end
  for _,name in ipairs(ev.mon.moves or {}) do
   local id,problem=require('src.storage.GiftPokemon').nativeKey(data.moves,key(name))
   if not id then return nil,problem end
  end
  for _,name in ipairs({ev.mon.item,ev.mon.ball}) do
   local id,problem=require('src.storage.GiftPokemon').nativeKey(data.items,key(name))
   if not id then return nil,problem end
  end
  local oldRandom=math.random
  math.random=function(a,b) if a==nil then return rng(0,2147483646)/2147483647 end;return b and rng(a,b) or rng(1,a) end
  local ok,built,problem=pcall(Ev.buildMon,data,{player={name='RetroRecomp',id=2712,secretId=0}},ev,version)
  math.random=oldRandom
  if not ok or not built then return nil,ok and problem or tostring(built) end
  local year,month,day=tostring(o.claim_date or '2000-01-01'):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
  built.metDate={year=tonumber(year),month=tonumber(month),day=tonumber(day)};built.heldItem=built.item
  return built
 end
 local edited,problem=require('src.storage.GiftPokemon').apply(mon,entry,data,version,rng)
 if not edited then return nil,problem end;mon=edited
 if #entry.canonical.moves>0 then
  if #entry.canonical.moves>4 then return nil,'Too many gift moves.' end
  mon.moves={}
  for _,move in ipairs(entry.canonical.moves) do
   if type(move)~='table' or type(move.name)~='string' or not move.name:match('^[A-Z][A-Z0-9]*$') then return nil,'Invalid gift move.' end
   local found
   for id,record in pairs(data.moves) do if key(record.name or id)==move.name then
    if found and found~=id then return nil,'Gift move is ambiguous in this game.' end;found=id
   end end
   local record=found and data.moves[found]
   if not record or not tonumber(record.pp) then return nil,'Special gift move '..move.name..' is unavailable in this game.' end
   mon.moves[#mon.moves+1]={id=found,pp=record.pp,ppUps=0}
  end
 end
 if o.isEgg then
  mon.level=gen>=4 and 1 or 5
  mon.exp=require('src.pokemon.Growth').withTables((data.constants or {}).experienceTables,function()
   return require('src.pokemon.Growth').expForLevel(data.pokemon[species].growthRate,mon.level)
  end)
  mon.eggSteps=math.max(1,tonumber(data.pokemon[species].eggCycles) or 20)*256
 end
 return mon
end
return G
