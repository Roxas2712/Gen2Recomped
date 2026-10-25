package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Fixture = dofile("tests/held_item/fixture.lua")
local TurnOrder = require("src.battle.TurnOrder")
local Order = require("src.battle.Gen3AIOrder")
for _, version in ipairs({ "firered", "emerald" }) do
  for _, mode in ipairs({ { 1, "native" }, { 2, "native" }, { 2, "unified" }, { 3, "unified" } }) do
    local f = Fixture.new(".", "gen2", version, mode[1], mode[2])
    f.reset()
    local b, s = f.battle, f.e.state
    b.player.curStats.speed, b.enemy.curStats.speed = 10, 200
    b.randomTurnNumber = 0
    s.mode, s.trigger, s.holder, s.requiresItem = "override", "priority", "PLAYER", false
    s.effect, s.parameter = "HELD_QUICK_CLAW", 256
    T.eq(TurnOrder.firstMover(b.player, { priority = 0 }, b.enemy, { priority = 0 }, b.rng, false, b), true,
      "public virtual Quick Claw reaches actual native comparator")
    T.eq(TurnOrder.firstMover(b.player, { priority = 0 }, b.enemy, { priority = 1 }, b.rng, false, b), false,
      "public virtual claw cannot beat greater move priority")
    T.eq(Order.result({ user = b.player, target = b.enemy, battle = b, rng = b.rng }), 1,
      "AI predictor uses physical metadata without virtual held-item substitution")
    b.randomTurnNumber = 65535
    T.eq(TurnOrder.firstMover(b.player, { priority = 0 }, b.enemy, { priority = 0 }, b.rng, false, b), false,
      "public 256 byte chance obeys strict native threshold at maximum word")
    f.close()
  end
end
T.finish("public priority integration")
