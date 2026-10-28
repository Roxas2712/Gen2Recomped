-- Keep shader translation at the old mod API boundary. Native engine and
-- API-3 shader sources retain their own coordinate contract.
local Clip=require('src.render.ClipSpaceCompat')
local Runtime=require('src.mods.Runtime')
local M={}
local active,graphics,wrapped,previous
local function legacyCaller()
 if not active then return false end
 local source
 for level=3,9 do
  local info=debug and debug.getinfo and debug.getinfo(level,'S')
  if not info then break end
  if info.what~='C' then source=info.source;break end
 end
 if source and (source:match('^@src/')or source:match('^@%./src/'))then return false end
 local id=Runtime.currentMod
 local mod=id and active.mods[id]
 if not mod and source then
  for _,candidate in pairs(active.mods or {})do
   local prefix='@'..candidate.path..'/'
   if source:sub(1,#prefix)==prefix then mod=candidate;break end
  end
 end
 return mod and (mod.manifest.api or 1)<3 or false
end
function M.install(loader)
 active=loader
 local g=love and love.graphics
 if not (g and type(g.newShader)=='function')then return end
 if g==graphics and g.newShader==wrapped then return end
 graphics,previous=g,g.newShader
 local base=previous
 wrapped=function(pixel,vertex,...)
  if legacyCaller()then
   pixel=Clip.legacyShader(pixel)
   vertex=Clip.legacyShader(vertex)
  end
  return base(pixel,vertex,...)
 end
 g.newShader=wrapped
end
function M.reset()active=nil end
return M
