-- Stable host-first state for the two authenticated result reports.
local P={}
function P.digest(value)
 return love.data.encode('string','hex',love.data.hash('sha256',require('src.core.SaveSerializer').encode(value)))
end
function P.same(a,b) return P.digest(a)==P.digest(b) end
return P
