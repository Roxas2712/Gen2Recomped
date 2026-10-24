-- Fresh Gold trainer-stage import into memory, then real native battle input.
return function(game)
  local U, V = require("tests.drivers.util"), require("src.core.GameVersion")
  assert(love.filesystem.getIdentity() ~= "Gen2Recomp", "use isolated identity")
  assert(os.getenv("POKEPORT_SKIP_LEGACY_MIGRATION") == "1", "disable migration")
  assert(os.getenv("POKEPORT_ISOLATED_TESTING") == "1", "use isolated wrapper")
  assert(V.get() == "gold" and os.getenv("POKEPORT_VERSION") == "gold", "Gold import probe only")
  local file = assert(io.open(assert(os.getenv("POKEPORT_GEN2_TRAINER_ROM")), "rb"))
  local raw = file:read("*a")
  file:close()
  local sha = love.data.encode("string", "hex", love.data.hash("sha1", raw))
  local complete = assert(love.filesystem.read("gold/rom-cache.complete"))
  assert(
    sha == "d8b8a3600a465308c9953dfa04f0081c05bdcb94" and complete:find(sha, 1, true),
    "trainer ROM must match the isolated Gold cache"
  )
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
  local manifest =
    require("src.link.Json").decode(assert(love.filesystem.read("tools/rom_manifest_gold.json")))
  local extractor = require("src.import.RomExtractorGen2").new(raw, "gold", manifest)
  local imported = extractor:gen2Trainers().byClass
  local id, definition
  local count = 0
  for key, row in pairs(imported) do
    count = count + 1
    assert(#row.attributes == 7, "fresh class has all seven native attribute bytes")
    if row.index == 63 then
      id, definition = key, row
    end
  end
  assert(count == 66 and definition, "actual Gold trainer group import")
  assert(
    #definition.items == 2 and definition.items[1] == "ITEM_014" and definition.items[2] == "ITEM_014",
    "actual Red stock preserves both Full Restore slots"
  )
  local copy = require("src.mods.Merge").deepCopy
  local original = copy(definition)
  local e = assert(game.mods.exports.portable_enemy_decision, "install decision example")
  assert(e.available, "native public decision producer unavailable")
  local P, Battle = require("src.pokemon.Pokemon"), require("src.battle.BattleState")
  local function named(registry, name)
    for key, row in pairs(registry) do
      if row.name == name then
        return key
      end
    end
    error("missing imported record " .. name)
  end
  local species, tackle = named(game.data.pokemon, "MEW"), named(game.data.moves, "TACKLE")
  game.save.options.ruleset = false
  game.save.options.textSpeed, game.save.options.animations = 1, false
  local b, damage, beforeHit
  local stops = {
    e.api.events:on("battle.damage_dealt", function(ctx)
      if ctx.target and ctx.target.mon.nickname == "FRESH_RED" then
        damage = damage + ctx.damage
      end
    end),
    e.api.events:on("battle.move_used", function(ctx)
      if ctx.user and ctx.user.mon.nickname == "PLAYER" then
        beforeHit = ctx.target and ctx.target.mon.hp
      end
    end),
  }
  local function fresh()
    local player = P.new(game.data, species, 30)
    player.nickname, player.hp = "PLAYER", 500
    player.stats = { hp = 500, attack = 1, defense = 500, speed = 999, special = 50, spatk = 1, spdef = 500 }
    player.moves = { { id = tackle, pp = 10 } }
    game.save.party = { player }
    local previous = game.data.trainers[id]
    game.data.trainers[id] = definition
    b = Battle.newTrainer(game, id, 1)
    game.data.trainers[id] = previous
    b:syncSides()
    assert(b.enemy.mon.level == 81 and #b.enemyParty == 6, "actual imported Red party is constructed")
    assert(b.trainer.items ~= definition.items and #b.trainer.items == 2, "fresh per-battle native stock")
    for i, value in ipairs(definition.attributes) do
      assert(b.trainer.attributes[i] == value, "native constructor preserves imported attribute byte")
    end
    b.enemy.mon.nickname, b.enemy.name = "FRESH_RED", "FRESH_RED"
    b.rng = function(lo)
      return lo or 0
    end
    b.queue, b.phase, b.afterQueue, b.menuIndex = {}, "menu", "menu", 1
    b.introSlide, b.fx = 0, {}
    game.stack.states = { game.overworld, b }
    e.state.mode, e.state.calls, e.state.contexts = "delegate", 0, {}
    return b
  end
  local function turn()
    damage, beforeHit = 0, nil
    U.tap(game, "a")
    assert(b.phase == "moveSelect", "native FIGHT opens moves")
    U.tap(game, "a")
    for _ = 1, 4000 do
      if b.phase == "menu" then
        return
      end
      U.tap(game, "a")
    end
    error("fresh imported Gen-2 turn did not settle")
  end
  for encounter = 1, 2 do
    fresh()
    local maxHp = b.enemy.mon.stats.hp
    local turns = encounter == 1 and 3 or 1
    for n = 1, turns do
      if n <= 2 then
        b.enemy.mon.hp = math.floor(maxHp / 4)
        b.enemy.shownHP = b.enemy.mon.hp
      end
      local before = b.enemy.mon.hp
      turn()
      local heals = n <= 2
      assert(beforeHit == (heals and maxHp or before), "native Full Restore precedes actual player move")
      assert(b.enemy.mon.hp == beforeHit - damage, "native imported healing and damage are retained")
      assert(#b.trainer.items == math.max(0, 2 - n), "native duplicate slots consume once per turn")
      assert(e.state.calls == n and e.state.contexts[n] == b, "one public query with exact native handle")
      assert(
        #definition.items == 2 and definition.items[1] == original.items[1],
        "shared imported stock survives"
      )
      print(
        "PORTABILITY_GEN2_IMPORT_CASE " .. encounter .. " " .. n .. " " .. maxHp .. " " .. #b.trainer.items
      )
    end
  end
  for _, stop in ipairs(stops) do
    stop()
  end
  print("PORTABILITY_GEN2_IMPORT_PASS gold classes=66 encounters=2 turns=4")
  love.event.quit(0)
end
