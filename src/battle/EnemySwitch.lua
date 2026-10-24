-- Native GBA trainer switch policy, expressed in this host's battler and
-- cartridge-derived type records. Selection is separate from execution.
local Abilities = require("src.battle.Abilities")
local TypeChart = require("src.battle.TypeChart")
local M = {}

local function distinct(types)
  local out, seen = {}, {}
  for _, value in ipairs(types or {}) do
    if not seen[value] then
      out[#out + 1], seen[value] = value, true
    end
  end
  return out
end

local function typesOf(battle, mon)
  return ((battle.data.pokemon or {})[mon.species] or {}).types or mon.types or {}
end

local function abilityOf(battle, mon)
  return Abilities.of({ mon = mon, def = (battle.data.pokemon or {})[mon.species] })
end

local function moveOf(battle, slot)
  return (battle.data.moves or {})[type(slot) == "table" and slot.id or slot]
end

-- AI flags cancel an opposing resistance/weakness, preserve immunities, and
-- normally ignore status moves. The candidate picker deliberately uses the
-- type-only calculation instead, including status moves and per-row rounding.
local function typeResult(kind, types, damage, damaging)
  local flags = { super = false, notVery = false, noEffect = false }
  for _, mult in ipairs(TypeChart.rows(kind, distinct(types))) do
    if damage then
      damage = math.floor(damage * mult / 10)
      if damage == 0 and mult ~= 0 then
        damage = 1
      end
    end
    if mult == 0 then
      flags.noEffect, flags.super, flags.notVery = true, false, false
    elseif damaging and not flags.noEffect then
      if mult == 5 then
        if flags.super then
          flags.super = false
        else
          flags.notVery = true
        end
      elseif mult == 20 then
        if flags.notVery then
          flags.notVery = false
        else
          flags.super = true
        end
      end
    end
  end
  return flags, damage
end

function M.flags(battle, move, mon, ability)
  local flags = { super = false, notVery = false, noEffect = false }
  if not move or tonumber(move.index) == 165 then
    return flags
  end
  if ability == "LEVITATE" and Abilities.normalizeType(move.type) == "GROUND" then
    flags.noEffect = true
  else
    flags = typeResult(move.type, typesOf(battle, mon), nil, (tonumber(move.power) or 0) ~= 0)
  end
  if ability == "WONDER_GUARD" and not flags.super and (tonumber(move.power) or 0) ~= 0 then
    flags.noEffect = true
  end
  return flags
end

local function hasSuper(battle, user, noRng)
  for _, id in ipairs(battle.double and { 0, 2 } or { 0 }) do
    local opponent = battle:battlerAt(id)
    if opponent then
      for i = 1, 4 do
        local move = moveOf(battle, user.mon.moves and user.mon.moves[i])
        if
          M.flags(battle, move, opponent.mon, Abilities.of(opponent)).super
          and (noRng or battle.rng(0, 9) ~= 0)
        then
          return true
        end
      end
    end
  end
  return false
end

function M.candidate(battle, user, valid)
  local party = battle:benchFor(false, user.position)
  local reserved = (battle._enemySwitchReservations or {})[user]
  if reserved then
    for i, mon in ipairs(party) do
      if mon == reserved then
        return i
      end
    end
  end
  local opponent = battle:battlerAt((user.position or 1) - 1)
  if battle.double then
    local id = (math.floor(battle.rng(0, 65535) / 2) % 2) * 2
    opponent = battle:battlerAt(id) or battle:battlerAt(id == 0 and 2 or 0)
  end
  if not opponent then
    return nil
  end
  local omitted = {}
  while true do
    local score, pick = 0, nil
    for i = 1, 6 do
      if not omitted[i] and valid(battle, user, i, true) then
        local types, value = typesOf(battle, party[i]), 10
        local incoming = opponent.curTypes or typesOf(battle, opponent.mon)
        for _, kind in ipairs({ incoming[1], incoming[2] or incoming[1] }) do
          for _, mult in ipairs(TypeChart.rows(kind, distinct(types))) do
            value = math.floor(value * mult / 10)
          end
        end
        if value > score then
          score, pick = value, i
        end
      end
    end
    if not pick then
      break
    end
    for j = 1, 4 do
      local move = moveOf(battle, party[pick].moves and party[pick].moves[j])
      if move and typeResult(move.type, opponent.curTypes, nil, true).super then
        return pick
      end
    end
    omitted[pick] = true
  end
  local score, pick = 0, nil
  for i = 1, 6 do
    if valid(battle, user, i, true) then
      for j = 1, 4 do
        local move = moveOf(battle, party[i].moves and party[i].moves[j])
        if move and (tonumber(move.power) or 0) ~= 1 then
          local damage = 2
          for _, kind in ipairs(distinct(user.curTypes)) do
            if kind == move.type then
              damage = 3
              break
            end
          end
          local _, value = typeResult(move.type, opponent.curTypes, damage, true)
          if value > score then
            score, pick = value, i
          end
        end
      end
    end
  end
  return pick
end

function M.choose(battle, user, valid)
  if not user or not user.mon then
    return nil
  end
  if user.trapped or user.escapePrevention or (tonumber(user.boundTurns) or 0) > 0 or user.ingrained then
    return nil
  end
  for id = 0, battle.double and 3 or 1 do
    local other = battle:battlerAt(id)
    local ability = Abilities.of(other)
    if id % 2 == 0 and (ability == "SHADOW_TAG" or ability == "ARENA_TRAP") then
      return nil
    end
    if ability == "MAGNET_PULL" then
      for _, kind in ipairs(user.curTypes or {}) do
        if kind == "STEEL" then
          return nil
        end
      end
    end
  end
  local available, party = {}, battle:benchFor(false, user.position)
  for i = 1, 6 do
    if valid(battle, user, i, true) then
      available[#available + 1] = i
    end
  end
  if #available == 0 then
    return nil
  end
  local function unspecified()
    return M.candidate(battle, user, valid) or available[1]
  end
  if user.perishTurns == 0 then
    return unspecified()
  end
  local opponent = battle.player
  if
    not battle.double
    and opponent
    and Abilities.of(opponent) == "WONDER_GUARD"
    and not hasSuper(battle, user, true)
  then
    for _, i in ipairs(available) do
      for j = 1, 4 do
        local move = moveOf(battle, party[i].moves and party[i].moves[j])
        if M.flags(battle, move, opponent.mon, Abilities.of(opponent)).super and battle.rng(0, 2) < 2 then
          return i
        end
      end
    end
  end
  local last = moveOf(battle, user._gbaLastLandedMove)
  local lastId = user._gbaLastLandedMove
  local super = hasSuper(battle, user, true)
  if not (super and battle.rng(0, 2) ~= 0) and last and (tonumber(last.power) or 0) ~= 0 then
    local absorb = ({ FIRE = "FLASH_FIRE", WATER = "WATER_ABSORB", ELECTRIC = "VOLT_ABSORB" })[Abilities.normalizeType(
      last.type
    )]
    if absorb and Abilities.of(user) ~= absorb then
      for _, i in ipairs(available) do
        if abilityOf(battle, party[i]) == absorb and battle.rng(0, 1) == 1 then
          return i
        end
      end
    end
  end
  local function counter(flag, modulo)
    local attacker = user._gbaLastHitById and battle:battlerAt(user._gbaLastHitById)
    if not last or (tonumber(last.power) or 0) == 0 or not attacker then
      return nil
    end
    for _, i in ipairs(available) do
      if M.flags(battle, last, party[i], abilityOf(battle, party[i]))[flag] then
        for j = 1, 4 do
          local move = moveOf(battle, party[i].moves and party[i].moves[j])
          if
            M.flags(battle, move, attacker.mon, Abilities.of(attacker)).super
            and battle.rng(0, modulo - 1) == 0
          then
            return i
          end
        end
      end
    end
  end
  local status = user.mon.status
  if
    (status == "sleep" or status == "SLP")
    and Abilities.of(user) == "NATURAL_CURE"
    and user.mon.hp >= math.floor(user.mon.stats.hp / 2)
  then
    if (not lastId or lastId == 0 or lastId == 65535) and battle.rng(0, 1) == 1 then
      return unspecified()
    elseif (not last or (tonumber(last.power) or 0) == 0) and battle.rng(0, 1) == 1 then
      return unspecified()
    end
    local index = counter("noEffect", 1) or counter("notVery", 1)
    if index then
      return index
    end
    if battle.rng(0, 1) == 1 then
      return unspecified()
    end
  end
  if hasSuper(battle, user, false) then
    return nil
  end
  local raised = 0
  for _, value in pairs(user.stages or {}) do
    raised = raised + math.max(0, tonumber(value) or 0)
  end
  if raised > 3 then
    return nil
  end
  return counter("noEffect", 2) or counter("notVery", 3)
end

return M
