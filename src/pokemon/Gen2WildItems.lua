-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Cartridge byte-domain rolls; source forceItem consumes no random value.
local M={NO_ITEM=192,SECOND_ITEM=20}
function M.choose(def,force,random)
  local items=def and def.items or{}
  if force then return items[1]end
  random=random or function(n)
    local rng=love and love.math and love.math.random or math.random
    return rng(0,n-1)
  end
  if random(256)<M.NO_ITEM then return nil end
  if random(256)<M.SECOND_ITEM then return items[2]end
  return items[1]
end
return M
