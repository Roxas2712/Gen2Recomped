package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local checks = dofile("tests/gba_layout/legacy_consumer.lua")(require("src.compat.gen1.DecodedLayout"))
T.check(checks > 240, "unchanged legacy layout consumer exercises sampling, writes, workers and invalidation")
T.finish("Classified decoded layout snapshots (" .. checks .. " consumer checks)")
