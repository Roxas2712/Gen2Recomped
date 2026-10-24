-- Imported-data native move/queue smoke in the isolated portability identity.
return function(game)
  local U, V = require("tests.drivers.util"), require("src.core.GameVersion")
  assert(love.filesystem.getIdentity() ~= "Gen2Recomp", "use isolated identity")
  assert(os.getenv("POKEPORT_SKIP_LEGACY_MIGRATION") == "1", "disable legacy migration")
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
  local e = assert(game.mods.exports.portable_charge_required, "install charge example")
  local species
  for id, def in pairs(game.data.pokemon) do
    if def.name == "MEW" then
      species = id
      break
    end
  end
  assert(species, "native Mew metadata missing")
  local function moveId(wanted)
    for id, def in pairs(game.data.moves) do
      if def.name:upper():gsub("[^%w]", "") == wanted then
        return id
      end
    end
    error("native move missing: " .. wanted)
  end
  game.save.options.textSpeed, game.save.options.animations = 1, false
  local world = game.overworld
  local function fresh(name)
    local mon = require("src.pokemon.Pokemon").new(game.data, species, 30)
    local move = { id = moveId(name), pp = 10 }
    mon.moves, mon.hp, mon.stats.hp = { move }, 400, 400
    game.save.party = { mon }
    local b = require("src.battle.BattleState").newWild(game, species, 30)
    b.enemy.mon.hp, b.enemy.mon.stats.hp = 400, 400
    b.rng = function(lo)
      return lo or 0
    end
    -- Bound move-resolution smoke: skip the separate sendout intro and let
    -- the ordinary battle state consume the generated queue with real input.
    game.stack.states = { world, b }
    b.phase, b.afterQueue = "messages", "menu"
    return b, move
  end
  local function drain(b)
    for _ = 1, 1800 do
      if b.phase == "menu" then
        return
      end
      U.tap(game, "a")
    end
    error("native charge result queue did not return to battle menu")
  end
  for _, name in ipairs({ "SOLARBEAM", "FLY" }) do
    for _, bypass in ipairs({ false, true }) do
      e.state.mode = bypass and "bypass" or "native"
      local b, move = fresh(name)
      local before = e.state.calls
      b:performMove(b.player, b.enemy, move)
      assert(
        e.state.calls == before + 1 and e.state.charge == true and e.state.isCalled == false,
        "native charge callback"
      )
      assert(e.state.battle == b, "native opaque battle handle")
      assert(move.pp == 9, "native first turn PP")
      assert((b.player.charging ~= nil) == not bypass, "native continuation verdict")
      assert((b.enemy.mon.hp < 400) == bypass, "native first turn damage")
      if bypass and V.isGen3() then
        local seen = false
        for _, row in ipairs(b.queue) do
          if row.anim == move.id then
            seen = true
            assert(row.animContext.moveTurn == 1, "native GBA release branch")
          end
        end
        assert(seen, "native bypass animation row missing")
      end
      drain(b)
      if not bypass then
        b.phase, b.afterQueue = "messages", "menu"
        b:performMove(b.player, b.enemy, move)
        assert(e.state.calls == before + 1, "native release repeated callback")
        assert(
          move.pp == 9 and b.player.charging == nil and b.player.invulnerable == nil,
          "native release state/PP"
        )
        assert(b.enemy.mon.hp < 400, "native release damage")
        drain(b)
      end
    end
  end
  e.stop()
  local calls = e.state.calls
  local b, move = fresh("FLY")
  b:performMove(b.player, b.enemy, move)
  assert(e.state.calls == calls and b.player.charging == move and move.pp == 9, "unsubscribe native default")
  print("PORTABILITY_CHARGE_REQUIRED_PASS " .. V.get())
  love.event.quit(0)
end
