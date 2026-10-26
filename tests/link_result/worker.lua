-- Run from either engine checkout with this directory supplied as arg[1].
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path = "./?.lua;./?/init.lua;" .. package.path
local root, version, api, format = assert(arg[1]), assert(arg[2]), tonumber(arg[3]), assert(arg[4])
local fixture = dofile(root .. "/tests/link_result/fixture.lua").new(root, version, api, format)
local rows = dofile(root .. "/tests/link_result/cases.lua").run(fixture)
print("LINK_RESULT_OBSERVED " .. require("src.link.Json").encode(rows))
fixture.close()
require("tests.modkit").finish("shared native link-battle completion")
