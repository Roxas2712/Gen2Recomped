-- Original Ruby/Sapphire field_control_avatar.c and wild_encounter.c rules.
-- Counters belong to the live field, never to a saved party or encounter table.
local M={}
function M.active()
  local v=require('src.core.GameVersion').get();return v=='ruby'or v=='sapphire'
end
function M.restart(world,fresh)
  world.rsEncounterImmunity=0
  world.rsEncounterChecked=world.rsEncounterSerial or 0
  if fresh then world.rsEncounterPrevious=0 end
end
function M.stepped(world)
  world.rsEncounterSerial=(world.rsEncounterSerial or 0)+1
end
function M.begin(world)
  local serial=world.rsEncounterSerial or 0
  if serial==(world.rsEncounterChecked or 0)then return false end
  world.rsEncounterChecked=serial
  local p=world.player
  local current=world.map:cellBehaviour(p.cellX,p.cellY)or 0
  world.rsEncounterPrior=world.rsEncounterPrevious or 0
  world.rsEncounterCurrent,world.rsEncounterPrevious=current,current
  local n=world.rsEncounterImmunity or 0
  if n<4 then world.rsEncounterImmunity=n+1;return false end
  return true
end
function M.rateMod(data,save,base,cycling)
  base=tonumber(base)or 0;if base<=0 then return nil end
  local raw=base*16;local rate=raw
  if cycling then rate=math.floor(rate*80/100)end
  if save.gen3Flute=='white'then rate=rate+math.floor(rate/2)
  elseif save.gen3Flute=='black'then rate=math.floor(rate/2)end
  local lead=(save.party or{})[1]
  if lead and lead.item=='CLEANSE_TAG'then rate=math.floor(rate*2/3)end
  if lead and not require('src.pokemon.Party').isEgg(lead)then
    local ability=require('src.battle.Abilities').of({mon=lead,def=(data.pokemon or{})[lead.species]})
    if ability=='STENCH'then rate=math.floor(rate/2)
    elseif ability=='ILLUMINATE'then rate=rate*2 end
  end
  rate=math.min(2880,rate)
  if rate~=raw then return{rate,raw}end
end
-- Keep public hook inputs in the imported rate units (out of 180). Only
-- the private roll view expands them to the cartridge's 2880-point scale.
function M.roll(def,rng,rateMod,rateOverride,previous,current)
  local original=def and def.grass
  if not original or original.rate==0 then return nil end
  rng=rng or love.math.random
  if previous~=current and rng(0,99)>=60 then return nil end
  local grass={};for k,v in pairs(original)do grass[k]=v end
  grass.rate,grass.rateMax=original.rate*16,2880
  return require('src.world.Encounter').roll({grass=grass},rng,rateMod,
    rateOverride and rateOverride*16 or nil)
end
return M
