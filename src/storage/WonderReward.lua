-- Deterministic materialization of a server-issued system encounter using
-- only the destination cartridge's native species, learnset and stat data.
local R={POOL='native-national-1-649-v1'}
function R.build(entry,species,data)
  local o=entry.origin or {}
  if o.kind~='retrorecomp_wonder' then return nil,'Not a system encounter.' end
  if o.pool~=R.POOL or type(o.seed)~='string' or #o.seed~=64 or not o.seed:match('^[a-f0-9]+$')
    or entry.mon.ot~='RetroRecomp' or type(entry.canonical.dex)~='number' or entry.canonical.dex%1~=0 or entry.canonical.dex<1 or entry.canonical.dex>649 then
    return nil,'The system encounter receipt is invalid.'
  end
  local def=data.pokemon[species];if not def then return nil,'This species is unavailable in this cartridge.' end
  local state=tonumber(o.seed:sub(1,7),16)%2147483646+1
  local function rng(lo,hi) state=state*48271%2147483647;return lo+state%(hi-lo+1) end
  local Stats=require('src.pokemon.Stats');local Growth=require('src.pokemon.Growth')
  local mon={species=species,level=entry.mon.level,moves={},ot='RetroRecomp',otId=2712,gen3OtName='RetroRecomp',
    statExp={hp=0,attack=0,defense=0,speed=0,special=0},catchRate=def.catchRate,happiness=def.baseFriendship or def.friendship or 70}
  if Stats.isGen3(def) then
    mon.ivs=Stats.randomIVs(rng);mon.evs={hp=0,attack=0,defense=0,speed=0,spatk=0,spdef=0}
    mon.personality=rng(0,65535)*65536+rng(0,65535)
    mon.nature=((data.constants or {}).natureOrder or {})[mon.personality%25+1]
    mon.abilitySlot=def.abilities and (def.abilities[2] and mon.personality%2+1 or def.abilities[1] and 1 or nil)
  else mon.dvs=Stats.randomDVs(rng) end
  mon.exp=Growth.withTables((data.constants or {}).experienceTables,function() return Growth.expForLevel(def.growthRate,mon.level) end)
  if type(def.level1Moves)~='table' or type(def.learnset)~='table' then return nil,'The native learnset is incomplete.' end
  for _,id in ipairs(require('src.pokemon.Pokemon').movesAtLevel(def,mon.level)) do
    local move=data.moves[id];if not move or not tonumber(move.pp) then return nil,'A native starting move is unavailable.' end
    mon.moves[#mon.moves+1]={id=id,pp=move.pp,ppUps=0}
  end
  if #mon.moves==0 then return nil,'This native species has no usable starting moves.' end
  return mon
end
return R
