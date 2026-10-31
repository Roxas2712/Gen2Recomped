-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Birch's first opponent differs between the paired games and Emerald.
-- Keep canonical host IDs, witnessed by the cartridge's own route data.
local M={}
local species={ruby='POOCHYENA',sapphire='POOCHYENA',emerald='ZIGZAGOON'}
function M.extract(edition,maps,encounters)
 local wanted=species[edition];if not wanted then return nil,'unsupported rescue edition'end
 local route=maps and maps.MAP_G00_N16;local object
 for _,row in ipairs(route and route.objects or{})do
  if tonumber(row.localId)==4 then
   if object then return nil,'ambiguous rescue object'end
   object=row
  end
 end
 if not object then return nil,'missing rescue object'end
 local grass=encounters and encounters.MAP_G00_N16 and encounters.MAP_G00_N16.grass
 local witnessed=false
 for _,slot in ipairs(grass and grass.slots or{})do
  if slot.species==wanted and tonumber(slot.min)==2 then witnessed=true end
 end
 if not witnessed then return nil,'missing native level-two rescue species'end
 return{species=wanted,level=2,mapId='MAP_G00_N16',localId=4,graphicsId=object.graphicsId,canLose=true,
  source=('ROM:MAP_G00_N16 object 4 (sprite %s) + own level-two %s grass slot'):format(tostring(object.graphicsId),wanted)}
end
return M
