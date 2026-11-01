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
-- Position is counted in native atlas order, including earlier rows in
-- this contiguous section. The picker uses its actual imported cells.
function M.positionWithin(game,section,x,y)
 if type(section)~='number'or section%1~=0 or section<0 then return end
 local c=game.data and game.data.constants or{}
 local grid=c.gen3RegionMapLayout
 if not(grid and type(grid.cells)=='table'and type(grid.width)=='number'and type(grid.height)=='number')then return end
 local w,h=grid.width,grid.height
 if type(x)~='number'or type(y)~='number'or x%1~=0 or y%1~=0 or x<0 or y<0 or x>=w or y>=h then return end
 if grid.cells[y*w+x+1]~=section then return end
 local count=0
 for row=y,0,-1 do
  local found=false
  for col=0,w-1 do
   if grid.cells[row*w+col+1]==section then
    found=true
    if row<y or col<x then count=count+1 end
   end
  end
  if not found then break end
 end
 return count
end
local emeraldEnums
local function emeraldHeal(game,section,position)
 if require('src.core.GameVersion').get()~='emerald'or type(position)~='number'then return end
 if not emeraldEnums then
  local load=require('compat.gen1-rs.Loader').new('emerald')
  emeraldEnums={sections=load('src.core.game3.constants.ruby.region_map_sections').byName,
   heals=load('src.core.game3.constants.ruby.heal_locations').byName,
   flags=load('src.core.game3.constants.emerald.flags').byName}
 end
 local C=emeraldEnums;local index
 if section==C.sections.MAPSEC_EVER_GRANDE_CITY then
  local flag=assert(C.flags.FLAG_LANDMARK_POKEMON_LEAGUE)
  local flags=(game.save or{}).flags or{}
  local key=('FLAG_G3_%04X'):format(flag)
  local opened=flags[key]==true or flags[key]==1 or flags[flag]==true or flags[flag]==1
  index=opened and position==0 and C.heals.HEAL_LOCATION_EVER_GRANDE_CITY_POKEMON_LEAGUE
   or C.heals.HEAL_LOCATION_EVER_GRANDE_CITY
 elseif section==C.sections.MAPSEC_LITTLEROOT_TOWN then
  local gender=((game.save or{}).player or{}).gender
  local female=gender=='girl'or gender=='female'or gender=='F'or gender==1
  index=female and C.heals.HEAL_LOCATION_LITTLEROOT_TOWN_MAYS_HOUSE
   or C.heals.HEAL_LOCATION_LITTLEROOT_TOWN_BRENDANS_HOUSE
 end
 local rows=game.data.constants and game.data.constants.gen3HealLocations
 return index and rows and rows[index],index
end
function M.matchesEmeraldHeal(game,id,warp)
 if type(warp)~='table'or warp.nativeEmerald~=true then return false end
 local rows=game.data.constants and game.data.constants.gen3HealLocations
 local row=rows and rows[warp.healLocation]
 return type(row)=='table'and Identity.same(game.data,row.map,id)and warp.map==id
  and row.x==warp.x and row.y==warp.y
end
function M.destination(game,section,targets,position)
 if type(section)~='number'or section%1~=0 or section<0 then return end
 local id=(targets or M.bySection(game))[section]
 if id then
  local native,index=emeraldHeal(game,section,position)
  if native and Identity.same(game.data,native.map,id)then
   local destination=M.detached(game,id,native)
   if destination then destination.nativeEmerald,destination.healLocation=true,index end
   return destination
  end
  return M.detached(game,id,M.spot(game,id))
 end
end
return M
