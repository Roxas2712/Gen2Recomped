-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Selection/stock only: native public-hook and item execution gates are separate.
package.path = "./?.lua;./?/init.lua;" .. package.path
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local rows = dofile("tests/gen3_trainer_items/cases.lua").run(".", "gen2", version)
  require("tests.modkit").eq(#rows, 22, version .. " exercises every native item case")
end
require("tests.modkit").finish("native GBA trainer item selection and stock")
