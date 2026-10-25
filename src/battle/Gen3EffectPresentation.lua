-- Native status-animation controllers. Presentation never changes battle HP,
-- status, PP or RNG; the battle queue owns its lifetime and native frame clock.
local M = {}
local V = require("src.core.GameVersion")

function M.queue(battle, user, name)
  if not V.isGen3() or type(battle.queue) ~= "table" then
    return
  end
  battle.nextInsert = (battle.nextInsert or 0) + 1
  table.insert(battle.queue, battle.nextInsert, {
    anim = name,
    gbaNativeEffect = true,
    attackerIsPlayer = user.isPlayer,
    attackerPosition = user.position,
    targetPosition = user.position,
  })
end

local function startFade(from, target)
  -- The initialization callback performs the first background half-step.
  return { y = from, target = target, toggle = 1, delay = 0, active = true }
end

local function fade(state)
  local f = state.fade
  if not f.active then
    return
  end
  if f.finishing ~= nil then
    if f.finishing == 4 then
      f.active = false
    else
      f.finishing = f.finishing + 1
    end
    return
  end
  if f.toggle == 0 then
    if f.delay < 2 then
      f.delay = f.delay + 1
      return
    end
    f.delay = 0
    f.toggle = 1
    return
  end
  state.coeff = f.y / 16
  local k = state.coeff
  state.color = k > 0 and { (30 / 31 * k) / k, 0, (1 * k) / k } or { 0, 0, 0 }
  f.toggle = 0
  if f.y == f.target then
    f.finishing = 0
  else
    f.y = f.y + (f.target > f.y and 2 or -2)
  end
end

function M.start(battle, row)
  if not V.isGen3() or row.anim ~= "POISON" then
    return false
  end
  local user = row.attackerPosition ~= nil and battle:battlerAt(row.attackerPosition)
    or (row.attackerIsPlayer and battle.player or battle.enemy)
  if not user or not battle:animationsOn() or user.invulnerable or (user.substituteHP or 0) > 0 then
    return false
  end
  battle._gbaEffectPresentation = {
    user = user,
    frame = 0,
    x = 0,
    y = 0,
    coeff = 0,
    color = { 0, 0, 0 },
    sound = V.get() == "firered" and 141 or 148,
    soundLeft = 6,
    soundWait = 0,
  }
  return true
end

function M.update(battle)
  local state = battle._gbaEffectPresentation
  if not state then
    return false
  end
  state.frame = state.frame + 1
  -- The native sound task precedes shake and palette callbacks. Its
  -- thirteen-frame counter plays again on the following callback.
  if state.soundWait > 0 then
    state.soundWait = state.soundWait - 1
  elseif state.soundLeft > 0 then
    local options = battle.game and battle.game.save and battle.game.save.options or {}
    require("src.core.Sound").playId(
      battle.data,
      state.sound,
      { pan = state.user.isPlayer and -64 or 63, mono = options.stereo == false }
    )
    state.soundLeft, state.soundWait = state.soundLeft - 1, 13
  end
  if state.frame == 1 then
    state.x, state.shakes, state.shakeWait = 1, 18, 1
    state.fade, state.cycles = startFade(0, 12), 1
  else
    if state.shakes > 0 then
      if state.shakeWait > 0 then
        state.shakeWait = state.shakeWait - 1
      else
        state.shakes, state.shakeWait = state.shakes - 1, 2
        state.x = state.shakes == 0 and 0 or -state.x
      end
    end
    if not state.fade.active and state.cycles > 0 then
      state.fade, state.cycles = startFade(12, 0), state.cycles - 1
    end
    fade(state)
  end
  if state.soundLeft == 0 and state.shakes == 0 and not state.fade.active and state.cycles == 0 then
    battle._gbaEffectPresentation = nil
    return false
  end
  return true
end

function M.view(battle, user)
  local state = battle._gbaEffectPresentation
  return state and state.user == user and state or nil
end
return M
