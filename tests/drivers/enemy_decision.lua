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
    assert(
      V.get() == "firered" or V.get() == "emerald",
      "this optional ROM probe expects a registered GBA game"
    )
    local file = assert(io.open(itemRom, "rb"))
    local raw = file:read("*a")
    file:close()
    assert(raw:sub(0xAD, 0xB0) == (V.get() == "firered" and "BPRE" or "BPEE"), "wrong item-effect cartridge")
    local manifest = require("src.link.Json").decode(
      assert(love.filesystem.read("tools/rom_manifest_" .. V.get() .. ".json"))
    )
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
    print("PORTABILITY_ENEMY_RAW_IMPORT " .. V.get() .. " item-effects stage, memory only")
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
  local function fresh(mode, stock, double)
    game.save.party = { mon("PLAYER") }
    if double then
      game.save.party[2] = mon("ALLY")
    end
    local enemy = mon("ENEMY")
    enemy.hp = 200
    local bench = mon("BENCH")
    if double then
      bench.hp = 200
    end
    local definition = {
      name = "PORTABLE",
      items = stock or { potion },
      parties = { { { prebuilt = enemy }, { prebuilt = bench } } },
      doubleBattle = double,
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
    e.state.changes, e.state.clear = nil, nil
    return b, definition
  end
  local function turn(b, terminal)
    U.tap(game, "a")
    assert(b.phase == "moveSelect", "native FIGHT did not open move selection")
    U.tap(game, "a")
    for _ = 1, 4000 do
      if terminal and b.result and game.stack:top() ~= b then
        return
      end
      if b.phase == "menu" and not (b.pendingActions and next(b.pendingActions)) then
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
    b = fresh("mutate-fields")
    e.state.changes = { kind = "switch", slot = 2 }
    damage, beforeHit = 0, nil
    turn(b)
    assert(b.enemy.mon.nickname == "BENCH" and b.enemy.mon.hp < 500, "native delegated item becomes switch")
    assert(b.gen3ItemsUsed[1], "mutated native action retains its original stock reservation")
    print("PORTABILITY_ENEMY_CASE " .. V.get() .. " mutate-item-to-switch")
    for _, kind in ipairs({ "move", "other" }) do
      b = fresh("mutate-fields")
      e.state.changes = { kind = kind, move = game.data.moves[tackle].index, slot = 1, target = 0 }
      damage, beforeHit = 0, nil
      turn(b)
      assert(beforeHit == 200 and b.enemy.mon.hp == 200 - damage, "mutated native decision does not heal")
      assert(b.enemy.mon.moves[1].pp == 9, "native move/fallback spends the selected party slot PP")
      assert(b.enemy.mon.moves[1].id == tackle, "native mutation preserves party move ID")
      assert(b.gen3ItemsUsed[1], "native move/fallback preserves original consumed stock")
      print("PORTABILITY_ENEMY_CASE " .. V.get() .. " mutate-item-to-" .. kind)
    end
    for _, spec in ipairs({
      { name = "meta-item", changes = { meta = true }, enemyPP = 10 },
      {
        name = "watch-move",
        changes = {
          kind = "watch",
          move = game.data.moves[tackle].index,
          slot = 1,
          target = "player",
        },
        enemyPP = 9,
        enemyHits = true,
      },
      {
        name = "meta-watch",
        changes = {
          kind = "watch",
          move = game.data.moves[tackle].index,
          slot = 1,
          target = "player",
          meta = true,
        },
        enemyPP = 10,
      },
      { name = "sleep-blocks-run", changes = { kind = "run" }, sleep = true, enemyPP = 10 },
      { name = "trap-blocks-run", changes = { kind = "run" }, trapped = true, enemyPP = 10 },
      { name = "run", changes = { kind = "run" }, enemyPP = 10, result = "fled" },
      { name = "double-done-items", double = true, changes = { done = true }, enemyPP = 10 },
      {
        name = "double-meta-items-still-heal",
        double = true,
        changes = { meta = true },
        enemyPP = 10,
        heals = true,
      },
      { name = "double-run-blocked", double = true, changes = { kind = "run" }, enemyPP = 10 },
      {
        name = "double-forfeit",
        double = true,
        changes = { kind = "run", forfeit = true },
        enemyPP = 10,
        result = "forfeited",
      },
    }) do
      b = fresh("mutate-fields", spec.double and { potion, potion } or nil, spec.double)
      e.state.changes = spec.changes
      if spec.sleep then
        b.enemy.mon.status = "SLP"
      end
      if spec.trapped then
        b.enemy.trapped = true
      end
      damage, beforeHit = 0, nil
      turn(b, spec.result ~= nil)
      assert(b.result == spec.result, "native control terminal result " .. spec.name)
      assert(b.enemy.curMoves[1].pp == spec.enemyPP, "native control selected-slot PP " .. spec.name)
      assert(b.enemy.mon.hp == 200 - damage + (spec.heals and 20 or 0), "native control HP " .. spec.name)
      assert((b.player.mon.hp < 500) == not not spec.enemyHits, "native control incoming hit " .. spec.name)
      assert(b.gen3ItemsUsed[1], "native control keeps original stock reservation " .. spec.name)
      if spec.double then
        assert(b.gen3ItemsUsed[2], "both double controllers reserve original stock")
        assert(b:battlerAt(3).mon.hp == (spec.heals and 220 or 200), "right control item outcome")
      end
      print("PORTABILITY_ENEMY_CASE " .. V.get() .. " control-" .. spec.name)
    end
    b = fresh("suppress")
    b.player.curTypes, b.enemy.curTypes = { "FIRE" }, { "STEEL" }
    damage, beforeHit = 0, nil
    turn(b)
    assert(damage == 9 and b.enemy.mon.hp == 191, "native critical multiplier precedes Steel rounding")
    print("PORTABILITY_ENEMY_CASE " .. V.get() .. " critical-before-type")
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
    local oldBrain = game.data.ai_classes.PORTABLE_SMOKE_BRAIN
    local brainCalls, brainMode = 0, "pick"
    game.data.ai_classes.PORTABLE_SMOKE_BRAIN = {
      kind = "brain",
      brain = function(view)
        brainCalls = brainCalls + 1
        assert(
          view.battle == b and view.user == b.enemy and view.target == b.player,
          "native brain opaque handles"
        )
        assert(view.data == game.data and view.rng == b.rng, "native brain data and RNG")
        assert(e.state.calls == 1, "native item/switch hook precedes brain")
        assert(
          #view.moves == 2 and view.moves[2].slot == 2 and view.moves[2].usable,
          "native brain candidate slots"
        )
        local move = view.moves[2].move
        assert(move.id == "TACKLE" and move.index == 33 and move.effect == 0, "portable imported brain move")
        assert(move.gen3Type == 0 and move.category == "physical", "native brain move type/category")
        if brainMode == "error" then
          error("intentional native smoke brain failure")
        end
        return { slot = 2 }
      end,
    }
    for _, mode in ipairs({ "pick", "error" }) do
      b = fresh("suppress", {})
      b.trainer.aiClass = "PORTABLE_SMOKE_BRAIN"
      b.enemy.curMoves[2] = { id = tackle, pp = 10 }
      brainCalls, brainMode, damage, beforeHit = 0, mode, 0, nil
      turn(b)
      assert(brainCalls == 1, "one native brain decision")
      assert(
        b.enemy.curMoves[mode == "pick" and 2 or 1].pp == 9,
        "native brain/fallback spends selected slot"
      )
      assert(b.enemy.curMoves[mode == "pick" and 1 or 2].pp == 10, "native brain preserves unselected slot")
      print("PORTABILITY_ENEMY_CASE " .. V.get() .. " brain-" .. mode)
    end
    b = fresh("delegate")
    b.trainer.aiClass = "PORTABLE_SMOKE_BRAIN"
    b.enemy.encoreTurns, b.enemy.encoreMove = 2, tackle
    brainCalls, damage, beforeHit = 0, 0, nil
    turn(b)
    assert(brainCalls == 0 and beforeHit == 220, "native item precedes Encore and brain")
    game.data.ai_classes.PORTABLE_SMOKE_BRAIN = oldBrain
    print("PORTABILITY_ENEMY_CASE " .. V.get() .. " encore-item-before-brain")
  end
  if itemRom then
    b = fresh("delegate", { named(game.data.items, "X ATTACK") })
    damage, beforeHit = 0, nil
    turn(b)
    assert(b.enemy.stages.attack == 1 and b.gen3ItemsUsed[1], "actual native X Attack bytes run through turn")
    print("PORTABILITY_ENEMY_CASE " .. V.get() .. " raw-x-attack")
    b = fresh("delegate", { named(game.data.items, "GUARD SPEC.") })
    damage, beforeHit = 0, nil
    turn(b)
    assert(
      b.sides[2].mistTurns == 4 and b.gen3ItemsUsed[1],
      "actual native Guard Spec bytes and first residual"
    )
    print("PORTABILITY_ENEMY_CASE " .. V.get() .. " raw-guard-spec")
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
