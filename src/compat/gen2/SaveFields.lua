-- Legacy player-field reads over native save owners. No duplicate wallet
-- or badge store is serialized. Authored player metatables take precedence.
local Version=require('src.core.GameVersion')
local Badges=require('src.inventory.Badges')
local M={}
local saves=setmetatable({}, {__mode='kv'})
local catalogs=setmetatable({}, {__mode='kv'})
local function badgeView(player,kanto)
  local save,data=saves[player],catalogs[player]
  local out={}
  for index,badge in ipairs(Badges.list(data))do
    if (kanto and index>8 or not kanto and index<=8) and Badges.has(save,badge)then
      out[badge.id:gsub('BADGE$','')]=true
    end
  end
  return out
end
local meta={
  __index=function(player,key)
    local save=saves[player]
    if not save then return nil end
    if key=='money' then return save.money end
    if key=='badges' then return badgeView(player,false) end
    if key=='kantoBadges' then return badgeView(player,true) end
  end,
  __newindex=function(player,key,value)
    local save=saves[player]
    if key=='money' and save then
      assert(type(value)=='number' and value==value,'money must be a number')
      save.money=math.max(0,math.min(999999,math.floor(value)))
    else rawset(player,key,value) end
  end,
}
function M.bind(save,data)
  if not Version.isGen2() or type(save and save.player)~='table' then return false end
  local player=save.player
  if getmetatable(player)~=nil and getmetatable(player)~=meta then return false end
  saves[player],catalogs[player]=save,data
  setmetatable(player,meta)
  return true
end
return M
