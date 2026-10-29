-- Source Gen2 constructors accept an options record, while the shared
-- Pokemon constructor takes a two-bound RNG. Keep the actual native mon.
local Native=require('src.pokemon.Pokemon')
local M={}
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
