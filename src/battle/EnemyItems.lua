-- GBA trainer stock and battle-only item effects. Raw cartridge bytes are
-- authoritative; old caches retain only the medicine semantics they contain.
local ItemEffects = require("src.inventory.ItemEffects")
local Party = require("src.pokemon.Party")
local Strings = require("src.core.Strings")
local M = {}

local function bit(value, mask)
  return math.floor((tonumber(value) or 0) / mask) % 2 ~= 0
end

local function statusName(value)
  if value == nil or value == 0 then
    return nil
  end
  local name = tostring(value):upper()
  return ({
    SLEEP = "SLP",
    POISON = "PSN",
    TOXIC = "TOX",
    BURN = "BRN",
    FREEZE = "FRZ",
    PARALYSIS = "PAR",
    PARALYZE = "PAR",
  })[name] or name
end

local CURES = { [32] = "SLP", [16] = "PSN", [8] = "BRN", [4] = "FRZ", [2] = "PAR", [1] = "CONFUSION" }

function M.effect(battle, key)
  local record = ItemEffects.gen3RecordFor(key, battle.data)
  if type(record) ~= "table" then
    return nil
  end
  local item = (battle.data.items or {})[key] or {}
  local e, mask = record.bytes, 0
  if e ~= nil then
    if type(e) ~= "table" then
      return nil
    end
    for i = 1, 6 do
      if type(e[i]) ~= "number" or e[i] % 1 ~= 0 or e[i] < 0 or e[i] > 255 then
        return nil
      end
    end
    local hp
    if bit(e[5], 4) then
      -- Native GetItemEffectParamOffset tests the remaining mask before
      -- advancing the first parameter bit. A HEAL_HP request therefore
      -- returns the first argument even when EV bits also precede healing.
      -- Trainer AI and enemy use share this cartridge quirk; the parsed
      -- field-medicine amount is deliberately not substituted here.
      hp = e[7]
      if type(hp) ~= "number" or hp % 1 ~= 0 or hp < 0 or hp > 255 then
        return nil
      end
    end
    local kind = tonumber(item.index) == 19 and 1
      or bit(e[5], 4) and 2
      or e[4] % 64 ~= 0 and 3
      or (e[1] % 64 ~= 0 or e[2] ~= 0 or e[3] ~= 0) and 4
      or bit(e[4], 128) and 5
      or 6
    return { raw = e, kind = kind, hp = hp, cures = e[4] % 64 }
  end
  -- Do not invent X-item flags from a name or a generic `battle` boolean.
  if record.heal then
    local hp = ({ all = 255, half = 254 })[record.amount] or tonumber(record.amount) or 0
    return { kind = tonumber(item.index) == 19 and 1 or 2, hp = hp, legacy = true }
  end
  for flag, name in pairs(CURES) do
    local has = record.cureAll == true
    for _, cure in ipairs(record.cures or {}) do
      if cure == name then
        has = true
      end
    end
    if has then
      mask = mask + flag
    end
  end
  if mask ~= 0 then
    return { kind = 3, cures = mask, legacy = true }
  end
  return nil
end

function M.history(battle)
  if battle._enemyItemHistory then
    return battle._enemyItemHistory
  end
  local history = { items = {}, count = 0 }
  local stock = battle.trainer and battle.trainer.items or {}
  for slot = 1, 4 do
    local key = stock[slot]
    local def = key and (battle.data.items or {})[key]
    local numeric = tonumber(def and def.index) or tonumber(key)
    if key and numeric ~= 0 then
      history.count = history.count + 1
      history.items[history.count] = { key = key, slot = slot }
    end
  end
  battle._enemyItemHistory = history
  return history
end

local function action(battle, battler, row, effect, flags)
  battle.gen3ItemsUsed = battle.gen3ItemsUsed or {}
  battle.gen3ItemsUsed[row.slot] = true
  return {
    special = "aiItem",
    item = row.key,
    slot = row.slot,
    decisionBattler = battler,
    aiItemType = effect.kind,
    aiItemFlags = flags or 0,
  }
end

function M.reserve(battle, battler, key)
  if not key or not battler or (battler.position or 1) % 2 ~= 1 then
    return nil
  end
  local wanted = tonumber(((battle.data.items or {})[key] or {}).index) or tonumber(key)
  for _, row in ipairs(M.history(battle).items) do
    local physical = tonumber(((battle.data.items or {})[row.key] or {}).index) or tonumber(row.key)
    if (row.key == key or wanted and wanted == physical) and not (battle.gen3ItemsUsed or {})[row.slot] then
      local effect = M.effect(battle, row.key)
      if effect then
        return action(battle, battler, row, effect, 0)
      end
      return nil
    end
  end
end

function M.choose(battle, battler)
  if not battler or not battler.mon or (battler.position or 1) % 2 ~= 1 then
    return nil
  end
  local h, valid = M.history(battle), 0
  for i = 1, 6 do
    local mon = (battle.enemyParty or {})[i]
    if mon and (tonumber(mon.hp) or 0) ~= 0 and mon.species and mon.species ~= 0 and not Party.isEgg(mon) then
      valid = valid + 1
    end
  end
  local hp, max = battler.mon.hp or 0, battler.mon.stats.hp or 0
  local first = (tonumber(battler.turnsOut) or 0) < 2
  for i, row in ipairs(h.items) do
    if not (battle.gen3ItemsUsed or {})[row.slot] and not (i > 1 and valid > h.count - (i - 1) + 1) then
      local effect = M.effect(battle, row.key)
      if effect then
        local kind, e, flags, use = effect.kind, effect.raw, 0, false
        if kind == 1 then
          use = hp ~= 0 and hp < math.floor(max / 4)
        elseif kind == 2 then
          use = (effect.hp or 0) ~= 0 and hp ~= 0 and (hp < math.floor(max / 4) or max - hp > effect.hp)
        elseif kind == 3 then
          local status = statusName(battler.mon.status)
          if status == "TOX" then
            status = "PSN"
          end
          for flag, name in pairs(CURES) do
            if
              bit(effect.cures, flag)
              and (name == status or name == "CONFUSION" and (battler.confusedTurns or 0) > 0)
            then
              flags, use = flags + flag, true
            end
          end
        elseif kind == 4 and first then
          if e[1] % 16 ~= 0 then
            flags = flags + 1
          end
          if math.floor(e[2] / 16) ~= 0 then
            flags = flags + 2
          end
          if e[2] % 16 ~= 0 then
            flags = flags + 4
          end
          if e[3] % 16 ~= 0 then
            flags = flags + 8
          end
          if math.floor(e[3] / 16) ~= 0 then
            flags = flags + 32
          end
          if math.floor(e[1] / 16) % 4 ~= 0 then
            flags = flags + 128
          end
          use = true
        elseif kind == 5 then
          use = first and (battle:sideOf(battler).mistTurns or 0) == 0
        elseif kind == 6 then
          return nil
        end
        if use then
          return action(battle, battler, row, effect, flags)
        end
      end
    end
  end
end

function M.use(battle, battler, key, kind, flags)
  local effect = M.effect(battle, key)
  if not effect or not effect.raw then
    return nil
  end
  local e, mon = effect.raw, battler.mon
  -- These clears belong to using a trainer item, even if all its requested
  -- stat stages are capped or its healing cannot affect the current target.
  local ramp = (battle.data.moves or {})[battler.rampMove]
  if battler.rampMove == "FURY_CUTTER" or ramp and tonumber(ramp.index) == 210 then
    battler.rampRun, battler.rampMove = nil, nil
  end
  battler.destinyBond, battler.grudge = nil, nil
  if bit(e[1], 128) then
    battler.infatuated = nil
  end
  if math.floor(e[1] / 16) % 4 ~= 0 then
    battler.focusEnergy = true
  end
  local boosts = {
    attack = e[1] % 16,
    defense = math.floor(e[2] / 16),
    speed = e[2] % 16,
    accuracy = math.floor(e[3] / 16),
    spatk = e[3] % 16,
  }
  for stat, by in pairs(boosts) do
    if by > 0 then
      battler.stages[stat] = math.min(6, (battler.stages[stat] or 0) + by)
    end
  end
  local side = battle:sideOf(battler)
  if bit(e[4], 128) and (side.mistTurns or 0) == 0 then
    side.mistTurns = 5
  end
  local status = statusName(mon.status)
  if status == "TOX" then
    status = "PSN"
  end
  for flag, name in pairs(CURES) do
    if name == status and bit(effect.cures, flag) then
      if status == "SLP" then
        battler.nightmare = nil
      end
      mon.status, battler.toxicCounter, battler.sleepTurns = nil, nil, nil
      break
    end
  end
  if bit(effect.cures, 1) and (battler.confusedTurns or 0) > 0 then
    battler.confusedTurns = nil
  end
  if bit(e[5], 4) then
    local hp, max = mon.hp or 0, mon.stats.hp or 0
    if bit(e[5], 64) and hp == 0 or not bit(e[5], 64) and hp ~= 0 then
      local amount = effect.hp or 0
      if amount == 255 then
        amount = max - hp
      elseif amount == 254 then
        amount = math.max(1, math.floor(max / 2))
      elseif amount == 253 then
        amount = 0
      end
      if hp ~= max then
        mon.hp = math.min(max, hp + amount)
      end
    end
  end
  local item = (battle.data.items or {})[key] or {}
  local messages = { Strings("%s\nused %s!", battle.trainer.name, item.name or key) }
  kind, flags = kind or effect.kind, tonumber(flags) or 0
  if kind == 1 or kind == 2 then
    messages[#messages + 1] = Strings("%s's HP\nwas restored!", battler.name)
  elseif kind == 3 then
    messages[#messages + 1] = Strings("%s's\nstatus returned\nto normal!", battler.name)
  elseif kind == 4 then
    messages[#messages + 1] = bit(flags, 128) and Strings("%s is getting\npumped!", battler.name)
      or Strings("%s's\nstats rose!", battler.name)
  elseif kind == 5 then
    messages[#messages + 1] = Strings("%s's\nshrouded in mist!", battler.name)
  end
  require("src.core.Sound").play(battle.data, "Get_Item")
  return messages
end

function M.mistActive(battle, battler)
  local side = battle and battle.sideOf and battle:sideOf(battler)
  return side and (side.mistTurns or 0) > 0 or false
end

function M.tickSides(battle)
  for _, side in ipairs(battle.sides or {}) do
    if (side.mistTurns or 0) > 0 then
      side.mistTurns = side.mistTurns - 1
      if side.mistTurns == 0 then
        battle:sayNext(Strings("The MIST\nwore off!"))
      end
    end
  end
end

return M
