-- Native LÖVE smoke test. Requires an imported cartridge in an isolated identity.
-- POKEPORT_DRIVER=tests/portability_follower_driver.lua POKEPORT_VERSION=red
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
  local e = assert(game.mods.exports.portable_follower, "install the portable_follower example")
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
  local Follower = require("src.world.PikachuFollower")
  e.state.mode = "deny"
  world:setMap(target, 2, 2, "right", { via = "reload", keepMusic = true })
  assert(Follower.current(world) == nil, "native map entry ignored denial")
  local map, x, y = world.map
  local function occupied(cx, cy)
    for _, npc in ipairs(world.npcs) do
      if npc.cellX == cx and npc.cellY == cy then
        return true
      end
    end
  end
  for cy = 2, map.heightCells - 3 do
    for cx = 2, map.widthCells - 4 do
      if
        map:isWalkableCell(cx, cy)
        and map:isWalkableCell(cx + 1, cy)
        and map:isWalkableCell(cx + 2, cy)
        and not map:isGrassCell(cx, cy)
        and not map:isGrassCell(cx + 1, cy)
        and not map:isGrassCell(cx + 2, cy)
        and not map:warpAtCell(cx, cy)
        and not map:warpAtCell(cx + 1, cy)
        and not map:warpAtCell(cx + 2, cy)
        and not occupied(cx, cy)
        and not occupied(cx + 1, cy)
        and not occupied(cx + 2, cy)
      then
        x, y = cx, cy
        break
      end
    end
    if x then
      break
    end
  end
  assert(x, "no bounded native movement fixture found")
  e.state.mode = "allow"
  world:setMap(target, x, y, "right", { via = "reload", keepMusic = true })
  local npc = assert(Follower.current(world), "native map entry did not spawn companion")
  assert(npc.passable and npc.sprite, "native companion lacks passable renderer")
  assert(e.state.game == game and e.state.world == world, "public hook lost original native handles")
  local before = e.state.calls
  U.wait(3)
  assert(e.state.calls > before, "normal native world loop omitted predicate")
  local px, py = npc.px, npc.py
  U.hold(game, "right", 16)
  U.wait(32)
  -- Map-load companions begin under the player; their first step opens the
  -- trail, and the second step must visibly move the native NPC.
  U.hold(game, "right", 16)
  U.wait(32)
  npc = assert(Follower.current(world), "companion disappeared during movement")
  assert(world.player.cellX >= x + 2, "native right input did not move player")
  assert(npc.px ~= px or npc.py ~= py, "native NPC loop did not advance companion")
  e.state.mode = "deny"
  U.wait(3)
  assert(Follower.current(world) == nil, "native update did not remove companion")
  for _, entity in ipairs(world.entities) do
    assert(entity ~= npc, "removed companion remains drawable")
  end
  e.state.mode = "allow"
  U.wait(3)
  assert(Follower.current(world), "native update did not respawn companion")
  e.stop()
  U.wait(3)
  assert(Follower.current(world) == nil, "unsubscribe did not restore no-follower native default")
  print("PORTABILITY_FOLLOWER_PASS " .. Version.get() .. " " .. target)
  love.event.quit(0)
end
