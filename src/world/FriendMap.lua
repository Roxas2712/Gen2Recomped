-- Matching navigation, rather than cartridge identity, admits map visitors.
-- Art, encounters and NPCs deliberately do not participate in this digest.
local M={}
local cache=setmetatable({},{__mode='k'})
local S=require('src.core.SaveSerializer')
local function hash(bytes)
 return love.data.encode('string','hex',love.data.hash('sha256',bytes))
end
function M.describe(world)
 local map=world and world.map
 if not map or not map.def or type(map.isWalkableCell)~='function' or type(map.isWaterCell)~='function' then return nil end
 local old=cache[map]
 if old and old.revision==map.gridRevision then return old.value end
 local def=map.def;local w,h=map.widthCells,map.heightCells
 if not w or not h then
  local cells=tonumber(map.tileset and map.tileset.blockCells) or 2
  w,h=(def.width or 0)*cells,(def.height or 0)*cells
 end
 if w<1 or h<1 or w*h>1000000 then return nil end
 local rows={}
 for y=0,h-1 do
  local row={}
  for x=0,w-1 do
   -- Elevation and native collision classes retain ledges, one-way walls
   -- and bridges; a visually similar floor is not sufficient evidence.
   row[#row+1]={map:isWalkableCell(x,y) and 1 or 0,map:isWaterCell(x,y) and 1 or 0,
    map.cellElevation and map:cellElevation(x,y) or 0,map:cellTile(x,y)}
  end
  rows[#rows+1]=row
 end
 local id=tostring(require('src.core.MapIdentity').sourceId(require('src.core.Game').data,map.id))
 local value={schema=1,map=id,width=w,height=h,layout=hash(S.encode({cells=rows,warps=def.warps or {},connections=def.connections or {}}))}
 cache[map]={revision=map.gridRevision,value=value}
 return value
end
function M.same(a,b)
 return type(a)=='table' and type(b)=='table' and a.schema==1 and b.schema==1 and a.map==b.map
  and a.width==b.width and a.height==b.height and a.layout==b.layout
end
return M
