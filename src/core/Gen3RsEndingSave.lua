-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- RS GameClear's bit 0 is separate from Emerald's CHAMPION_SAVEWARP bit 7.
-- The host atomic writer remains the only owner of durable save IO.
local M={}
local function rs(version)return version=='ruby'or version=='sapphire'end
local function hasBit(flags)return flags%2==1 end
function M.home(data,save)
  if not(save and rs(save.version))then return end
  local r=data and data.constants and data.constants.gen3PlayerRoom
  if type(r)~='table'then return end
  local p=save.player or{}
  local female=p.gender=='girl'or p.gender=='female'or p.gender==1 or p.female==true
  local map
  if female then map=r.girl else map=r.boy end
  if not(map and data.maps and data.maps[map]and type(r.x)=='number'and type(r.y)=='number'
    and r.x>=0 and r.y>=0 and r.x%1==0 and r.y%1==0)then return end
  return{map=map,x=r.x,y=r.y,facing='down'}
end
function M.write(game)
  local save=game.save;local home=M.home(game.data,save)
  if not home then return false,'RS bedroom metadata is unavailable'end
  local oldFlags,oldWarp=save.specialSaveWarpFlags,save.gen3RsEndingReturn
  local flags=math.floor(tonumber(oldFlags)or 0)
  save.specialSaveWarpFlags=hasBit(flags)and flags or flags+1
  save.gen3RsEndingReturn={format=1,version=save.version,map=home.map,x=home.x,y=home.y}
  local ok,written=pcall(game.writeSave,game)
  if not ok or written~=true then
    save.specialSaveWarpFlags,save.gen3RsEndingReturn=oldFlags,oldWarp
    return false,ok and'Save writer refused the League save'or tostring(written)
  end
  return true
end
function M.apply(save,data)
  local home=M.home(data,save);local warp=save and save.gen3RsEndingReturn
  local flags=math.floor(tonumber(save and save.specialSaveWarpFlags)or 0)
  if not(home and hasBit(flags)and type(warp)=='table'and warp.format==1 and warp.version==save.version
    and warp.map==home.map and warp.x==home.x and warp.y==home.y)then return false end
  save.player=save.player or{}
  for k,v in pairs(home)do save.player[k]=v end
  save.lastHeal={map=home.map,x=home.x,y=home.y}
  save.specialSaveWarpFlags=flags-1;save.gen3RsEndingReturn=nil
  return true
end
return M
