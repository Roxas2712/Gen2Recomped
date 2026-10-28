-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- GBA Haze resets every active stage in place and preserves other effects.
local H={}
local V=require('src.core.GameVersion')
local Strings=require('src.core.Strings')
local builtins=setmetatable({},{__mode='k'})
function H.run(ctx)
 for _,actor in ctx.battle:activeBattlers()do
  if actor.stages then
   for key in pairs(actor.stages)do actor.stages[key]=0 end
  end
 end
 return{Strings('All stat changes\nwere eliminated!')},true
end
function H.builtin(id,base)
 if id~='HAZE_EFFECT'or not base or not V.isGen3()then return base end
 if builtins[base]then return builtins[base]end
 local out={};for key,value in pairs(base)do out[key]=value end
 out.run=H.run;builtins[base]=out;builtins[out]=out
 return out
end
return H
