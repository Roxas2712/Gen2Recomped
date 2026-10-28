-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path = "./?.lua;./?/init.lua;" .. package.path
local root, backend, version = unpack(arg)
local rows, T = dofile(root .. "/tests/gen3_trainer_items/cases.lua").run(root, backend, version)
print("GBA_TRAINER_ITEMS_BASELINE " .. require("src.link.Json").encode(rows))
T.finish("native GBA trainer item baseline")
