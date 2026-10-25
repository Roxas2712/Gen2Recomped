-- Native LÖVE smoke test. Requires an imported cartridge in an isolated identity.
-- POKEPORT_DRIVER=tests/portability_boot_driver.lua POKEPORT_VERSION=red
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
    if top and type(top.onNewGame) == "function" then title = top break end
    U.tap(game, "start")
    U.wait(5)
  end
  assert(title, "native title did not become ready after the intro")
  U.wait(30)
  title.onNewGame()
  U.wait(60)
  assert(game.save and game.save.player and game.overworld, "native New Game did not create the world")
  assert(game.stack.states[1] == game.overworld, "world missing below introduction")
  if os.getenv("POKEPORT_PORTABILITY_SHOT") then
    assert(U.shot(game, os.getenv("POKEPORT_PORTABILITY_SHOT")), "native frame capture missing")
  end
  print("PORTABILITY_BOOT_PASS " .. Version.get() .. " " .. game.save.player.map)
  love.event.quit(0)
end
