-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The calculation and the edition's damage-adjustment command have separate
-- owners. In R/S the public calculation precedes variation and Focus Band.
local A = {}
local V = require("src.core.GameVersion")
local cache = setmetatable({}, { __mode = "k" })
function A.rs()
  return V.get() == "ruby" or V.get() == "sapphire"
end
function A.draw(ctx, lo, hi)
  return (ctx.battle.rng or ctx.rng)(lo, hi)
end
function A.compute(ctx, calculate)
  if not V.isGen3() then return calculate() end
  ctx.gbaNativeDamage = true
  local battle, previous = ctx.battle, ctx.battle._gbaDamageCalculation
  battle._gbaDamageCalculation = ctx
  local ok, amount, info = pcall(calculate)
  battle._gbaDamageCalculation = previous
  if not ok then error(amount, 0) end
  return amount, info
end
function A.options(battle, user, target, move, opts)
  local ctx = battle._gbaDamageCalculation
  if ctx and ctx.user == user and ctx.target == target and ctx.move.id == move.id then
    opts.gbaRawCalculation = true
    -- calc_opts snapshots the current generator before the public hook.
    -- Replacing battle.rng inside that hook affects later commands, not
    -- this already prepared calculation. Explicit authored generators stay.
    if opts.rng == ctx.rng then opts.rng = battle.rng or opts.rng end
    if A.rs() and opts.deferAdjustment == nil then opts.deferAdjustment = true end
  end
end
local function copy(info)
  local out = {}
  for key, value in pairs(info or {}) do out[key] = value end
  return out
end
local function flags(info)
  return info.typeFlags or { super = info.gbaFixedSuper, notVery = info.gbaFixedNotVery }
end
function A.immune(ctx, info)
  local Abilities = require("src.battle.Abilities")
  if info.typeMult == 0 then return true end
  local ability = Abilities.of(ctx.target)
  if ability == "LEVITATE" and Abilities.normalizeType(ctx.move.type) == "GROUND" then return true end
  local f = flags(info)
  return ability == "WONDER_GUARD" and not (f.super and not f.notVery)
end
function A.guard(ctx, info, ignoreWonderGuard)
  local Abilities = require("src.battle.Abilities")
  local ability = Abilities.of(ctx.target)
  local f = flags(info)
  if ability == "LEVITATE" and Abilities.normalizeType(ctx.move.type) == "GROUND"
      or not ignoreWonderGuard and ability == "WONDER_GUARD" and not (f.super and not f.notVery) then
    info.typeMult, info.ability = 0, ability
  end
end
function A.site(ctx, info)
  local effect = tonumber(ctx.move.gen3Effect)
  if info.gbaBeatUp then return "normal" end
  if effect == 40 then return "none" end
  if effect == 189 then return "set_unless_immune" end
  if info.gbaSetDamage or effect == 41 or effect == 87 or effect == 88 or effect == 130
      or effect == 89 or effect == 144 or effect == 161 then return "set" end
  if effect == 29 or effect == 44 or effect == 77 or effect == 119 then return "normal_unless_immune" end
  return "normal"
end
function A.apply(ctx, amount, original, siteOverride)
  if not V.isGen3() or not (ctx.gbaNativeDamage or original.gbaNativeFixed or original.gbaBeatUp or siteOverride) then
    return amount, original
  end
  local info = copy(original)
  if not A.rs() then
    -- Native fixed records already perform their FR/LG/E ability guard.
    if not info.gbaNativeFixed and not info.gbaBeatUp and not siteOverride
        and not (ctx.record and ctx.record.explode) then A.guard(ctx, info) end
    return amount, info
  end
  local site = siteOverride or A.site(ctx, info)
  local prepared = { bandRolled = true }
  local reached = site ~= "none"
  if site == "normal_unless_immune" or site == "set_unless_immune" then reached = not A.immune(ctx, info) end
  if reached then
    if site ~= "set" and site ~= "set_unless_immune" then
      local percent = 100 - A.draw(ctx, 0, 15)
      if amount ~= 0 then amount = math.max(1, math.floor(amount * percent / 100)) end
    end
    -- Keep the per-move proc even if a later strike's roll fails or the item
    -- changes. Every reached command still performs its own held-item read.
    local proc = ctx.battle:focusBandHolds(ctx.target, amount, true)
    ctx.gbaAdjustmentBands = ctx.gbaAdjustmentBands or {}
    if proc then ctx.gbaAdjustmentBands[ctx.target] = true end
    local banded = ctx.gbaAdjustmentBands[ctx.target]
    local swipe = site ~= "normal2" and tonumber(ctx.move.gen3Effect) == 101
    if (ctx.target.substituteHP or 0) <= 0 and (swipe or ctx.target.enduring or banded)
        and amount >= ctx.target.mon.hp then
      amount = math.max(0, ctx.target.mon.hp - 1)
      prepared.endured = ctx.target.enduring == true
      prepared.hung = not prepared.endured and banded or nil
    end
  end
  info.damageAdjustment = prepared
  if site ~= "normal2" and not info.gbaBeatUp then A.guard(ctx, info) end
  return amount, info
end
function A.builtin(id, base)
  if not V.isGen3() or not base or id == "OHKO_EFFECT" then return base end
  local native = require("src.battle.MoveEffects").RECORDS[id]
  if not native or type(base.chooseDamage) ~= "function" then return base end
  local byName = cache[base]
  if byName and byName[id] then return byName[id] end
  local out = {}
  for key, value in pairs(base) do out[key] = value end
  out.chooseDamage = function(ctx)
    return A.compute(ctx, function()
      if id == "FALSE_SWIPE_EFFECT" and V.isGen3() then
        return ctx.battle:computeDamage(ctx.user, ctx.target, ctx.move, { rng = ctx.rng })
      end
      return base.chooseDamage(ctx)
    end)
  end
  byName = byName or {}; byName[id] = out; cache[base] = byName
  return out
end
return A
