-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native recipients own HP-attacker and landed-move history independently.
local H = {}
local V = require("src.core.GameVersion")
local names = { [0] = "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST",
  "STEEL", "MYSTERY", "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC", "ICE", "DRAGON", "DARK" }
local types = { FIGHT = 1, ELECTR = 13, PSYCHC = 14, CURSE_TYPE = 9, PSYCHIC_TYPE = 14 }
for id, name in pairs(names) do types[name] = id end
local function rs()
  local version = V.get()
  return version == "ruby" or version == "sapphire"
end
local function nativeType(data, move, frame)
  local rows = data.constants and data.constants.types
  local row = rows and rows[move.type]
  local explicit = tonumber(move.gen3Type)
  if frame and move.type ~= frame.historyBaseType and explicit == frame.historyBaseTypeId then
    explicit = nil -- a copied row can retain the original type's numeric tag
  end
  return explicit or tonumber(move.type)
    or (type(row) == "table" and tonumber(row.index)) or types[move.type]
end
function H.begin(frame)
  local move = frame.move
  frame.historyMoveNum = tonumber(move and (move.index or move.numId)) or tonumber(frame.moveId)
  frame.historyBaseType = move and move.type
  frame.historyBaseTypeId = move and tonumber(move.gen3Type)
end
function H.prepare(battle, move, ordinaryMulti, tripleKick)
  local frame = battle._gbaMoveFrame
  if not frame then return end
  frame.effectiveMove = move
  if rs() and (ordinaryMulti or tripleKick) then frame.rsMultiHit = true end
end
-- Called only by the direct-hit command, after HP/Substitute adjustment and
-- before damage_dealt. Generic effect-context HP loss never enters here.
function H.hit(battle, user, target, move, substitute)
  if not V.isGen3() then return end
  local frame = battle._gbaMoveFrame
  if not frame or frame.user ~= user or frame.target ~= target then return end
  frame.hitsLanded = (frame.hitsLanded or 0) + 1
  frame.effectiveMove = move
  frame.historyType = nativeType(battle.data, move, frame)
  if not substitute then
    local position = user.position
    if position == nil then
      for pos = 0, 3 do
        if battle:battlerAt(pos) == user then position = pos; break end
      end
    end
    target.expLastHitById = position
  end
end
function H.moveEnd(battle, frame)
  if not V.isGen3() or not frame then return end
  local user, target = frame.user, frame.target
  if not user or not target or user == target then return end
  local move = frame.effectiveMove or frame.move
  local landed = not frame.noEffect and not frame.missed and (frame.hitsLanded or 0) > 0
  if frame.rsMultiHit then
    if frame.noEffect or frame.missed or frame.notObeyed then
      target.expLastLandedMove = 65535
      landed = false
    else landed = true end
  end
  if landed then
    target.expLastLandedMove = frame.historyMoveNum
    target.expLastHitByType = frame.historyType
    if frame.historyType == nil then
      target.expLastHitByType = move and nativeType(battle.data, move, frame) or nil
    end
  end
  -- R/S runs bookkeeping after each reached hit and again on script exit.
  -- A failed multi-hit script also clears the independently owned Mirror Move.
  if frame.rsMultiHit and (frame.noEffect or frame.missed or frame.notObeyed or target.faintQueued) then
    target.gbaLastTakenMove = nil
  end
end
function H.afterHit(battle)
  local frame = battle._gbaMoveFrame
  if frame and frame.rsMultiHit then
    require("src.battle.Gen3MirrorMove").history(battle, frame)
    H.moveEnd(battle, frame)
  end
end
local function uint(value, maximum)
  return value == nil or type(value) == "number" and value % 1 == 0 and value >= 0 and value <= maximum
end
function H.valid(actor)
  return uint(actor.expLastLandedMove, 65535) and uint(actor.expLastHitByType, 255)
    and (uint(actor.expLastHitById, 3) or actor.expLastHitById == 255)
end
function H.signature(actor, role)
  local attacker = actor.expLastHitById
  if role == "guest" and type(attacker) == "number" and attacker >= 0 and attacker <= 3 then
    attacker = attacker % 2 == 0 and attacker + 1 or attacker - 1
  end
  return ":hit=" .. tostring(actor.expLastLandedMove) .. "," .. tostring(actor.expLastHitByType)
    .. "," .. tostring(attacker)
end
return H
