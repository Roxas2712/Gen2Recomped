-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The native enemy-item effect program operates on its selected battler.
-- Stock admission, hook results and presentation belong to the controller.
local Items = require("src.battle.Gen3TrainerItems")
local M = {}
local function bit(value, flag) return math.floor(value / flag) % 2 == 1 end
local names = { sleep = "SLP", poison = "PSN", toxic = "TOX", burn = "BRN",
  freeze = "FRZ", paralysis = "PAR", paralyze = "PAR" }

function M.apply(battle, actor, item)
  if not item or not Items.context(battle, actor) then return false end
  -- Enemy item use ends these move-specific effects, independently of the
  -- item's effect bytes. Rollout uses a separate native counter.
  local ramp = actor.rampMove and battle.data.moves and battle.data.moves[actor.rampMove]
  if actor.rampMove == "FURY_CUTTER" or ramp and ramp.index == 210 then
    actor.rampRun, actor.rampMove = nil, nil
  end
  actor.destinyBond, actor.grudge = nil, nil
  -- Re-read the live effect program at execution, rather than the program
  -- observed when the trainer reserved the item during action selection.
  local e = Items.effect(battle, item)
  if not e then return true end
  if bit(e[1], 128) then actor.infatuated = nil end
  if math.floor(e[1] / 16) % 4 ~= 0 then actor.focusEnergy = true end
  local function raise(stat, amount)
    if actor.stages and amount > 0 and (actor.stages[stat] or 0) < 6 then
      require("src.battle.MoveEffects").changeStage(battle, actor, stat, amount, false)
    end
  end
  raise("attack", e[1] % 16)
  raise("defense", math.floor(e[2] / 16))
  raise("speed", e[2] % 16)
  raise("accuracy", math.floor(e[3] / 16))
  raise("spatk", e[3] % 16)
  local side = battle.sides and battle.sides[2]
  if bit(e[4], 128) and side and (tonumber(side.gen3MistTurns) or 0) == 0 then
    side.gen3MistTurns = 5
  end
  local mon = actor.mon
  local status = names[mon.status] or mon.status
  local cure = bit(e[4], 32) and status == "SLP"
    or bit(e[4], 16) and (status == "PSN" or status == "TOX")
    or bit(e[4], 8) and status == "BRN"
    or bit(e[4], 4) and status == "FRZ"
    or bit(e[4], 2) and status == "PAR"
  if cure then
    if status == "SLP" then actor.nightmare = nil end
    mon.status, mon.toxic, mon._gen3Toxic = nil, nil, nil
    actor.toxicCounter, actor.sleepTurns = nil, nil
  end
  if bit(e[4], 1) and (tonumber(actor.confusedTurns) or 0) > 0 then
    actor.confusedTurns = nil
  end
  if bit(e[5], 4) then
    local hp = tonumber(mon.hp) or 0
    local maxHp = tonumber(mon.stats and mon.stats.hp) or tonumber(mon.maxHp) or 0
    if bit(e[5], 64) and hp == 0 or not bit(e[5], 64) and hp ~= 0 then
      local amount = e.hp
      if amount == 255 then amount = maxHp - hp
      elseif amount == 254 then amount = math.max(1, math.floor(maxHp / 2))
      elseif amount == 253 then amount = 0 end
      if hp ~= maxHp then mon.hp = math.max(0, math.min(maxHp, hp + amount)) end
    end
  end
  return true
end

return M
