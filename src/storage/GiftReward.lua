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
 local Stats=require('src.pokemon.Stats')
 if o.shiny then
  if mon.personality then
   local state=tonumber(o.seed:sub(8,14),16)%2147483646+1
   local function rng(lo,hi) state=state*48271%2147483647;return lo+state%(hi-lo+1) end
   mon.personality=Stats.shinyPersonality(mon.personality,mon.otId,rng)
   mon.nature=((data.constants or {}).natureOrder or {})[mon.personality%25+1]
  else mon.dvs={attack=14,defense=10,speed=10,special=10,hp=0} end
  mon.shiny=true;mon.isShiny=true
 end
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
