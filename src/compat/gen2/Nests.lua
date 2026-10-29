-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Source records use screen pixels; the native import keeps hardware OAM
-- bytes. A live view translates only that boundary, never the native data.
local Native=require('src.world.Gen2Nests')
local Iteration=require('src.compat.gen1.TableIteration')
local M={LANDMARK_PALLET_TOWN=Native.LANDMARK_PALLET_TOWN,LANDMARK_FAST_SHIP=Native.LANDMARK_FAST_SHIP}
local cached=setmetatable({},{__mode='k'})
local offset={x=8,y=16}
local function read(state,key)
 local value=state.row[key]
 if value~=nil then return offset[key] and value-offset[key] or value end
 if key=='index'then return state.index end
 if key=='id'then return state.id end
end
local function snapshot(state)
 local result={}
 for key in Iteration.rawPairs(state.row)do result[key]=read(state,key)end
 if result.index==nil then result.index=state.index end
 if result.id==nil then result.id=state.id end
 return result
end
function M.find(...)return Native.find(...)end
function M.regionOf(...)return Native.regionOf(...)end
function M.landmarkId(...)return Native.landmarkId(...)end
function M.landmark(data,index)
 local row=Native.landmark(data,index)
 if not row then return nil end
 local bucket=cached[row]
 if not bucket then bucket=setmetatable({},{__mode='v'});cached[row]=bucket end
 if bucket[index]then return bucket[index]end
 local state={row=row,index=index,id=Native.landmarkId(data,index)}
 local view=setmetatable({},{__index=function(_,key)return read(state,key)end,
  __newindex=function(_,key,value)
   row[key]=offset[key] and value~=nil and value+offset[key] or value
  end})
 Iteration.register(view,snapshot,state)
 bucket[index]=view
 return view
end
return M
