package.path = "./?.lua;./?/init.lua;" .. package.path
for _, version in ipairs({ "red", "gold", "silver", "crystal", "firered", "emerald" }) do
  dofile("tests/enemy_decision/cases.lua").run(".", "gen2", version, 3, "unified", function(f)
    f.T.eq(
      f.e.api:supports("hooks", "battle.enemy_switch_or_item"),
      f.gen == 2 or f.gen == 3,
      "public capability follows native decision producer"
    )
  end)
end
require("tests.modkit").finish("native enemy decision hook")
