-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Both parties are the completed cable battle's copies, not the saved team.
local mod = ...
local rows, order = {}, {}
if type(mod.supports) == "function" then
  mod.exports.supported = mod:supports("events", "link.battle_ended")
end
mod.exports.results, mod.exports.order = rows, order
mod.exports.off = mod.events:on("link.battle_ended", function(result)
  order[#order + 1] = "battle"
  rows[#rows + 1] = result
end)
mod.events:on("link.ended", function()
  order[#order + 1] = "session"
end)
