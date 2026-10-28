-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- FR/LG EnterHallOfFame saves bit 0 and Pallet's continueGameWarp.
-- HEAL_LOCATION_PALLET_TOWN is the first native heal record, not its indoor
-- whiteout destination. Durable IO remains owned by Game.writeSave.
local M={}
local function frlg(save)return save and(save.version=='firered'or save.version=='leafgreen')end
function M.home(data,save)
  if not frlg(save)then return end
  local r=data and data.constants and data.constants.gen3HealLocations
  r=type(r)=='table'and r[1]
  if not(type(r)=='table'and r.index==1 and r.outdoor==true and type(r.map)=='string'
    and data.maps and data.maps[r.map]and type(r.x)=='number'and type(r.y)=='number'
    and r.x>=0 and r.y>=0 and r.x%1==0 and r.y%1==0)then return end
  local heal=r.respawn
  if not(type(heal)=='table'and data.maps[heal.map]and type(heal.x)=='number'and type(heal.y)=='number'
    and heal.x>=0 and heal.y>=0 and heal.x%1==0 and heal.y%1==0)then return end
  return{map=r.map,x=r.x,y=r.y,facing='down'},{map=heal.map,x=heal.x,y=heal.y}
end
function M.write(game)
  local save=game.save;local home=M.home(game.data,save)
  if not home then return false,'FR/LG Pallet heal-location metadata is unavailable'end
  local oldFlags,oldWarp=save.specialSaveWarpFlags,save.continueGameWarp
  local flags=math.floor(tonumber(oldFlags)or 0)
  save.specialSaveWarpFlags=flags%2==1 and flags or flags+1
  save.continueGameWarp={map=home.map,x=home.x,y=home.y}
  local ok,written=pcall(game.writeSave,game)
  if not ok or written~=true then
    save.specialSaveWarpFlags,save.continueGameWarp=oldFlags,oldWarp
    return false,ok and'Save writer refused the League save'or tostring(written)
  end
  return true
end
function M.apply(save,data)
  local home,heal=M.home(data,save);local warp=save and save.continueGameWarp
  local flags=math.floor(tonumber(save and save.specialSaveWarpFlags)or 0)
  if not(home and flags%2==1 and type(warp)=='table'and warp.map==home.map and warp.x==home.x and warp.y==home.y)then return false end
  save.player=save.player or{};for key,value in pairs(home)do save.player[key]=value end
  save.lastHeal=heal
  save.specialSaveWarpFlags=flags-1
  return true
end
return M
