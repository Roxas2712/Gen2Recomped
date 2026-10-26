-- Recreate the legacy parent's base data without sharing mutable mod state.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = require("tests.love_stub")
local data=require("src.core.Data")
data:load()
local game=require("src.core.Game")
game.data=data;game.save=require("src.core.SaveData").newGame()
game.input=require("src.core.Input");game.input:init()
game.stack=require("src.core.StateStack");game.stack:init()
require("src.render.Font").load(data)
require("src.battle.TypeChart").load(data)
assert(arg[1] and arg[1]:match("^tests/[%w_./-]+%.lua$"),"test path required")
dofile(arg[1])
