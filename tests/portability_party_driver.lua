-- Native LÖVE smoke test. Requires an imported cartridge in an isolated identity.
-- POKEPORT_DRIVER=tests/portability_party_driver.lua POKEPORT_VERSION=red
return function(game)
  local U = require("tests.drivers.util")
  local Version = require("src.core.GameVersion")
  assert(love.filesystem.getIdentity() ~= "Gen2Recomp", "use the isolated test launcher")
  assert(os.getenv("POKEPORT_SKIP_LEGACY_MIGRATION") == "1", "disable legacy migration")
  assert(Version.get() == (os.getenv("POKEPORT_VERSION") or "red"), "wrong cartridge")
  assert(game.data and game.data.maps and next(game.data.maps), "native map data missing")
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
  assert(title, "native title did not become ready after the intro")
  U.wait(30)
  title.onNewGame()
  U.wait(60)
  assert(game.save and game.save.player and game.overworld, "native New Game did not create the world")
  assert(game.stack.states[1] == game.overworld, "world missing below introduction")
  local Pokemon = require("src.pokemon.Pokemon")
  game.stack.states = { game.overworld }
  local function species(name)
    for id, def in pairs(game.data.pokemon) do
      if type(def) == "table" and def.name == name then
        return id
      end
    end
    error("test species missing: " .. name)
  end
  game.save.party = {}
  for i = 1, 6 do
    local mon = Pokemon.new(game.data, species("BULBASAUR"), 20)
    mon.nickname = "PROBE" .. i
    game.save.party[i] = mon
  end
  local battle = require("src.battle.BattleState").newWild(game, species("PIDGEY"), 5)
  battle:syncSides()
  local calls, original = 0, nil
  local off = game.mods.hooks:wrap("ui.party.grid_navigation", function(next, menu)
    calls, original = calls + 1, menu
    return true
  end, 0, "native_party_grid_probe")
  local canceled = 0
  local menu = require("src.ui.Screens").push(game, "PartyMenu", {
    battle = battle,
    onSwitch = function()
      error("unexpected switch")
    end,
    onCancel = function()
      canceled = canceled + 1
    end,
  })
  U.wait(3)
  assert(menu.index == 1 and original == menu, "native party hook/handle missing")
  U.tap(game, "right")
  assert(menu.index == (Version.isGen3() and 3 or 2), "native party peer mismatch")
  if os.getenv("POKEPORT_PORTABILITY_SHOT") then
    assert(U.shot(game, os.getenv("POKEPORT_PORTABILITY_SHOT")), "native party capture missing")
  end
  U.tap(game, "a")
  assert(menu.submenu, "native confirm did not open battle submenu")
  U.tap(game, "b")
  assert(not menu.submenu and game.stack:top() == menu, "native submenu cancel failed")
  U.tap(game, "b")
  assert(game.stack:top() ~= menu and canceled == 1, "native party cancel failed")
  assert(calls > 0, "predicate not dispatched")
  off()
  print("PORTABILITY_PARTY_PASS " .. Version.get() .. " " .. calls)
  love.event.quit(0)
end
