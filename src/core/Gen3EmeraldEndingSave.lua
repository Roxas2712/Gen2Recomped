-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original CHAMPION_SAVEWARP bit, authoritative writer and ROM-derived home.
local M={}
function M.home(data,save)
  if not(save and save.version=='emerald')then return end
  local r=data and data.constants and data.constants.gen3PlayerRoom
  if type(r)~='table'then return end
  local p=save.player or{};local female=p.gender=='girl'or p.gender=='female'or p.gender==1 or p.female==true
  local map
  if female then map=r.girl else map=r.boy end
  if not(map and data.maps and data.maps[map]and type(r.x)=='number'and type(r.y)=='number'
    and r.x>=0 and r.y>=0 and r.x%1==0 and r.y%1==0)then return end
  return{map=map,x=r.x,y=r.y,facing='down'}
end
function M.write(game)
  local save=game.save
  if not M.home(game.data,save)then return false,'Emerald bedroom metadata is unavailable'end
  local old=save.specialSaveWarpFlags
  require('src.core.SaveData').setChampionSaveWarp(save)
  local ok,written=pcall(game.writeSave,game)
  if not ok or written~=true then
    save.specialSaveWarpFlags=old
    return false,ok and'Save writer refused the League save'or tostring(written)
  end
  return true
end
function M.apply(save,data)
  local home=M.home(data,save);local Save=require('src.core.SaveData')
  if not(home and Save.hasChampionSaveWarp(save))then return false end
  save.specialSaveWarpFlags=math.floor(tonumber(save.specialSaveWarpFlags)or 0)-Save.CHAMPION_SAVEWARP
  save.player=save.player or{};for key,value in pairs(home)do save.player[key]=value end
  save.lastHeal={map=home.map,x=home.x,y=home.y}
  return true
end
return M
