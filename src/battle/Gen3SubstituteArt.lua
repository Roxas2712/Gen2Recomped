-- The native doll is a 64x64 OBJ centered on the battler's raw coordinates.
local M = {}
local V = require("src.core.GameVersion")
local Assets = require("src.render.Assets")

function M.pose(battle, battler)
  if not V.isGen3() or not battler then
    return nil
  end
  if battle.gen3Layout and not battle:gen3Layout() then
    return nil
  end
  local constants = battle.data and battle.data.constants or {}
  local record, coords = constants.gen3SubstituteArt, constants.gen3BattlerCoords
  if not record or record.version ~= 1 or record.width ~= 64 or record.height ~= 64 then
    return nil
  end
  local positions = coords and (battle:isDouble() and coords.doubles or coords.singles)
  local id = tonumber(battler.position) or (battler.isPlayer and 0 or 1)
  local raw = positions and positions[id + 1]
  local path = battler.isPlayer and record.back or record.front
  if not raw or type(path) ~= "string" then
    return nil
  end
  local dx, dy = battle:gen3AnimShake(battler)
  return {
    image = path,
    x = require("src.battle.Gen3Battle").fieldOffset(battle) + raw.x - 32 + (dx or 0),
    y = raw.y + (battler.isPlayer and 17 or 16) - 32 + (dy or 0),
  }
end

function M.draw(battle, battler)
  local pose = M.pose(battle, battler)
  if not pose then
    return false
  end
  local image = Assets.image(pose.image)
  love.graphics.draw(image, pose.x, pose.y)
  return true
end

return M
