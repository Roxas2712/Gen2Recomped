package.path = "./?.lua;./?/init.lua;" .. package.path
local checks, signature = dofile(arg[1] .. "/tests/gba_layout/legacy_consumer.lua")(require(arg[2] or "src.core.game3.layout_native"))
print(checks)
print(signature)
