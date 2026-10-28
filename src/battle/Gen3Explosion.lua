-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Explosion owns its HP write and calculation before the accuracy command.
local E = {}
local V = require("src.core.GameVersion")
local Strings = require("src.core.Strings")
local cache = setmetatable({}, { __mode = "k" })
function E.builtin(id, base)
  if not V.isGen3() or id ~= "EXPLODE_EFFECT" or not base then return base end
  if cache[base] then return cache[base] end
  local out = {}
  for key, value in pairs(base) do out[key] = value end
  out.gbaExplosion = true
  out.gate = function(ctx)
    for _, actor in ctx.battle:activeBattlers() do
      if require("src.battle.Abilities").of(actor) == "DAMP" then return false, Strings("But, it failed!") end
    end
    return true
  end
  cache[base] = out
  return out
end
function E.prepare(ctx, record, calculate)
  if not V.isGen3() or not record or not record.gbaExplosion or not record.explode
      or record.chooseDamage or record.perHitDamage then return end
  local battle, frame = ctx.battle, ctx.battle._gbaMoveFrame
  local scope = frame and frame.parent or battle._gbaActionFrame or frame or ctx
  if not frame or not frame.spreadContinuation then scope.gbaExplosion = nil; scope.gbaStopTargets = nil end
  local state = scope.gbaExplosion
  if not state then
    local ok, message = true, nil
    if record.gate then ok, message = record.gate(ctx) end
    if not ok then
      scope.gbaStopTargets = true
      if frame then frame.failed = true end
      battle:cancelMoveAnim()
      if message then battle:sayNext(message) end
      return false
    end
    state = { user = ctx.user, defer = battle:isDouble() and tonumber(ctx.move.target) == 32 }
    scope.gbaExplosion = state
  end
  if frame then frame.gbaExplosionState = state end
  -- Every target body executes setHP(0), even after a mod has written HP or
  -- a genuine native heal has cleared the prior logical faint marker.
  ctx.user.mon.hp = 0
  require('src.battle.Gen3FaintFriendship').capture(battle,ctx.user)
  require('src.battle.Gen3Faint').mark(ctx.user)
  if record.beforeAccuracy then record.beforeAccuracy(ctx); ctx.gbaExplosionBeforeAccuracy = true end
  local amount, info = calculate()
  amount, info = require("src.battle.Gen3DamageAdjustment").apply(ctx, amount, info)
  ctx.gbaExplosionDamage, ctx.gbaExplosionInfo, ctx.gbaExplosionPrepared = amount, info, true
  return true
end
function E.guard(ctx, info)
  -- The FR/LG/E special branch still checks Levitate/type immunity after
  -- accuracy, but never runs the ordinary Wonder Guard command.
  if not require("src.battle.Gen3DamageAdjustment").rs() then
    require("src.battle.Gen3DamageAdjustment").guard(ctx, info, true)
  end
end
return E
