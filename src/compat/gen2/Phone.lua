-- The imported phone catalogue, shared with the native Pokegear and scripts.
local Version = require('src.core.GameVersion')
local P = {}
local bound, edition
function P.useRegistry(data)
  bound, edition = data, Version.get()
end
return setmetatable(P, { __index = function(_, key)
  if key == 'CONTACTS' then
    if edition ~= Version.get() or not Version.isGen2() then return nil end
    return bound and bound.map_scripts and bound.map_scripts.phone
  end
end })
