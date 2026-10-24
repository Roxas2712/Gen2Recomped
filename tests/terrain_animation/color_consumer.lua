-- Test mod: public handle only, no engine imports.
local mod = ...
local r = assert(mod.renderData)
mod.exports.supports = function(v) return r:supportsColor(v) end
mod.exports.colors = function(v, id, target) return r:colorTileset(v, id, target) end
mod.exports.weather = function(v, id) return r:weatherColor(v, id) end
