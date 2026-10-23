-- Imported-data smoke in the separate disposable portability identity.
return function(game)
  local U = require("tests.drivers.util")
  local Version = require("src.core.GameVersion")
  assert(love.filesystem.getIdentity() ~= "Gen2Recomp", "use isolated identity")
  assert(os.getenv("POKEPORT_SKIP_LEGACY_MIGRATION") == "1", "disable legacy migration")
  assert(os.getenv("POKEPORT_ISOLATED_TESTING") == "1", "use isolated wrapper")
  assert(Version.get() == os.getenv("POKEPORT_VERSION") and Version.isGen3(), "wrong cartridge")
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
  local e = assert(game.mods.exports.portable_gba_item_use, "install portable GBA example")
  local world = game.overworld
  local species
  for id, def in pairs(game.data.pokemon) do
    if def.name == "RATTATA" or def.name == "Rattata" then
      species = id
      break
    end
  end
  assert(species, "native Rattata metadata missing")
  local mon = require("src.pokemon.Pokemon").new(game.data, species, 12)
  game.save.party = { mon }
  game.save.inventory, game.save.bagOrder = {}, {}
  local potion
  for id, def in pairs(game.data.items) do
    if def.key == "POTION" or (def.translationSourceName or def.name):upper() == "POTION" then
      potion = id
      break
    end
  end
  assert(potion, "native Potion missing")
  assert(require("src.inventory.Bag").add(game.save, potion, 6, game.data), "native bag add failed")
  local TextBox = require("src.render.TextBox")
  local PartyMenu = require("src.ui.Gen3PartyMenu")
  local function openPicker()
    game.stack.states = { world }
    local bag = require("src.ui.Gen3BagMenu").new(game, {})
    game.stack:push(bag)
    local found
    for i, row in ipairs(bag.rows) do
      if row.id == potion then
        bag.index, found = i, true
        break
      end
    end
    assert(found, "native Potion row missing")
    for _ = 1, 1200 do
      if getmetatable(game.stack:top()) == PartyMenu then
        break
      end
      U.tap(game, "a")
      U.wait(2)
    end
    assert(getmetatable(game.stack:top()) == PartyMenu, "native GBA picker missing")
    return bag
  end
  local function finish(bag, expectedText)
    local seen = false
    for _ = 1, 1200 do
      local top = game.stack:top()
      if top == bag then
        break
      end
      if getmetatable(top) == TextBox then
        if expectedText then
          local actual = require("src.link.Json").encode(top.pages)
          local expected = require("src.link.Json").encode(
            TextBox.paginate(expectedText, top.maxCols, top.letterSpacing, top.maxPixels)
          )
          assert(actual == expected, "native final result text mismatch")
        else
          error("nil result text unexpectedly displayed")
        end
        seen = true
        U.tap(game, "a")
      end
      U.wait(2)
    end
    assert(game.stack:top() == bag, "native result UI did not return to bag")
    assert(seen == (expectedText ~= nil), "native text presence mismatch")
  end
  local count = 6
  for _, mode in ipairs({ "block", "message", "silent" }) do
    mon.hp = mon.stats.hp - 10
    local hp = mon.hp
    e.state.mode = mode
    local bag = openPicker()
    local calls = e.state.calls
    U.tap(game, "a")
    U.wait(3)
    assert(e.state.calls == calls + 1 and e.state.argCount == 5, "native item dispatch count/shape")
    assert(e.state.game == game and e.state.battle == nil and e.state.slot == 1, "native GBA handles/slot")
    assert(e.state.item == "POTION", "API-3 item ID not canonical")
    if mode == "block" then
      assert(mon.hp == hp and game.save.inventory[potion] == count, "blocked native effect changed state")
    else
      count = count - 1
      assert(mon.hp == mon.stats.hp and game.save.inventory[potion] == count, "native medicine effect/count")
      assert(e.state.returnCount == 3 and e.state.kind == "heal", "native field triple")
    end
    finish(bag, mode == "block" and "PORTABLE BLOCK" or mode == "message" and "PORTABLE TEXT" or nil)
    assert(e.state.calls == calls + 1 and game.save.inventory[potion] == count, "native UI repeated effect")
  end
  e.stop()
  local calls = e.state.calls
  mon.hp = mon.stats.hp - 10
  openPicker()
  U.tap(game, "a")
  U.wait(3)
  assert(e.state.calls == calls, "unsubscribe retained callback")
  assert(mon.hp == mon.stats.hp and game.save.inventory[potion] == count - 1, "unsubscribe lost native use")
  print("PORTABILITY_GBA_ITEM_USE_PASS " .. Version.get())
  love.event.quit(0)
end
