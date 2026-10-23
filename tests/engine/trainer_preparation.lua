package.path = "./?.lua;./?/init.lua;" .. package.path
local Fixture = dofile("tests/trainer_preparation/fixture.lua")
local _, T = dofile("tests/trainer_preparation/cases.lua").run(function(noMod, failing)
  return Fixture.new(".", "gen2", "red", 3, "unified", noMod, failing)
end)
T.finish("portable trainer.before_battle")
