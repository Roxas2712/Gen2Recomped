-- The shared hook has two native contracts: Gen 2 executes inside the
-- query and returns a boolean; GBA reserves stock and returns an action.
local Runtime = require("src.mods.Runtime")
local TrainerAI = require("src.battle.TrainerAI")
local M = {}

local function slug(value)
  return type(value) == "string" and value:upper():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "") or nil
end

function M.itemKey(data, ref)
  local items = data and data.items or {}
  if items[ref] then
    return ref
  end
  local number, name, found = tonumber(ref), slug(ref), nil
  for key, row in pairs(items) do
    if
      type(row) == "table"
      and (
        number and tonumber(row.index) == number
        or name and (slug(row.key) == name or slug(row.name) == name)
      )
    then
      if
        found
        and items[found] ~= row
        and (not tonumber(row.index) or tonumber(items[found].index) ~= tonumber(row.index))
      then
        return nil
      end
      found = key
    end
  end
  return found
end

local function itemNumber(battle, key)
  local def = (battle.data.items or {})[key]
  return tonumber(def and def.index) or tonumber(key)
end

local function effectItemKey(battle, ref)
  local key = M.itemKey(battle.data, ref)
  local effects = battle.data.constants and battle.data.constants.gen3ItemEffects or {}
  if key and effects[key] then
    return key
  end
  local number = key and itemNumber(battle, key)
  if number then
    for candidate in pairs(effects) do
      if itemNumber(battle, candidate) == number then
        return candidate
      end
    end
  end
  return key or ref
end

function M.validSwitch(battle, battler, value, gba, executing)
  local index = tonumber(value)
  if not index or index ~= index then
    return nil
  end
  if gba then
    index = math.floor(index)
  end
  local party = battle:benchFor(false, battler.position)
  local mon = party and party[index]
  if not mon or (tonumber(mon.hp) or 0) <= 0 then
    return nil
  end
  if gba and (index < 1 or index > 6 or require("src.pokemon.Party").isEgg(mon)) then
    return nil
  end
  if gba and (mon.species == nil or mon.species == 0) then
    return nil
  end
  for _, active in pairs(battle.sides[2].battlers) do
    if active and active.mon == mon then
      return nil
    end
  end
  if gba then
    for who, reserved in pairs(battle._enemySwitchReservations or {}) do
      if reserved == mon and not (executing and who == battler) then
        return nil
      end
    end
  end
  return index
end

local HEAL =
  { POTION = 20, SUPER_POTION = 50, HYPER_POTION = 200, MAX_POTION = math.huge, FULL_RESTORE = math.huge }

function M.gen2Item(battle, ref)
  if not ref then
    return false
  end
  local key = M.itemKey(battle.data, ref) or ref
  local trainer, mon = battle.trainer, battle.enemy.mon
  -- Gen 2's native handler accepts an explicit item even when absent from
  -- stock. Preserve that native distinction from GBA's useStocked refusal.
  for i, id in ipairs(trainer and trainer.items or {}) do
    if id == key then
      table.remove(trainer.items, i)
      break
    end
  end
  local def = (battle.data.items or {})[key]
  local name = slug(def and def.key) or slug(key)
  local amount = HEAL[name]
  if amount then
    mon.hp = math.min(mon.stats.hp, mon.hp + amount)
  end
  if name == "FULL_HEAL" or name == "FULL_RESTORE" then
    mon.status, battle.enemy.confusedTurns = nil, nil
  end
  battle:say(
    require("src.core.Strings")("%s used %s!", trainer and trainer.name or "TRAINER", def and def.name or key)
  )
  return true
end

function M.gen2Native(battle)
  if battle.kind ~= "trainer" or not battle.trainer or type(battle.trainer.attributes) ~= "table" then
    return false
  end
  local enemy, player = battle.enemy, battle.player
  local TypeChart = require("src.battle.TypeChart")
  local function multiplier(kind, types)
    local unique, seen = {}, {}
    for _, t in ipairs(types or {}) do
      if not seen[t] then
        unique[#unique + 1], seen[t] = t, true
      end
    end
    return TypeChart.effectiveness(kind, unique)
  end
  local score, bench = 10, {}
  for _, id in ipairs(player._gen2UsedMoves or {}) do
    local move = battle.data.moves[id]
    if move and (move.power or 0) > 0 and multiplier(move.type, enemy.curTypes) > 10 then
      score = score - 1
    end
  end
  for i, mon in ipairs(battle.enemyParty or {}) do
    if mon ~= enemy.mon and (mon.hp or 0) > 0 then
      local types = ((battle.data.pokemon or {})[mon.species] or {}).types or mon.types or {}
      local incoming = multiplier((player.curTypes or {})[1], types)
      local super = false
      for _, slot in ipairs(mon.moves or {}) do
        local move = battle.data.moves[slot.id]
        if move and (move.power or 0) > 0 and multiplier(move.type, player.curTypes) > 10 then
          super = true
        end
      end
      bench[#bench + 1] = { index = i, resists = incoming < 10, super = super }
    end
  end
  local desire, target = 0, nil
  if #bench > 0 and enemy.perishTurns == 1 then
    desire, target = 48, bench[1].index
  elseif score < 10 then
    for _, row in ipairs(bench) do
      if row.resists and row.super then
        desire, target = 32, row.index
        break
      end
      if row.resists and not target then
        desire, target = 16, row.index
      end
    end
  end
  local attrs = battle.trainer.attributes
  local flags = (attrs[6] or 0) + (attrs[7] or 0) * 256
  local chances = {
    [1] = { [16] = 50, [32] = 79, [48] = 96 },
    [2] = { [16] = 8, [32] = 12, [48] = 21 },
    [4] = { [16] = 20, [32] = 50, [48] = 80 },
  }
  local chance
  for _, bit in ipairs({ 1, 2, 4 }) do
    if math.floor(flags / bit) % 2 == 1 then
      chance = chances[bit][desire]
      break
    end
  end
  local trapped = enemy.trapped or (enemy.boundTurns or 0) > 0 or (player.trappingTurns or 0) > 0
  if target and not trapped and chance and battle.rng(0, 99) < chance then
    return battle:performEnemySwitch(enemy, target)
  end
  local highest = 0
  for _, mon in ipairs(battle.enemyParty or {}) do
    highest = math.max(highest, mon.level or 0)
  end
  if (enemy.mon.level or 0) < highest then
    return false
  end
  local stock = {}
  for _, id in ipairs(battle.trainer.items or {}) do
    local key = M.itemKey(battle.data, id) or id
    local def = (battle.data.items or {})[key]
    stock[slug(def and def.key) or slug(key)] = key
  end
  for _, name in ipairs({
    "FULL_RESTORE",
    "MAX_POTION",
    "HYPER_POTION",
    "SUPER_POTION",
    "POTION",
    "X_ACCURACY",
    "FULL_HEAL",
    "GUARD_SPEC",
    "DIRE_HIT",
    "X_ATTACK",
    "X_DEFEND",
    "X_SPEED",
    "X_SPECIAL",
  }) do
    local key, amount = stock[name], HEAL[name]
    if key then
      local hp, max = enemy.mon.hp, enemy.mon.stats.hp
      local use = amount and hp * 2 <= max and max - hp >= math.min(amount, max) / 2
        or name == "FULL_HEAL" and enemy.mon.status ~= nil
        or not amount and name ~= "FULL_HEAL" and (enemy._gen2TurnsTaken or 0) == 0
      if use then
        return M.gen2Item(battle, key)
      end
    end
  end
  return false
end

function M.gen2(battle)
  local chosen
  if Runtime.wantsHook("battle.enemy_switch_or_item") then
    chosen = Runtime.call("battle.enemy_switch_or_item", M.gen2Native, battle)
  else
    chosen = M.gen2Native(battle)
  end
  if type(chosen) == "table" then
    if chosen.kind == "switch" then
      return battle:performEnemySwitch(battle.enemy, tonumber(chosen.index) or 0)
    end
    if chosen.kind == "item" then
      return M.gen2Item(battle, chosen.item)
    end
    return false
  end
  return not not chosen
end

local function reserveSwitch(battle, battler, index)
  battle._enemySwitchReservations = battle._enemySwitchReservations or {}
  battle._enemySwitchReservations[battler] = battle:benchFor(false, battler.position)[index]
end

local function reserveItem(battle, battler, key)
  return require("src.battle.EnemyItems").reserve(battle, battler, key)
end

local function gbaAllowed(battle)
  return battle.kind == "trainer" and not battle.pokedudeDemo and not (battle.demo and not battle.dudeDemo)
end

-- Explicit mod classes precede the native switch/item hook. Their allowance
-- belongs to each party Pokemon; their item actions share native trainer stock.
function M.gbaClass(battle, battler)
  if not gbaAllowed(battle) or not battle.trainer or not battle.trainer.aiClass then
    return nil
  end
  local class = TrainerAI.classFor(battle)
  if not class or class.kind ~= nil and class.kind ~= "class" then
    return nil
  end
  if not battler or not battler.mon or (battler.position or 1) % 2 ~= 1 then
    return nil
  end
  battle._gbaClassUses = battle._gbaClassUses or {}
  local mon = battler.mon
  local left = battle._gbaClassUses[mon]
  if left == nil then
    left = tonumber(class.uses) or 0
  end
  if left <= 0 then
    return nil
  end
  local roll = battle.rng(0, 255)
  local function switch()
    for index, candidate in ipairs(battle:benchFor(false, battler.position) or {}) do
      local active = false
      for _, other in pairs(battle.sides[2].battlers) do
        if other.mon == candidate then
          active = true
          break
        end
      end
      if
        not active
        and (tonumber(candidate.hp) or 0) > 0
        and not require("src.pokemon.Party").isEgg(candidate)
      then
        reserveSwitch(battle, battler, index)
        return { special = "aiSwitch", index = index, decisionBattler = battler }
      end
    end
  end
  local function item()
    if class.item then
      return reserveItem(battle, battler, M.itemKey(battle.data, class.item))
    end
  end
  local action
  if class.switchChance and roll < class.switchChance then
    action = switch()
  elseif class.onStatus then
    if mon.status or battler.status or battler.modStatus then
      action = item()
    end
  elseif class.chance and roll >= class.chance then
    action = nil
  elseif class.switch then
    action = switch()
  elseif class.hpBelow then
    local hp, maxHp = tonumber(mon.hp) or 0, tonumber(mon.stats and mon.stats.hp) or 1
    if hp >= math.floor(maxHp / class.hpBelow) then
      if class.switchBelow and hp < math.floor(maxHp / class.switchBelow) then
        action = switch()
      end
    else
      action = item()
    end
  else
    action = item()
  end
  if action then
    battle._gbaClassUses[mon] = left - 1
  end
  return action
end

local function sourceAction(battle, battler, action)
  if not action then
    return nil
  end
  local id = battler.position or 1
  if action.special == "aiSwitch" then
    reserveSwitch(battle, battler, action.index)
    return { kind = "switch", slot = action.index, user = "enemy", battler = id }
  elseif action.special == "aiItem" then
    battle.gen3ItemsUsed = battle.gen3ItemsUsed or {}
    if action.slot then
      battle.gen3ItemsUsed[action.slot] = true
    end
    return {
      kind = "item",
      item = itemNumber(battle, action.item),
      aiItemType = action.aiItemType,
      aiItemFlags = action.aiItemFlags or 0,
      user = "enemy",
      battler = id,
      target = id,
    }
  end
end

function M.gba(battle, battler)
  if not gbaAllowed(battle) then
    return nil
  end
  local native, action
  local function base()
    local index = require("src.battle.EnemySwitch").choose(battle, battler, M.validSwitch)
    action = index and { special = "aiSwitch", index = index }
      or require("src.battle.EnemyItems").choose(battle, battler)
    if action then
      action.decisionBattler = battler
    end
    native = sourceAction(battle, battler, action)
    return native or false
  end
  local chosen
  if Runtime.wantsHook("battle.enemy_switch_or_item") then
    chosen = Runtime.call("battle.enemy_switch_or_item", base, battle)
  else
    chosen = base()
  end
  if chosen == true or native and chosen == native then
    -- The reference returns this same native action after next(). A mod can
    -- edit its item without consuming another stock slot.
    if native and native.kind == "item" and action then
      if native.item ~= itemNumber(battle, action.item) then
        action.item = effectItemKey(battle, native.item)
      end
      action.aiItemType, action.aiItemFlags = native.aiItemType, native.aiItemFlags
    end
    return action
  end
  if type(chosen) ~= "table" then
    return nil
  end
  if chosen.kind == "switch" then
    local index = M.validSwitch(battle, battler, chosen.index or chosen.slot, true)
    if not index then
      return nil
    end
    reserveSwitch(battle, battler, index)
    return { special = "aiSwitch", index = index, decisionBattler = battler }
  elseif chosen.kind == "item" then
    return reserveItem(battle, battler, M.itemKey(battle.data, chosen.item))
  end
end

return M
