-- Source Gen2 constructors accept an options record, while the shared
-- Pokemon constructor takes a two-bound RNG. Keep the actual native mon.
local Native=require('src.pokemon.Pokemon')
local M={}
local Progression=require('src.pokemon.Gen2Progression')
for _,key in ipairs{'MAX_LEVEL','MAX_STAT_EXP','STAT_EXP_ORDER','newStatExp','gainStatExp',
 'experienceGain','partySpecies','writeStats','gainExperience'}do M[key]=Progression[key]end
local Growth=require('src.pokemon.Growth')
M.growthFor=Growth.record
M.experienceForLevel=Growth.evaluate
M.levelForExperience=Growth.sourceLevel
M.registerInto=Growth.registerCoefficients
local Caught=require('src.pokemon.Gen2CaughtData')
for _,key in ipairs{'CAUGHT_TIME_MASK','CAUGHT_LEVEL_MASK','CAUGHT_GENDER_MASK',
 'CAUGHT_LOCATION_MASK','CAUGHT_EGG_LEVEL','LANDMARK_EVENT','LANDMARK_GIFT',
 'CAUGHT_BY','hasCaughtData','caughtTimeOf','caughtGenderOf','setCaughtData',
 'setGiftCaughtData','packCaughtData','unpackCaughtData'}do M[key]=Caught[key]end
local function identity()return require('src.pokemon.IdentityRolls')end
function M.vanillaShiny(dvs)return identity().gen2VanillaShiny(dvs)end
function M.isShiny(dvs,context)return identity().gen2GeneShiny(dvs,context)end
function M.vanillaGender(def,dvs)return identity().gen2VanillaGender(def,dvs)end
function M.gender(def,dvs,context)return identity().gen2GeneGender(def,dvs,context)end
function M.randomDVs()
  local random=love and love.math and love.math.random or math.random
  local dvs=require('src.pokemon.Stats').randomDVs(random)
  dvs.hp=nil -- Source birth derives HP later, after any authored gene edits.
  return dvs
end
local PP=require('src.pokemon.Gen2PP')
function M.ppUpsOf(move,data)return PP.ups(data and data.moves and type(move)=='table' and data.moves[move.id],move)end
function M.maxPpOf(move,data)return PP.forSlot(move,data and data.moves)end
function M.partyMoves(mon)return PP.partyMoves(mon)end
function M.restoreAllPp(mon,data)return PP.restore(mon,data and data.moves)end
function M.repairMoves(mon,data)return PP.repair(mon,data and data.moves)end
function M.hpDV(dvs)return require('src.pokemon.Stats').hpDV(dvs)end
function M.stats(base,dvs,level,statExp)
  return require('src.pokemon.Stats').calcGen2(base,dvs,level,statExp)
end
-- Source signatures put the Pokemon first; the native owner takes data first.
function M.syncIdentity(mon,data)return Native.syncIdentity(data,mon)end
function M.refreshStats(mon,data)return Native.refreshStats(data,mon)end
function M.new(data,id,level,opts)
  if type(opts)~='table' then return Native.new(data,id,level,opts) end
  local rng=opts.rng or love.math.random
  local keys={'attack','defense','speed','special'}
  local draws=0
  local function seeded(lo,hi)
    draws=draws+1
    local value=opts.dvs and keys[draws] and opts.dvs[keys[draws]]
    if value~=nil then return value end
    return rng(lo,hi)
  end
  local mon=Native.new(data,id,level,seeded,nil,opts)
  if opts.statExp then
    mon.statExp={};for key,value in pairs(opts.statExp)do mon.statExp[key]=value end
    mon.stats=require('src.pokemon.Stats').calc(data.pokemon[mon.species],level,mon.dvs,mon.statExp)
    mon.hp=mon.stats.hp
  end
  if opts.moves then
    mon.moves={}
    for _,move in ipairs(opts.moves)do
      local slot={}
      if type(move)=='table' then for key,value in pairs(move)do slot[key]=value end
      else slot.id=move end
      if slot.pp==nil then slot.pp=Native.maxPP(data.moves[slot.id],slot,2) end
      mon.moves[#mon.moves+1]=slot
    end
  end
  mon.item=opts.item
  return mon
end
function M.movesAtLevel(def,level,moves)
  local ids=Native.movesAtLevel(def,level)
  if not moves then return ids end
  local out={};for _,id in ipairs(ids)do out[#out+1]={id=id,pp=Native.maxPP(moves[id],nil,2)}end
  return out
end
function M.stampOT(save,mon)
  return require('src.battle.BattleState').stampOT(save,mon)
end
return setmetatable(M,{__index=Native})
