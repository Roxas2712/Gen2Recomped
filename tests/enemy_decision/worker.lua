package.path = "./?.lua;./?/init.lua;" .. package.path
local root, backend, version, api, format = unpack(arg)
local rows =
  dofile(root .. "/tests/enemy_decision/cases.lua").run(root, backend, version, tonumber(api), format)
print("ENEMY_DECISION " .. require("src.link.Json").encode(rows))
require("tests.modkit").finish("native enemy decision contracts")
