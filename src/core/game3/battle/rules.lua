-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Observation only; native Damage and the active battle still resolve hits.
local Native=require('src.compat.gen1.NativeSession')
local crit=setmetatable({},{__index=function(_,key)
 if key=='CHANCE'and Native.game()then return require('src.battle.Damage').gen3CritDenominators()end
end,__newindex=function()error('native critical rule observations are read-only',2)end})
return{crit=crit}
