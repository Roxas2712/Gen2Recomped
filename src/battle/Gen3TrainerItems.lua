-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native GBA trainer items: selection spends a slot, execution owns a battler.
-- The shared hook must not turn a selected/spent item into a second bag use.
-- gBattleHistory has one opposing bag, including two-opponent battles; party
-- ownership and the active item recipient remain separate from that bag.
local Party = require("src.pokemon.Party")
local M = {}
M.TYPE = { FULL_RESTORE = 1, HEAL_HP = 2, CURE_CONDITION = 3,
  X_STAT = 4, GUARD_SPECS = 5, NOT_RECOGNIZABLE = 6 }

local function bit(value, flag) return math.floor(value / flag) % 2 == 1 end
local function healthy(mon)
  return type(mon) == "table" and (tonumber(mon.hp) or 0) > 0 and not Party.isEgg(mon)
end

function M.context(battle, actor)
  actor = actor or battle.enemy
  if not (actor and actor.mon) or actor.isPlayer then return nil end
  local position = actor.position
  if position == nil and actor == battle.enemy then position = 1 end
  if position ~= 1 and position ~= 3 then return nil end
  if battle.battlerAt and battle:battlerAt(position) ~= actor then return nil end
  local second = position == 3 and battle.trainerB and battle.enemyPartyB
  local trainer = second and battle.trainerB or battle.trainer
  local party = second and battle.enemyPartyB or battle.enemyParty
  if not (trainer and type(party) == "table") then return nil end
  local index
  for i, mon in ipairs(party) do if mon == actor.mon then index = i; break end end
  if not index then return nil end
  return { owner = second and "B" or "A", position = position, actor = actor,
    trainer = trainer, party = party, index = index }
end

local function itemNumber(battle, key)
  local def = battle.data and battle.data.items and battle.data.items[key]
  local number = def and (def.index or def.numId)
  if number == nil then number = tonumber(key) end
  if number == nil and type(key) == "string" then number = tonumber(key:match("^ITEM_(%d+)$")) end
  return type(number) == "number" and number == number and number % 1 == 0
    and number > 0 and number <= 65535 and number or nil
end
M.itemNumber = itemNumber

function M.effect(battle, key)
  local records = battle.data and battle.data.constants and battle.data.constants.gen3ItemEffects
  local record = records and records[key]
  local bytes = record and record.bytes
  if type(bytes) ~= "table" or #bytes < 6 then return nil end
  local e = {}
  for i = 1, #bytes do
    local value = bytes[i]
    if type(value) ~= "number" or value % 1 ~= 0 or value < 0 or value > 255 then return nil end
    e[i] = value
  end
  -- The two EV parameters precede the HP parameter in GetItemEffectParamOffset.
  e.hp = bit(e[5], 4) and (e[7 + e[5] % 2 + math.floor(e[5] / 2) % 2] or 0) or 0
  local T = M.TYPE
  if itemNumber(battle, key) == 19 then e.kind = T.FULL_RESTORE
  elseif bit(e[5], 4) then e.kind = T.HEAL_HP
  elseif e[4] % 64 ~= 0 then e.kind = T.CURE_CONDITION
  elseif e[1] % 64 ~= 0 or e[2] ~= 0 or e[3] ~= 0 then e.kind = T.X_STAT
  elseif bit(e[4], 128) then e.kind = T.GUARD_SPECS
  else e.kind = T.NOT_RECOGNIZABLE end
  return e
end

local function bags(battle)
  battle._gen3TrainerItems = battle._gen3TrainerItems or { reservations = {}, nextId = 0 }
  return battle._gen3TrainerItems
end

function M.history(battle, context)
  local state = bags(battle)
  local h = state.history
  if h then return h end
  h = { slots = {}, count = 0 }
  state.history = h
  local used = battle.gen3ItemsUsed
  for original = 1, 4 do
    local key = battle.trainer and battle.trainer.items and battle.trainer.items[original]
    if itemNumber(battle, key) then
      h.count = h.count + 1
      h.slots[h.count] = { item = key, original = original, spent = used and used[original] == true or false }
    end
  end
  return h
end

local function reserve(battle, context, slot, effect, flags)
  if slot.spent then return nil end
  slot.spent = true
  battle.gen3ItemsUsed = battle.gen3ItemsUsed or {}
  battle.gen3ItemsUsed[slot.original] = true
  local state = bags(battle)
  state.nextId = state.nextId + 1
  state.reservations[state.nextId] = { actor = context.actor, owner = context.owner,
    position = context.position, item = slot.item, effect = effect, executed = false }
  return { special = "aiItem", item = slot.item, slot = slot.original,
    aiItemType = effect.kind, aiItemFlags = flags, battler = context.position,
    target = context.position, trainerItemReservation = state.nextId }
end

function M.stocked(battle, actor, key)
  local context = M.context(battle, actor)
  local number = itemNumber(battle, key)
  if not context or not number then return nil end
  for _, slot in ipairs(M.history(battle, context).slots) do
    if itemNumber(battle, slot.item) == number and not slot.spent then
      local effect = M.effect(battle, slot.item)
      if effect then return reserve(battle, context, slot, effect, 0) end
    end
  end
end

local statusNames = { sleep = "SLP", poison = "PSN", toxic = "TOX", burn = "BRN",
  freeze = "FRZ", paralysis = "PAR", paralyze = "PAR" }
local function decision(battle, context, e)
  local actor, mon, T = context.actor, context.actor.mon, M.TYPE
  local hp = tonumber(mon.hp) or 0
  local maxHp = tonumber(mon.stats and mon.stats.hp) or tonumber(mon.maxHp) or 0
  if e.kind == T.FULL_RESTORE then return hp > 0 and hp < math.floor(maxHp / 4), 0 end
  if e.kind == T.HEAL_HP then
    return e.hp ~= 0 and hp > 0 and (hp < math.floor(maxHp / 4) or maxHp - hp > e.hp), 0
  end
  if e.kind == T.CURE_CONDITION then
    local status = statusNames[mon.status] or mon.status
    local flags = 0
    if bit(e[4], 32) and status == "SLP" then flags = flags + 32 end
    if bit(e[4], 16) and (status == "PSN" or status == "TOX") then flags = flags + 16 end
    if bit(e[4], 8) and status == "BRN" then flags = flags + 8 end
    if bit(e[4], 4) and status == "FRZ" then flags = flags + 4 end
    if bit(e[4], 2) and status == "PAR" then flags = flags + 2 end
    if bit(e[4], 1) and (tonumber(actor.confusedTurns) or 0) > 0 then flags = flags + 1 end
    return flags ~= 0, flags
  end
  if e.kind == T.X_STAT then
    if (tonumber(actor.turnsOut) or 0) ~= 0 then return false, 0 end
    local flags = 0
    if e[1] % 16 ~= 0 then flags = flags + 1 end
    if math.floor(e[2] / 16) ~= 0 then flags = flags + 2 end
    if e[2] % 16 ~= 0 then flags = flags + 4 end
    if e[3] % 16 ~= 0 then flags = flags + 8 end
    if math.floor(e[3] / 16) ~= 0 then flags = flags + 32 end
    if math.floor(e[1] / 16) % 4 ~= 0 then flags = flags + 128 end
    return true, flags
  end
  if e.kind == T.GUARD_SPECS then
    local side = battle.sides and battle.sides[2]
    return (tonumber(actor.turnsOut) or 0) == 0 and (tonumber(side and side.gen3MistTurns) or 0) == 0, 0
  end
  return false, 0
end

function M.choose(battle, actor)
  local context = M.context(battle, actor)
  if not context or not healthy(context.actor.mon) then return nil end
  local h, valid = M.history(battle, context), 0
  local party = battle.foeSummaryParty and battle:foeSummaryParty() or battle.enemyParty or {}
  for index = 1, 6 do if healthy(party[index]) then valid = valid + 1 end end
  for index, slot in ipairs(h.slots) do
    local i = index - 1
    if not slot.spent and not (i > 0 and valid > (h.count - i) + 1) then
      local effect = M.effect(battle, slot.item)
      if effect then
        if effect.kind == M.TYPE.NOT_RECOGNIZABLE then return nil end
        local use, flags = decision(battle, context, effect)
        if use then return reserve(battle, context, slot, effect, flags) end
      end
    end
  end
end

-- Execution may consume this reservation once, for its originally selected
-- actor. Public hook/action adapters still need to define mutation handling.
function M.claim(battle, actor, action)
  if type(action) ~= "table" then return nil end
  local state = battle._gen3TrainerItems
  local reservation = state and state.reservations[action.trainerItemReservation]
  if not reservation or reservation.executed or reservation.actor ~= actor then return nil end
  local context = M.context(battle, actor)
  if not context or context.owner ~= reservation.owner then return nil end
  reservation.executed = true
  return reservation
end

return M
