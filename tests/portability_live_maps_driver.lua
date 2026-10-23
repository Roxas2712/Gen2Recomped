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
  assert(os.getenv("POKEPORT_ISOLATED_TESTING") == "1", "use the isolated test wrapper")
  local e = assert(game.mods.exports.portable_live_maps, "install the public portable_live_maps example")
  local world = game.overworld
  local wanted = Version.get() == "gold" and "NEWBARKTOWN"
    or Version.get() == "emerald" and "LITTLEROOTTOWN"
    or "PALLETTOWN"
  local function normalized(value)
    return tostring(value or ""):upper():gsub("[^%w]", "")
  end
  local target
  for id, def in pairs(game.data.maps) do
    local connects = false
    for _, dir in ipairs({ "north", "south", "east", "west" }) do
      if def.connections and def.connections[dir] then
        connects = true
      end
    end
    if
      connects
      and (
        normalized(id):find(wanted, 1, true)
        or normalized(def.label) == wanted
        or normalized(def.name) == wanted
      )
    then
      target = id
      break
    end
  end
  -- Imported GBA headers can carry bank/number IDs without town labels.
  -- These select only this bounded cartridge fixture; the mod consumer never
  -- assumes a particular map ID or generation-specific representation.
  local nativeTown = { firered = "MAP_G03_N00", emerald = "MAP_G00_N09" }
  if not target and game.data.maps[nativeTown[Version.get()]] then
    target = nativeTown[Version.get()]
  end
  assert(target, "native connected town not found")
  game.stack.states = { world }
  local before = #e.events
  world:setMap(target, 2, 2, "down", { via = "reload", keepMusic = true })
  assert(world.map.id == target, "native connected map did not load")
  assert(#e.events >= before + 2, "native map load omitted lifecycle events")
  local pre, post = e.events[#e.events - 1], e.events[#e.events]
  assert(pre.phase == "preparing" and post.phase == "updated", "native lifecycle order mismatch")
  assert(pre.mapId == target and post.mapId == target, "native lifecycle map mismatch")
  assert(world.preparingLiveMaps == nil, "native preparation flag was stranded")
  local maps = assert(e.maps())
  assert(#maps > 1 and #maps == #post.maps, "native connected residency missing")
  for i, map in ipairs(maps) do
    assert(
      map.mapId == post.maps[i].mapId and map.ox == post.maps[i].ox and map.oy == post.maps[i].oy,
      "native API-3 placement disagrees with event"
    )
    assert(
      type(map.ox) == "number" and type(map.oy) == "number" and map.x == nil,
      "native pixel fields missing"
    )
  end
  local n = #e.events
  world:rebuildNeighbors()
  assert(#e.events == n + 2, "native repeat rebuild omitted lifecycle pair")
  print("PORTABILITY_LIVE_MAPS_PASS " .. Version.get() .. " " .. #maps)
  love.event.quit(0)
end
