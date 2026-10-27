-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Live cartridge-numbered offsets; changing datasets never keeps an old row.
local Native=require('src.compat.gen1.NativeSession')
local Ids=require('src.compat.gen1.BattleIds')
local P={}
-- Base sprite anchors are independent of the current render transform and
-- animation coordinate overrides. Read the live cartridge record each time;
-- the returned point is detached so callers cannot edit native layout data.
function P.battlerCoords(double,id)
  if double~=nil and type(double)~='boolean'then return nil,'double must be a boolean'end
  id=id==nil and 0 or tonumber(id)
  if not id or id~=id or id%1~=0 or id<0 or id>3 then return nil,'invalid battler slot'end
  local game,why=Native.game();if not game then return nil,why end
  local constants=game.data and game.data.constants
  local imported=constants and constants.gen3BattlerCoords
  local layout=imported and(double and imported.doubles or imported.singles)
  local point=layout and layout[id+1]
  if not point then
    local coords=require('src.core.game3.battle.anim_coords')
    point=(double and coords.DOUBLES or coords.SINGLES)[id]
  end
  local x,y=point and(point.x or point[1]),point and(point.y or point[2])
  local function finite(n)return type(n)=='number'and n==n and n~=math.huge and n~=-math.huge end
  if not finite(x)or not finite(y)then return nil,'invalid native battler coordinates'end
  return{x=x,y=y,[1]=x,[2]=y}
end
for _,kind in ipairs{'front','back','elev'}do
 P[kind]=setmetatable({},{__index=function(_,id)
  local g=Native.game();if not g then return nil end
  local key=Ids.new(g.data):native('pokemon',id);local row=key and g.data.pokemon[key]
  if not row then return nil end
  if kind=='elev'then return g.data.constants.gen3Elevation and g.data.constants.gen3Elevation[key]or 0 end
  local coords=kind=='front'and row.frontPicCoords or row.backPicCoords
  return coords and coords.yOffset
 end,__newindex=function()error('native picture coordinates are read-only',2)end})
end
return P
