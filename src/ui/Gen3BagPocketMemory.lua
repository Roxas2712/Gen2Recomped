-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The cartridge keeps the active bag pocket between field/battle openings.
-- Keep that navigation state outside the save, scoped to this save and edition.
local M = {}
local sessions = setmetatable({}, {__mode = 'k'})

local function eligible(bag)
  if type(bag.game.save) ~= 'table' or bag.pcList or bag.scriptRows
    or bag.noInput or bag.rsTutorial then return false end
  local pocket = bag.pockets[bag.pocket]
  -- FRLG's TM CASE and BERRY POUCH are separate screens, represented by
  -- synthetic fourth pockets in this host. They do not change the real bag.
  return pocket and not (bag.frlg and (pocket.key == 'TM_HM' or pocket.key == 'BERRY'))
end

function M.restore(bag)
  if not eligible(bag) then return end
  if not bag.lockPocket then
    local session = sessions[bag.game.save]
    local key = session and session[require('src.core.GameVersion').get()]
    for i, pocket in ipairs(bag.pockets) do
      if pocket.key == key then bag.pocket = i break end
    end
  end
  -- GoToBagMenu updates the shared pocket even when switching is disabled:
  -- Hoenn's berry pickers select BERRIES, FRLG's item PC selects ITEMS.
  M.remember(bag)
end

function M.remember(bag)
  if not eligible(bag) then return end
  local pocket = bag.pockets[bag.pocket]
  if not pocket then return end
  local session = sessions[bag.game.save] or {}
  sessions[bag.game.save] = session
  session[require('src.core.GameVersion').get()] = pocket.key
end

return M
