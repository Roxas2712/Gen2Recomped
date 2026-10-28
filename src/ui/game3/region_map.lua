-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local Query=require('src.compat.gen1.NativeRegionMap')
local M={}
function M.state()return Query.active('frlg')end
function M.isOpen()return M.state()~=nil end
function M.inputReady()return M.state()~=nil and Query.ready()end
function M.currentMapSec()if M.state()then return Query.section()end end
function M.canFlyToCursor()
 local s=M.state();return s~=nil and s.mode=='fly'and Query.destination(Query.section())~=nil
end
function M.flyBlockedByMapType()return not M.canFlyToCursor()end
return setmetatable(M,{__index=function(_,key)if key=='mode'then local s=M.state();return s and s.mode end end})
