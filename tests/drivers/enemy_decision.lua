-- Imported-data native input/controller smoke, in an isolated identity only.
-- Test parties and stock are in memory; no normal SAVE action is performed.
return function(game)
  local U, V = require("tests.drivers.util"), require("src.core.GameVersion")
  assert(love.filesystem.getIdentity() ~= "Gen2Recomp", "use isolated identity")
  assert(os.getenv("POKEPORT_SKIP_LEGACY_MIGRATION") == "1", "disable migration")
  assert(os.getenv("POKEPORT_ISOLATED_TESTING") == "1", "use isolated wrapper")
  assert(V.get() == os.getenv("POKEPORT_VERSION"), "wrong imported cartridge")
  local title
  for _ = 1, 120 do
    local top = game.stack:top()
    if top and type(top.onNewGame) == "function" then
      title = top
      break
    end
    U.tap(game, "start")
    U.wait(5)
  end
  assert(title, "native title missing")
  U.wait(30)
  title.onNewGame()
  U.wait(60)
  assert(game.save and game.overworld, "native New Game missing")
  local e = assert(game.mods.exports.portable_enemy_decision, "install enemy-decision example")
  assert(e.available, "native producer unavailable")
  local P, Battle = require("src.pokemon.Pokemon"), require("src.battle.BattleState")
  local function named(registry, name)
    for id, def in pairs(registry) do
      if def.name == name then
        return id
      end
    end
    error("missing imported record " .. name)
  end
  local species = named(game.data.pokemon, "MEW")
  local tackle = named(game.data.moves, "TACKLE")
  local potion = named(game.data.items, "POTION")
  local itemRom = os.getenv("POKEPORT_ITEM_EFFECT_ROM")
  if itemRom then
    assert(V.get() == "firered", "this optional ROM probe expects FireRed")
    local file = assert(io.open(itemRom, "rb"))
    local raw = file:read("*a")
    file:close()
    assert(raw:sub(0xAD, 0xB0) == "BPRE", "wrong item-effect cartridge")
    local manifest =
      require("src.link.Json").decode(assert(love.filesystem.read("tools/rom_manifest_firered.json")))
    local extractor = require("src.import.RomExtractorGen3").new(raw, V.info(), manifest)
    extractor._constants = { itemOrder = game.data.constants.itemOrder }
    local generated
    extractor.write = function(_, name, value)
      assert(name == "constants", "unexpected partial-import output")
      generated = value
    end
    extractor:extractItemEffects()
    assert(generated and generated.gen3ItemEffects[potion].bytes[7] == 20, "actual Potion effect bytes")
    game.data.constants.gen3ItemEffects = generated.gen3ItemEffects
    print("PORTABILITY_ENEMY_RAW_IMPORT FireRed item-effects stage, memory only")
  end
  game.save.options.ruleset = false
  game.save.options.textSpeed, game.save.options.animations = 1, false
  local world = game.overworld
  local function mon(name)
    local p = P.new(game.data, species, 30)
    p.hp, p.nickname = 500, name
    p.stats = { hp = 500, attack = 50, defense = 50, speed = 50, special = 50, spatk = 50, spdef = 50 }
    p.moves = { { id = tackle, pp = 10 } }
    return p
  end
  local function fresh(mode, stock)
    game.save.party = { mon("PLAYER") }
    local enemy = mon("ENEMY")
    enemy.hp = 200
    local definition = {
      name = "PORTABLE",
      items = stock or { potion },
      parties = { { { prebuilt = enemy }, { prebuilt = mon("BENCH") } } },
    }
    local old = game.data.trainers.PORTABLE_NATIVE_DECISION
    game.data.trainers.PORTABLE_NATIVE_DECISION = definition
    local b = Battle.newTrainer(game, "PORTABLE_NATIVE_DECISION", 1)
    game.data.trainers.PORTABLE_NATIVE_DECISION = old
    b:syncSides()
    b.player.curStats.speed = 80
    b.rng = function(lo)
      return lo or 0
    end
    b.queue, b.phase, b.afterQueue, b.menuIndex = {}, "menu", "menu", 1
    b.introSlide, b.fx = 0, {}
    game.stack.states = { world, b }
    e.state.mode, e.state.calls, e.state.contexts = mode, 0, {}
    e.state.decision = { kind = "item", item = "POTION" }
    return b, definition
  end
  local function turn(b)
    U.tap(game, "a")
    assert(b.phase == "moveSelect", "native FIGHT did not open move selection")
    U.tap(game, "a")
    for _ = 1, 4000 do
      if b.phase == "menu" then
        return
      end
      U.tap(game, "a")
    end
    error("native enemy-decision turn did not settle")
  end
  local damage, beforeHit
  local stops = {
    e.api.events:on("battle.damage_dealt", function(ctx)
      if ctx.target and ctx.target.mon.nickname == "ENEMY" then
        damage = damage + ctx.damage
      end
    end),
    e.api.events:on("battle.move_used", function(ctx)
      if ctx.user and ctx.user.mon.nickname == "PLAYER" then
        beforeHit = ctx.target and ctx.target.mon.hp
      end
    end),
  }
  for _, mode in ipairs({ "suppress", "override", "repeat", "fail-after" }) do
    local b, definition = fresh(mode)
    damage, beforeHit = 0, nil
    turn(b)
    assert(e.state.calls == 1 and e.state.contexts[1] == b, "native public query and exact handle")
    -- Old imported Gen-2 caches have no native AI attributes. Only the
    -- explicit action has an effect there; the GBA parsed heal fallback works.
    local heals = mode == "override" or V.generation() == 3 and mode ~= "suppress"
    assert(b.enemy.mon.hp == 200 - damage + (heals and 20 or 0), "native item/HP result")
    assert(beforeHit == (heals and 220 or 200), "native item runs before the faster player's hit")
    assert(#definition.items == 1, "native imported definition stock remains unchanged")
    if V.generation() == 2 then
      assert(#b.trainer.items == (heals and 0 or 1), "Gen-2 battle stock consumption")
    else
      assert(((b.gen3ItemsUsed or {})[1] == true) == heals, "GBA stock reservation")
    end
    print("PORTABILITY_ENEMY_CASE " .. V.get() .. " " .. mode)
  end
  local b = fresh("override")
  e.state.decision = { kind = "switch", index = 2 }
  damage, beforeHit = 0, nil
  turn(b)
  assert(b.enemy.mon.nickname == "BENCH" and b.enemy.mon.hp < 500, "native incoming switch target takes hit")
  assert(b.enemyParty[1].hp == 200, "native outgoing occupant is preserved")
  print("PORTABILITY_ENEMY_CASE " .. V.get() .. " switch")
  if V.generation() == 3 then
    b = fresh("suppress")
    game.data.ai_classes = game.data.ai_classes or {}
    local oldClass = game.data.ai_classes.PORTABLE_SMOKE_CLASS
    game.data.ai_classes.PORTABLE_SMOKE_CLASS = { kind = "class", uses = 1, item = potion }
    b.trainer.aiClass = "PORTABLE_SMOKE_CLASS"
    damage, beforeHit = 0, nil
    turn(b)
    assert(e.state.calls == 0 and beforeHit == 220, "native mod class item precedes suppressed hook")
    assert(b.enemy.mon.hp == 220 - damage, "native class item and incoming hit execute")
    local previous = b.enemy.mon.hp
    damage, beforeHit = 0, nil
    turn(b)
    assert(e.state.calls == 1 and b.enemy.mon.hp == previous - damage, "spent native class reaches hook")
    game.data.ai_classes.PORTABLE_SMOKE_CLASS = oldClass
    print("PORTABILITY_ENEMY_CASE " .. V.get() .. " class-before-hook-and-spent")
  end
  if itemRom then
    b = fresh("delegate", { named(game.data.items, "X ATTACK") })
    damage, beforeHit = 0, nil
    turn(b)
    assert(b.enemy.stages.attack == 1 and b.gen3ItemsUsed[1], "actual native X Attack bytes run through turn")
    print("PORTABILITY_ENEMY_CASE firered raw-x-attack")
    b = fresh("delegate", { named(game.data.items, "GUARD SPEC.") })
    damage, beforeHit = 0, nil
    turn(b)
    assert(
      b.sides[2].mistTurns == 4 and b.gen3ItemsUsed[1],
      "actual native Guard Spec bytes and first residual"
    )
    print("PORTABILITY_ENEMY_CASE firered raw-guard-spec")
  end
  b = fresh("delegate")
  e.state.stop()
  damage, beforeHit = 0, nil
  turn(b)
  assert(e.state.calls == 0, "native unsubscribe removes producer callback")
  assert(b.enemy.mon.hp == 200 - damage + (V.generation() == 3 and 20 or 0), "native no-subscriber behavior")
  for _, stop in ipairs(stops) do
    stop()
  end
  print("PORTABILITY_ENEMY_DECISION_PASS " .. V.get())
  love.event.quit(0)
end
