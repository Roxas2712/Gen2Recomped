-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local Query=require('src.compat.gen1.NativeRegionMap')
local M={}
-- Numeric protocol facts; actual RS classification remains with its owner.
local types={NONE=0,ROUTE=1,CITY_CANFLY=2,CITY_CANTFLY=3,BATTLE_FRONTIER=4}
M.TYPE=setmetatable({},{__index=types,__newindex=function()error('native region map types are read-only',2)end})
function M.active()return Query.active('hoenn')end
function M.isOpen()return M.active()~=nil end
function M.manifest()return Query.manifest()end
function M.mapSecType(view,section)return Query.kind(view,section)end
function M.flyWarpDestination(session,section,pos)
 local s=M.active();if not s then return end
 local game=require('src.compat.gen1.NativeSession').game()
 if session~=require('src.core.Game3').forNative(game).session then return end
 return Query.destination(section,pos)
end
return M
