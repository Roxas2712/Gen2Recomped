-- Native LÖVE smoke test. Requires an imported cartridge in an isolated identity.
-- POKEPORT_DRIVER=tests/portability_item_use_driver.lua POKEPORT_VERSION=red
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
  assert(os.getenv("POKEPORT_ISOLATED_TESTING") == "1", "use isolated test wrapper")
  assert(Version.generation() == 1, "this driver checks the GB item contract")
  local e = assert(game.mods.exports.portable_item_use, "install portable_item_use example")
  local world = game.overworld
  local mon = require("src.pokemon.Pokemon").new(game.data, "RATTATA", 12)
  game.save.party = { mon }
  game.save.inventory, game.save.bagOrder = {}, {}
  require("src.inventory.Bag").add(game.save, "POTION", 3, game.data)
  local function openPicker()
    game.stack.states = { world }
    local bag = require("src.ui.BagMenu").new(game, {})
    game.stack:push(bag)
    for i, row in ipairs(bag.items) do
      if row.value == "POTION" then
        bag.index = i
        break
      end
    end
    U.tap(game, "a")
    U.wait(2)
    U.tap(game, "a")
    U.wait(2)
    local picker = game.stack:top()
    assert(type(picker.onSwitch) == "function", "native party picker missing")
    return bag, picker
  end
  mon.hp = mon.stats.hp - 10
  e.state.mode = "block"
  local bag, picker = openPicker()
  local before, hp = e.state.calls, mon.hp
  U.tap(game, "a")
  U.wait(3)
  assert(e.state.calls == before + 1, "native target confirmation missed hook")
  assert(e.state.game == game and e.state.target == mon, "native hook handles changed")
  assert(e.state.item == "POTION" and e.state.battle == nil, "native GB item arguments changed")
  assert(mon.hp == hp and game.save.inventory.POTION == 3, "blocked item changed native state")
  assert(game.stack:top() == picker, "blocked item added result UI")
  e.state.mode = "native"
  U.tap(game, "a")
  U.wait(3)
  assert(mon.hp == mon.stats.hp and game.save.inventory.POTION == 2, "delegated native Potion failed")
  -- Complete the real HP animation and text. Stop at the bag before another
  -- A press could start a second use; no screen callback is invoked by hand.
  local TextBox = require("src.render.TextBox")
  for _ = 1, 300 do
    local top = game.stack:top()
    if top == bag then
      break
    end
    if getmetatable(top) == TextBox then
      U.tap(game, "a")
    end
    U.wait(2)
  end
  assert(game.stack:top() == bag, "native medicine UI did not return to bag")
  assert(e.state.calls == before + 2 and game.save.inventory.POTION == 2, "native UI repeated consumption")
  e.stop()
  mon.hp = mon.stats.hp - 10
  before = e.state.calls
  openPicker()
  U.tap(game, "a")
  U.wait(3)
  assert(e.state.calls == before, "unsubscribe retained item wrapper")
  assert(mon.hp == mon.stats.hp and game.save.inventory.POTION == 1, "unsubscribe lost native item use")
  print("PORTABILITY_ITEM_USE_PASS " .. Version.get())
  love.event.quit(0)
end
