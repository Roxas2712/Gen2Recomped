-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- GBA switch/item hook protocol. Its original result is a native handle:
-- mutations retain identity, whereas a fresh request needs fresh admission.
local Items = require("src.battle.Gen3TrainerItems")
local Party = require("src.pokemon.Party")
local Runtime = require("src.mods.Runtime")
local M = {}
local function position(battle, actor)
  return actor == battle.enemy and 1 or actor == battle.player and 0 or actor and actor.position
end
local function name(value)
  return type(value)=="string" and value:upper():gsub("[%s%-]+","_") or nil
end

function M.itemKey(battle, value)
  if type(value)~="number" and type(value)~="string" then return nil end
  local data = battle.data or {}
  if type(data.items and data.items[value])=="table" then return value end
  local number = tonumber(value)
  if number and (number~=number or number%1~=0 or number<=0 or number>65535) then return nil end
  local wanted, found, foundNumber = name(value)
  for key, def in pairs(data.items or {}) do
    if type(def)=="table" then
      local id = Items.itemNumber(battle,key)
      local canonical = type(key)=="string" and not key:match("^ITEM_%d+$") and key or def.name
      if number and id==number or not number and wanted and name(canonical)==wanted then
        if found and id~=foundNumber then return nil end
        local effects = data.constants and data.constants.gen3ItemEffects
        if found==nil or effects and effects[key] and not effects[found]
            or tostring(key)<tostring(found) and not (effects and effects[found]) then found=key end
        foundNumber=id
      end
    end
  end
  return found
end

local function partyEntries(battle)
  local entries={}
  for _,party in ipairs({battle.enemyParty or {},battle.enemyPartyB or {}}) do
    for index,mon in ipairs(party) do
      entries[#entries+1]={mon=mon,party=party,index=index}
    end
  end
  return entries
end
function M.slot(battle, actor, requested)
  local slot=math.floor(tonumber(requested) or 0)
  if slot<1 or slot>6 then return nil end
  local context=Items.context(battle,actor)
  local entry=partyEntries(battle)[slot]
  if not context or not entry or entry.party~=context.party or not entry.mon.species
      or entry.mon.species==0 or (tonumber(entry.mon.hp)or 0)<=0 or Party.isEgg(entry.mon) then return nil end
  local pending=battle.monToSwitchInto or {}
  for _,id in ipairs({1,3}) do
    local current=battle:battlerAt(id)
    if current and current.mon==entry.mon or pending[id]==slot then return nil end
  end
  return slot,entry
end

local function view(battle, actor, selected)
  if not selected then return nil end
  local id=position(battle,actor)
  local result
  if selected.special=="aiItem" then
    result={kind="item",item=Items.itemNumber(battle,selected.item),
      aiItemType=selected.aiItemType,aiItemFlags=selected.aiItemFlags or 0,
      user="enemy",battler=id,target=id}
  elseif selected.special=="aiSwitch" then
    result={kind="switch",slot=selected.portableSlot or selected.index,user="enemy",battler=id}
  else return nil end
  return result
end

function M.call(battle, actor, vanilla)
  if not Items.context(battle,actor) then return nil end
  local native
  local function selectNative()
    local selected
    if vanilla then selected=vanilla(battle,actor)
    else selected=Items.choose(battle,actor) end
    native=view(battle,actor,selected)
    return native or false
  end
  if not Runtime.wantsHook("battle.enemy_switch_or_item") then
    selectNative()
    return native
  end
  local chosen=Runtime.call("battle.enemy_switch_or_item",selectNative,battle)
  if chosen==true or native~=nil and chosen==native then return native end
  if type(chosen)~="table" then return nil end
  if chosen.kind=="switch" then
    local slot=M.slot(battle,actor,chosen.index or chosen.slot)
    if not slot then return nil end
    local id=position(battle,actor)
    battle.monToSwitchInto=battle.monToSwitchInto or {}
    battle.monToSwitchInto[id]=slot
    return view(battle,actor,{special="aiSwitch",portableSlot=slot})
  elseif chosen.kind=="item" then
    local item=M.itemKey(battle,chosen.item)
    return view(battle,actor,item and Items.stocked(battle,actor,item))
  end
end

return M
