-- Recreate the legacy parent's base data without sharing mutable mod state.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = require("tests.love_stub")
require("src.core.Data"):load()
assert(arg[1] and arg[1]:match("^tests/[%w_./-]+%.lua$"),"test path required")
dofile(arg[1])
