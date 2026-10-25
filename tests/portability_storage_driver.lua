-- Native LÖVE smoke test. Requires an imported cartridge in an isolated identity.
-- POKEPORT_DRIVER=tests/portability_storage_driver.lua POKEPORT_STORAGE_PHASE=prepare|verify
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
  assert(os.getenv("POKEPORT_ISOLATED_TESTING") == "1", "use the isolated test wrapper")
  local e = assert(game.mods.exports.portable_storage, "unchanged API-3 storage consumer not loaded")
  local S = require("src.core.SaveData")
  local version = Version.get()
  local phase = assert(os.getenv("POKEPORT_STORAGE_PHASE"), "set prepare or verify phase")
  if phase == "prepare" then
    title.onNewGame()
    U.wait(60)
    assert(game.overworld and game.save.player, "native new game missing")
    local context = assert(e.context(game))
    assert(context.gameVersion == version, "native game version mismatch")
    assert(e.write(game, "smoke/record", { version = version, identity = context.playthroughId, format = 1 }))
    assert(e.writeBytes(game, "smoke/bytes", "SMOKE\0\255\128"))
    game:writeOptions()
    assert(game:writeSave(), "native normal SAVE failed")
    assert(game.save.meta.playthroughId == context.playthroughId, "normal SAVE lost storage identity")
  elseif phase == "verify" then
    local ghost = assert(e.context(game))
    local selected = assert(e.selected(game))
    local context = selected:context()
    local record = assert(selected:read("smoke/record"))
    assert(context.gameVersion == version and record.version == version, "native version scope mismatch")
    assert(
      record.identity == context.playthroughId and ghost.playthroughId ~= context.playthroughId,
      "boot skeleton displaced the durable title scope"
    )
    assert(type(context.normalSavedAt) == "number", "normal save chronology missing")
    assert(selected:readBytes("smoke/bytes") == "SMOKE\0\255\128", "opaque bytes did not survive restart")
    title.onContinue()
    U.wait(60)
    assert(game.overworld and game.save.player, "native Continue did not restore world")
    assert(e.context(game).playthroughId == context.playthroughId, "Continue lost identity")
    assert(e.read(game, "smoke/record").identity == context.playthroughId, "Continue lost mod record")
    assert(e.delete(game, "smoke/record"))
    assert(e.delete(game, "smoke/bytes"))
  else
    error("unknown storage phase")
  end
  print("PORTABILITY_STORAGE_PASS " .. version .. " " .. phase)
  love.event.quit(0)
end
