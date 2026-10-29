-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The linked private program's uniform interface is immutable. Keep only
-- bounded booleans with that variant, never another Shader/Texture owner.
local I={}
function I.has(record,variant,name,stats)
 local method=record.hook.hasUniform
 local bank=variant.uniformInterface
 if not bank or bank.method~=method then
  bank={method=method,values={},count=0};variant.uniformInterface=bank
 end
 local value=bank.values[name]
 if value~=nil then stats.interfaceHits=(stats.interfaceHits or 0)+1;return value end
 value=method(variant.shader,name)
 stats.interfaceQueries=(stats.interfaceQueries or 0)+1
 if bank.count<256 then bank.values[name]=value;bank.count=bank.count+1 end
 return value
end
return I
