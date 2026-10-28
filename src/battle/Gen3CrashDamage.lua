-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- A native Jump Kick miss calculates its own crash without a damage hook.
local C = {}
local V = require("src.core.GameVersion")
local Strings = require("src.core.Strings")
local cache = setmetatable({}, { __mode = "k" })
local function crash(ctx, reason)
  if reason == "absorbed" or reason == "immune" or reason == "floored" then return end
  local kind = require("src.battle.Abilities").normalizeType(ctx.move.type)
  local identified = ctx.target.identified and (kind == "NORMAL" or kind == "FIGHTING")
  local typeMult = 10
  for _, value in ipairs(require("src.battle.TypeChart").rows(ctx.move.type, ctx.target.curTypes or {})) do
    if not (identified and value == 0) then typeMult = typeMult * value / 10 end
  end
  if typeMult == 0 and reason ~= "protected" then return end
  ctx.say(Strings("%s\nkept going and\ncrashed!", ctx.displayName(ctx.user)))
  local amount, info = ctx.battle:computeDamage(ctx.user, ctx.target, ctx.move,
    { rng = ctx.battle.rng, forceCrit = false, gbaRawCalculation = true, gbaSilentCalculation = true,
      deferAdjustment = require("src.battle.Gen3DamageAdjustment").rs() or nil })
  if require("src.battle.Gen3DamageAdjustment").rs() then
    ctx.gbaNativeDamage = true
    -- The cartridge adjusts against the intended recipient before halving
    -- the crash, including that recipient's Focus Band/Endure decisions.
    amount = require("src.battle.Gen3DamageAdjustment").apply(ctx, amount, info, "normal")
  end
  amount = math.floor(amount / 2)
  if amount == 0 then amount = 1 end
  local maxHp = ctx.target.mon.stats and ctx.target.mon.stats.hp or ctx.target.mon.maxHp or 1
  amount = math.min(amount, math.floor(maxHp / 2))
  ctx.battle:applyDamage(ctx.user, amount, false, { confusion = true, bandRolled = true })
  if ctx.user.mon.hp <= 0 then ctx.battle:onFaint(ctx.user) end
end
function C.builtin(id, base)
  if not V.isGen3() or id ~= "JUMP_KICK_EFFECT" or not base then return base end
  if cache[base] then return cache[base] end
  local out = {}
  for key, value in pairs(base) do out[key] = value end
  out.onMiss = crash
  out.onProtect = function(ctx)
    ctx.say(Strings("%s\nprotected itself!", ctx.displayName(ctx.target)))
    crash(ctx, "protected")
    return true
  end
  cache[base] = out
  return out
end
return C
