-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- RS draws a 64x64 frame around GetBattlerSpriteFinal_Y, not opaque feet.
local M={}
function M.place(battle,battler,img,scale,fieldOffset)
  local data=battle.data;local c=data and data.constants
  local profile=c and c.gen3RsHealthbox
  if not profile or(profile.version~='ruby'and profile.version~='sapphire')then return end
  local species=battler.species or(battler.mon and battler.mon.species)
  local def=species and data.pokemon and data.pokemon[species]
  if not def or img:getWidth()~=64 or img:getHeight()~=64 then return end
  local coords=c.gen3BattlerCoords
  local double=battle.isDouble and battle:isDouble()
  local rows=coords and(double and coords.doubles or coords.singles)
  local pos=tonumber(battler.position)or(battler.isPlayer and 0 or 1)
  local anchor=rows and rows[pos+1]
  local body
  if battler.isPlayer then body=def.backPicCoords else body=def.frontPicCoords end
  if not anchor or not body or type(body.yOffset)~='number'then return end
  local lift=not battler.isPlayer and c.gen3Elevation and c.gen3Elevation[species]or 0
  return anchor.x+(fieldOffset or 0)-32*scale,
    anchor.y+body.yOffset-lift-32*scale
end
return M
