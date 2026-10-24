package.path = "./?.lua;./?/init.lua;" .. package.path
for _, version in ipairs({ "red", "gold", "silver", "crystal", "firered", "emerald" }) do
  dofile("tests/enemy_decision/cases.lua").run(".", "gen2", version, 3, "unified")
end
require("tests.modkit").finish("native enemy decision hook")
