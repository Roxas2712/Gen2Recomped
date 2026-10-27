-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The imported effect byte owns native fixed damage, independently of names.
local F = {}
local V = require("src.core.GameVersion")
local cache = setmetatable({}, { __mode = "k" })
local effects = { [41] = true, [87] = true, [88] = true, [130] = true }
local function rs()
  return V.get() == "ruby" or V.get() == "sapphire"
end
function F.native(move)
  return V.isGen3() and move.fixedDamage == nil and effects[tonumber(move.gen3Effect)] == true
end
local function effectiveness(target, move)
  local Types, Abilities = require("src.battle.TypeChart"), require("src.battle.Abilities")
  local kind = Abilities.normalizeType(move.type)
  local identified = target.identified and (kind == "NORMAL" or kind == "FIGHTING")
  local value, super, notVery = 1, false, false
  for _, multiplier in ipairs(Types.rows(move.type, target.curTypes or {})) do
    if not (identified and multiplier == 0) then
      value = value * multiplier / 10
      super = super or multiplier > 10
      notVery = notVery or multiplier > 0 and multiplier < 10
    end
  end
  return math.floor(value * 10 + 0.5), super, notVery
end
-- This is reached inside the public damage-calculation seam. FR/LG/E roll
-- Psywave here; R/S's rejection opcode supplies its value before that seam.
function F.calculate(user, target, move, opts)
  if (tonumber(move.power) or 0) <= 0 and not opts.power then
    return 0, { crit = false, typeMult = 10, status = true, gbaNativeFixed = true }
  end
  local effect = tonumber(move.gen3Effect)
  local amount
  if effect == 41 then amount = 40
  elseif effect == 130 then amount = 20
  elseif effect == 87 then amount = tonumber(user.mon.level) or 1
  elseif effect == 88 then
    local roll = opts.psywaveRoll
    if roll == nil then roll = (opts.rng or love.math.random)(0, 10) end
    amount = math.floor((tonumber(user.mon.level) or 1) * (math.max(0, math.min(10, roll)) * 10 + 50) / 100)
  else return nil end
  local mult, super, notVery = effectiveness(target, move)
  if mult == 0 and not opts.deferAdjustment then amount = 0 end
  return amount, { crit = false, typeMult = mult, physical = require("src.battle.TypeChart").category(move.type) ~= "special",
    gbaNativeFixed = true, gbaFixedSuper = super, gbaFixedNotVery = notVery }
end
local function choose(ctx)
  local opts = { rng = ctx.rng, gbaNativeFixed = true, deferAdjustment = rs() or nil }
  if rs() and tonumber(ctx.move.gen3Effect) == 88 then
    repeat opts.psywaveRoll = ctx.rng(0, 15) until opts.psywaveRoll <= 10
  end
  local amount, info = ctx.battle:computeDamage(ctx.user, ctx.target, ctx.move, opts)
  info = type(info) == "table" and info or { crit = false, typeMult = 10 }
  -- The calculation does not consume critical/random-damage commands. Native
  -- target ability guards run after the public calculation has returned.
  local Abilities = require("src.battle.Abilities")
  local ability = Abilities.of(ctx.target)
  if ability == "LEVITATE" and Abilities.normalizeType(ctx.move.type) == "GROUND"
      or ability == "WONDER_GUARD" and not (info.gbaFixedSuper and not info.gbaFixedNotVery) then
    info.typeMult, info.ability = 0, ability
  end
  info.gbaNativeFixed = true
  return math.max(0, math.floor(tonumber(amount) or 0)), info
end
function F.builtin(id, base)
  if not V.isGen3() or id ~= "SPECIAL_DAMAGE_EFFECT" or not base then return base end
  if cache[base] then return cache[base] end
  local out = {}
  for key, value in pairs(base) do out[key] = value end
  out.gbaNativeFixed = true
  out.chooseDamage = function(ctx)
    if not V.isGen3() or ctx.move.fixedDamage ~= nil or not effects[tonumber(ctx.move.gen3Effect)] then
      return base.chooseDamage(ctx)
    end
    return choose(ctx)
  end
  cache[base] = out
  return out
end
return F
