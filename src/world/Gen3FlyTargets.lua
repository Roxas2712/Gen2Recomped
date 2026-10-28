-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The region picker and read-only consumers share its native visited targets.
local Identity=require('src.core.MapIdentity')
local M={}
function M.bySection(game)
 local data,save=game.data or{},game.save or{}
 local field=data.field or{};local out={}
 for _,id in ipairs(field.flyOrder or{})do
  local def=(data.maps or{})[id];local sec=def and tonumber(def.regionMapSection)
  if sec and(save.visited or{})[id]and(field.flyWarps or{})[id]and not out[sec]then out[sec]=id end
 end
 return out
end
function M.spot(game,id)
 local spot=Identity.lookup(game.data,(game.data.field or{}).flyWarps,id)
 if type(spot)=='table'then return spot end
end
function M.detached(game,id,spot)
 local maps=game.data and game.data.maps
 if type(id)~='string'or not(maps and maps[id])or type(spot)~='table'then return end
 for _,v in ipairs{spot.x,spot.y}do
  if type(v)~='number'or v~=v or v%1~=0 or v<0 or v==math.huge then return end
 end
 if spot.x==nil or spot.y==nil then return end
 return{map=require('src.core.Gen3MapNames').canonicalId(game.data,id),x=spot.x,y=spot.y}
end
function M.destination(game,section,targets)
 if type(section)~='number'or section%1~=0 or section<0 then return end
 local id=(targets or M.bySection(game))[section]
 if id then return M.detached(game,id,M.spot(game,id))end
end
return M
