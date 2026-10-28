-- Typed access to the pinned native RS enums, without host/global caches.
local M={}
function M.new(load)
  local c={}
  for _,name in ipairs({'region_map_sections','flags','vars','map_groups','heal_locations'})do
    c[name]=load('src.core.game3.constants.ruby.'..name)
  end
  function c:id(family,name)return assert(self[family]).byName[name]end
  function c:require(family,name)return assert(self:id(family,name),'Missing native RS constant '..name)end
  function c:flag(name)return self:id('flags',name)end
  function c:var(name)return self:id('vars',name)end
  function c:name(family,id,prefix)
    return ((assert(self[family]).byId or {})[prefix or '']or{})[id]
  end
  return c
end
return M
