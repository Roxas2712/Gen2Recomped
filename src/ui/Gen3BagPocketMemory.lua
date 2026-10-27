-- The cartridge keeps the active bag pocket between field/battle openings.
-- Keep that navigation state outside the save, scoped to this save and edition.
local M = {}
local sessions = setmetatable({}, {__mode = 'k'})

local function eligible(bag)
  return type(bag.game.save) == 'table' and not (bag.lockPocket or bag.store
    or bag.pick or bag.itemPc or bag.scriptRows or bag.noInput or bag.rsTutorial)
end

function M.restore(bag)
  if not eligible(bag) then return end
  local session = sessions[bag.game.save]
  local key = session and session[require('src.core.GameVersion').get()]
  for i, pocket in ipairs(bag.pockets) do
    if pocket.key == key then bag.pocket = i return end
  end
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
