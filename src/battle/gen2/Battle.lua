-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The live Gen2 model boundary of the shared native controller. This is not
-- an alias to the screen and does not construct or advance a second battle.
local Runtime = require('src.mods.Runtime')
local Model = {}
local screens = setmetatable({}, { __mode = 'kv' })
local ended = setmetatable({}, { __mode = 'k' })

function Model.bind(model, screen)
  screens[model] = screen
  return model
end

local function owner(model)
  return assert(screens[model], 'native Gen2 model is not attached to a battle')
end

local function active(screen, mon)
  if screen.player and screen.player.mon == mon then return screen.player end
  if screen.enemy and screen.enemy.mon == mon then return screen.enemy end
end

function Model:moveDef(move)
  return owner(self):moveDef(move)
end

function Model:speciesDef(mon)
  return mon and self.data.pokemon and self.data.pokemon[mon.species] or nil
end

-- Raw native battle statistics, before stages, badges, status or held items.
-- Those modifiers remain in the actual damage/order owners and run once.
-- A caller's temporary shadow mon uses its own stats without changing a party
-- member. Active Transform statistics remain on the existing native wrapper.
function Model:battleStat(mon, key)
  local screen = screens[self]
  local battler = screen and active(screen, mon)
  local stats = battler and battler.curStats or mon and mon.stats
  return stats and stats[key]
end

function Model:sideOf(mon)
  local screen = owner(self)
  local battler = active(screen, mon)
  if battler then return battler.isPlayer and 'player' or 'enemy' end
end

-- Finish notification is owned by the native result path. Presentation stays
-- on the native queue; completeBattle/finish perform its actual screen return.
-- Existing native event consumers retain the screen in `battle`; the distinct
-- live model is also provided explicitly. No second save/party snapshot exists.
function Model:endBattle(outcome, details)
  local screen = owner(self)
  -- Link/spectator owners also publish ended/hostWin/guestWin, and a native
  -- extension may carry its own string. Do not narrow the owner's protocol.
  assert(type(outcome) == 'string' and outcome ~= '', 'invalid native Gen2 battle outcome')
  if ended[self] then return false end
  screen.result = outcome
  screen:restoreMimicked(screen.player)
  screen:restoreMimicked(screen.enemy)
  ended[self] = true
  local event = { battle=screen, model=self, result=outcome }
  if details and details.skipped then event.skipped = true end
  Runtime.emit('battle.ended', event)
  return true
end

return Model
