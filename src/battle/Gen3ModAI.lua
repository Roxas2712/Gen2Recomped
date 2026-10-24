-- Mod-defined GBA move selectors run after native class/item/switch actions.
local M = {}
local TrainerAI = require("src.battle.TrainerAI")
local function present(move)
  return type(move) == "table" and move.id ~= nil and move.id ~= "" and move.id ~= 0
end
local function struggle(battle)
  local id = "STRUGGLE"
  for key, def in pairs(battle.data.moves or {}) do
    if tonumber(def.index) == 165 then
      id = key
      break
    end
  end
  return { id = id, pp = 1, struggle = true }
end
local function fallback(battle, user)
  for _, move in ipairs(user.curMoves or {}) do
    if present(move) and (move.pp == nil or move.pp > 0) then
      return move
    end
  end
  return struggle(battle)
end
local function moveView(battle, move)
  local def = (battle.data.moves or {})[move.id] or {}
  local loader = battle.game and battle.game.mods
  local id = move.id
  if loader and loader.content then
    id = require("src.mods.UnifiedIds").new(loader):read("moves", move.id)
  elseif type(id) ~= "string" or id:match("^MOVE_%d+$") then
    id = (def.name or tostring(id)):upper():gsub("[^%w]+", "_")
  end
  local constants = battle.data.constants or {}
  local typeIndex = constants.types and constants.types[def.type]
  typeIndex = typeIndex and tonumber(typeIndex.index)
  if typeIndex == nil then
    for i, name in ipairs(constants.typeOrder or {}) do
      if name == def.type then
        typeIndex = i - 1
        break
      end
    end
  end
  local category = (def.power or 0) == 0 and "status"
    or typeIndex and (typeIndex <= 8 and "physical" or "special")
    or nil
  local aliases = {
    PSYCHIC = "PSYCHIC_TYPE",
    PSYCHC = "PSYCHIC_TYPE",
    MYSTERY = "CURSE_TYPE",
    FIGHT = "FIGHTING",
    ELECTR = "ELECTRIC",
  }
  return {
    id = id,
    index = def.index,
    num = def.index,
    name = def.name,
    type = aliases[def.type] or def.type,
    gen3Type = typeIndex,
    power = def.power,
    accuracy = def.accuracy,
    pp = def.pp,
    priority = def.priority,
    category = category,
    effect = def.gen3Effect or type(def.effect) == "number" and def.effect or nil,
    target = def.target,
    secondaryChance = def.secondaryChance,
  }
end
local function limits(battle, user)
  local bad = {}
  local held = require("src.battle.HoldItems").effectOf(user, "check")
  for i = 1, 4 do
    local move = (user.curMoves or {})[i]
    if not present(move) then
      bad[i] = true
    else
      local def = (battle.data.moves or {})[move.id] or {}
      if move.pp == 0 or user.disabledSlot == i then
        bad[i] = true
      end
      if user.tormented and user.lastMove == move.id then
        bad[i] = true
      end
      if (user.tauntTurns or 0) > 0 and (def.power or 0) == 0 then
        bad[i] = true
      end
      if (user.encoreTurns or 0) > 0 and user.encoreMove and user.encoreMove ~= move.id then
        bad[i] = true
      end
      if held == "CHOICE_BAND" and user.choicedMove and user.choicedMove ~= move.id then
        bad[i] = true
      end
      for _, foe in ipairs(battle:foesOf(user)) do
        if foe.imprison then
          for _, sealed in ipairs(foe.curMoves or {}) do
            if sealed.id == move.id then
              bad[i] = true
            end
          end
        end
      end
    end
  end
  return bad
end
local function layersFor(battle)
  local layers, records = {}, battle.data.ai_classes or {}
  local function add(id)
    local record = id and records[id]
    if
      type(record) == "table"
      and type(record.score) == "function"
      and (record.kind == nil or record.kind == "layer")
    then
      layers[#layers + 1] = record.score
    end
  end
  -- GBA identifiers are literal, including numeric keys. Duplicates and the
  -- explicit class appended after aiMods are part of the public contract.
  for _, id in ipairs(battle.enemyAIMods or {}) do
    add(id)
  end
  add(battle.trainer.aiClass)
  return layers
end
local function scoresFor(battle, user, target, bad, flags, simulatedRNG)
  local scores, moves, slots, initial, simulated = {}, {}, {}, {}, {}
  for i = 1, 4 do
    scores[i] = bad[i] and 0 or 100
    local move = (user.curMoves or {})[i]
    if present(move) then
      moves[#moves + 1], slots[#slots + 1], initial[#initial + 1] = move, i, scores[i]
      simulated[#simulated + 1] = simulatedRNG[i]
    end
  end
  local native = require("src.battle.Gen3AI").scoreMoves(
    battle,
    user,
    target,
    moves,
    { scores = initial, flags = flags, simulatedRNG = simulated }
  )
  if native then
    for i, slot in ipairs(slots) do
      scores[slot] = native[i]
    end
  end
  return scores
end
local function applyLayers(battle, user, target, scores, bad, layers)
  if #layers == 0 then
    return
  end
  local view = { battle = battle, user = user, target = target, data = battle.data, rng = battle.rng }
  for slot = 1, 4 do
    local move = (user.curMoves or {})[slot]
    if present(move) and not bad[slot] then
      -- One detached view per physical slot, shared by its successive layers.
      local def = moveView(battle, move)
      for _, score in ipairs(layers) do
        scores[slot] = score(view, def, scores[slot]) or scores[slot]
      end
    end
  end
end
local function pick(battle, user, scores, bad)
  local emerald = require("src.core.GameVersion").get() == "emerald"
  local best, candidates = scores[1], { 1 }
  for i = 2, 4 do
    if not emerald or present((user.curMoves or {})[i]) then
      if best < scores[i] then
        best, candidates = scores[i], { i }
        -- FireRed appends a newly higher slot twice; Emerald includes it once.
        if not emerald then
          candidates[2] = i
        end
      elseif best == scores[i] then
        candidates[#candidates + 1] = i
      end
    end
  end
  local slot = candidates[battle.rng(1, #candidates)]
  if not present((user.curMoves or {})[slot]) then
    for i = 1, 4 do
      if not bad[i] and present((user.curMoves or {})[i]) then
        slot = i
        break
      end
    end
  end
  return slot, best
end
local function chooseDouble(battle, user, bad, flags)
  local id, slots, points = user.position or 1, {}, {}
  for targetId = 0, 3 do
    local target = battle:battlerAt(targetId)
    points[targetId] = -1
    if targetId ~= id and target and (target.mon.hp or 0) > 0 then
      local simulated = {}
      for i = 1, 4 do
        simulated[i] = 100 - battle.rng(0, 15)
      end
      battle.rng(0, 65535)
      local scores = scoresFor(battle, user, target, bad, flags, simulated)
      local slot, best = pick(battle, user, scores, bad)
      slots[targetId], points[targetId] = slot, best
      if targetId % 2 == id % 2 and best < 100 then
        points[targetId] = -1
      end
    end
  end
  local best, targets = points[0], { 0 }
  for i = 1, 3 do
    if best == points[i] then
      targets[#targets + 1] = i
    end
    if best < points[i] then
      best, targets = points[i], { i }
    end
  end
  local targetId = targets[battle.rng(1, #targets)]
  return slots[targetId], targetId
end
local function choose(battle, user, class, layers)
  local bad = limits(battle, user)
  if bad[1] and bad[2] and bad[3] and bad[4] then
    return struggle(battle), true
  end
  local id = user.position or 1
  local target = battle:battlerAt(id % 2 == 1 and id - 1 or id + 1)
  local slot
  if class and class.kind == "brain" and type(class.brain) == "function" then
    local view =
      { battle = battle, user = user, target = target, data = battle.data, rng = battle.rng, moves = {} }
    for i = 1, 4 do
      local move = (user.curMoves or {})[i]
      if present(move) then
        view.moves[#view.moves + 1] = { slot = i, move = moveView(battle, move), usable = not bad[i] }
      end
    end
    local picked = class.brain(view)
    slot = tonumber(type(picked) == "table" and picked.slot or picked)
    if
      not slot
      or slot < 1
      or slot > 4
      or slot ~= math.floor(slot)
      or bad[slot]
      or not present((user.curMoves or {})[slot])
    then
      slot = nil
    end
  end
  -- Native AI setup consumes four simulation draws even for a valid brain.
  local simulated = {}
  for i = 1, 4 do
    simulated[i] = 100 - battle.rng(0, 15)
  end
  local targetId = id % 2 == 1 and id - 1 or id + 1
  if battle:isDouble() then
    targetId = math.floor(battle.rng(0, 65535) / 2) % 2 * 2
    if not battle:battlerAt(targetId) then
      targetId = 2 - targetId
    end
  end
  if not slot then
    local flags = tonumber(battle.trainer.aiFlags) or 0
    local emeraldDouble = battle:isDouble() and require("src.core.GameVersion").get() == "emerald"
    if emeraldDouble and math.floor(flags / 128) % 2 == 0 then
      flags = flags + 128
    end
    if emeraldDouble and require("src.battle.Gen3AI").program(battle) then
      -- The reference's loaded Emerald per-target program branch bypasses
      -- mod layers. A missing pack still follows the ordinary layer path.
      slot, targetId = chooseDouble(battle, user, bad, flags)
    else
      local scores = scoresFor(battle, user, battle:battlerAt(targetId), bad, flags, simulated)
      applyLayers(battle, user, battle:battlerAt(targetId), scores, bad, layers)
      slot = pick(battle, user, scores, bad)
    end
  end
  local move = (user.curMoves or {})[slot]
  if not move then
    return fallback(battle, user), true
  end
  local targetKind = tonumber((battle.data.moves[move.id] or {}).target) or 0
  if math.floor(targetKind / 16) % 2 == 1 then
    targetId = id
  end
  if math.floor(targetKind / 8) % 2 == 1 then
    targetId = battle:isDouble() and 0 or id - 1
    if battle:isDouble() and not battle:battlerAt(targetId) then
      targetId = 2
    end
  end
  if battle:isDouble() then
    battle.chosenTargets = battle.chosenTargets or {}
    battle.chosenTargets[id] = battle:battlerAt(targetId)
  end
  return move, true
end
function M.choose(battle, user)
  if battle.kind ~= "trainer" or not battle.trainer then
    return nil, false
  end
  local class = battle.trainer.aiClass and TrainerAI.classFor(battle)
  local layers = layersFor(battle)
  local ok, action, handled = pcall(choose, battle, user, class, layers)
  if not ok then
    return fallback(battle, user), true
  end
  return action, handled
end
return M
