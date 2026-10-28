-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Logical HP loss, announcements and move-owned reactions are separate phases.
-- In particular, writing mon.hp through a mod is not State.heal.
local F = {}
function F.begin(actor)
  actor.destinyBond, actor.grudge = nil, nil
end
function F.isFainted(actor)
  return not actor or actor._gbaLogicalFaint or not actor.mon or (tonumber(actor.mon.hp) or 0) <= 0
end
function F.mark(actor)
  if actor then actor._gbaLogicalFaint = true end
end
function F.healed(actor)
  if actor and actor.mon and actor.mon.hp > 0 then actor._gbaLogicalFaint = nil end
end
function F.valid(actor)
  return actor._gbaLogicalFaint == nil or type(actor._gbaLogicalFaint) == 'boolean'
end
function F.signature(actor)
  if not actor._gbaLogicalFaint and not actor.grudge and not actor.destinyBond then return '' end
  return ':faint='..tostring(not not actor._gbaLogicalFaint)
    ..',grudge='..tostring(not not actor.grudge)..',bond='..tostring(not not actor.destinyBond)
end
function F.pending(battle, actor)
  local frame = battle._gbaMoveFrame
  while frame do
    local state = frame.gbaExplosionState or frame.gbaExplosion
    if state and not state.done and state.user == actor then return state end
    frame = frame.parent
  end
  local state = battle._gbaActionFrame and battle._gbaActionFrame.gbaExplosion
  if state and not state.done and state.user == actor then return state end
end
function F.deferred(battle, actor)
  return battle._gbaFaintRelease ~= actor and F.pending(battle, actor) ~= nil
end
local function finish(battle, state)
  if not state or state.done then return end
  state.done = true
  if not F.isFainted(state.user) then return end
  local previous = battle._gbaFaintRelease
  battle._gbaFaintRelease = state.user
  local ok, err = pcall(battle.onFaint, battle, state.user)
  battle._gbaFaintRelease = previous
  if not ok then error(err, 0) end
end
function F.body(battle, frame)
  local state = frame and frame.gbaExplosionState
  if state and not state.defer then finish(battle, state) end
end
function F.flush(battle, owner)
  finish(battle, owner and owner.gbaExplosion)
end
function F.announce(actor)
  F.mark(actor)
  actor.mon.hp = 0
  actor.mon.status, actor.status, actor.toxicCounter, actor.sleepTurns = nil, nil, nil, nil
end
function F.react(battle, target)
  local frame = battle._gbaMoveFrame
  local user = frame and frame.user
  -- Residual/self faints have no attacking target script. Never select a
  -- convenient fallback foe, and never react to the user's own faint.
  if not frame or frame.target ~= target or user == target or not user then return end
  local Strings = require('src.core.Strings')
  local function name(actor) return actor.name or actor.mon.nickname or actor.mon.species end
  if target.destinyBond and battle:sideOf(user) ~= battle:sideOf(target) and not F.isFainted(user) then
    battle:sayNext(Strings('%s took\n%s with it!', name(target), name(user)))
    user.mon.hp = 0
    require('src.battle.Gen3FaintFriendship').capture(battle,user)
    F.mark(user)
    battle:drainNext(user, 0)
    battle:onFaint(user)
  end
  local index = frame.calledReactionSlot or frame.ppIndex
  if target.grudge and index and not F.isFainted(user) then
    local slot = (user.curMoves or user.mon.moves or {})[index]
    if slot then
      slot.pp = 0
      local move = frame.move and (frame.move.name or frame.move.id) or frame.moveId
      battle:sayNext(Strings("%s's %s\nlost all its PP!", name(user), move))
    end
  end
end
return F
