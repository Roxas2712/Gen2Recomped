return function(f, backend)
  if backend ~= "gen2" or f.gen ~= 2 then
    return
  end
  local T = f.T
  local copy = require("src.mods.Merge").deepCopy
  local seed = f.freshDecision({ "POTION" })
  local definition = {
    name = "FOE",
    items = { "POTION" },
    attributes = { 0, 0, 7, 9, 11, 1, 0 },
    parties = { { { prebuilt = copy(seed.enemy.mon) }, { prebuilt = copy(seed.enemyParty[2]) } } },
  }
  f.data.trainers.PORTABLE_CONSTRUCTOR = definition
  local Battle = require("src.battle.BattleState")
  local first = Battle.newTrainer(f.game, "PORTABLE_CONSTRUCTOR", 1)
  first:syncSides()
  first.enemy.mon.hp = 1
  f.battle = first
  f.e.state.mode, f.e.state.decision = "override", { kind = "item", item = "POTION" }
  T.eq(f.query(), true, "Gen-2 constructor invokes immediate public item query")
  T.eq(first.enemy.mon.hp, 21, "Gen-2 constructor target receives immediate healing")
  T.eq(#first.trainer.items, 0, "Gen-2 battle consumes its own stock")
  T.eq(#definition.items, 1, "Gen-2 battle cannot consume shared imported class stock")
  for i, value in ipairs(definition.attributes) do
    T.eq(first.trainer.attributes[i], value, "Gen-2 constructor preserves imported attribute byte")
  end
  local second = Battle.newTrainer(f.game, "PORTABLE_CONSTRUCTOR", 1)
  T.eq(#second.trainer.items, 1, "a Gen-2 rematch starts with fresh native stock")
  T.neq(first.trainer.items, second.trainer.items, "Gen-2 rematches do not share mutable stock")
end
