-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Player battle tonics execute the imported GBA effect bytes, not Gen1 X items.
local V = require('src.core.GameVersion')
local Strings = require('src.core.Strings')
local M = {}
local function bit(n, mask) return math.floor(n / mask) % 2 == 1 end
local function friendship(data, mon, record, ow)
  local bytes = record.bytes
  local now = tonumber(mon.happiness) or 70
  local band = now < 100 and 0 or now < 200 and 1 or 2
  if not bit(bytes[6], 32 * 2 ^ band) then return end
  local index = 1
  for i = 0, band - 1 do if bit(bytes[6], 32 * 2 ^ i) then index = index + 1 end end
  local gain = record.friendship and record.friendship[index]
  if not gain then return end
  local held = data.items and data.items[mon.item]
  local effect = held and held.holdEffect
  if gain > 0 then
    if effect == 'FRIENDSHIP_UP' or effect == 27 then gain = math.floor(gain * 150 / 100) end
    local ball = data.items and data.items[mon.ball]
    if mon.ball == 'LUXURY_BALL' or ball and (ball.index == 11 or ball.numId == 11) then gain = gain + 1 end
    local map = ow and ow.map and ow.map.def
    if mon.metLocation ~= nil and map and mon.metLocation == map.regionMapSection then gain = gain + 1 end
  end
  mon.happiness = math.max(0, math.min(255, now + gain))
end

function M.use(data, save, id, record, battle, ow)
  if not V.isGen3() or not record or not (record.battle or record.mist) then return nil end
  local fail = {Strings("It won't have\nany effect.")}
  local bytes = record.bytes
  if not battle or type(bytes) ~= 'table' or #bytes < 6 then return 'failed', fail end
  for i = 1, 6 do
    local n = bytes[i]
    if type(n) ~= 'number' or n % 1 ~= 0 or n < 0 or n > 255 then return 'failed', fail end
  end
  -- A double battle's second player controller owns its own active recipient.
  local actor = battle.menuBattler and battle:menuBattler() or battle.player
  if not actor or not actor.isPlayer or not actor.mon or (actor.mon.hp or 0) <= 0 then return 'failed', fail end
  local changes, messages = {}, {}
  local labels = {attack='ATTACK', defense='DEFENSE', speed='SPEED', accuracy='ACCURACY', spatk='SP. ATK'}
  local raises = {
    {'attack', bytes[1] % 16}, {'defense', math.floor(bytes[2] / 16)},
    {'speed', bytes[2] % 16}, {'accuracy', math.floor(bytes[3] / 16)}, {'spatk', bytes[3] % 16},
  }
  for _, row in ipairs(raises) do
    local old = actor.stages[row[1]] or 0
    if row[2] > 0 and old < 6 then changes[#changes + 1] = {row[1], math.min(6, old + row[2])} end
  end
  local focus = math.floor(bytes[1] / 16) % 4 ~= 0 and not actor.focusEnergy
  local mist = bit(bytes[4], 128) and not require('src.battle.Gen3Mist').active(battle, actor)
  if #changes == 0 and not focus and not mist then return 'failed', fail end
  for _, row in ipairs(changes) do
    actor.stages[row[1]] = row[2]
    messages[#messages + 1] = Strings("%s's\n%s rose!", actor.name, Strings(labels[row[1]]))
  end
  if focus then actor.focusEnergy = true; messages[#messages + 1] = Strings("%s is getting\npumped!", actor.name) end
  if mist then
    if not require('src.battle.Gen3Mist').apply(battle, actor) then return 'failed', fail end
    messages[#messages + 1] = Strings("%s became\nshrouded in MIST!", actor.name)
  end
  friendship(data, actor.mon, record, ow or battle.game and battle.game.overworld)
  return 'consumed', messages
end
return M
