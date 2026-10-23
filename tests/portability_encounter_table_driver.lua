-- Imported-data title-screen preview test in the isolated portability identity.
return function(game)
  local U, V = require("tests.drivers.util"), require("src.core.GameVersion")
  assert(love.filesystem.getIdentity() ~= "Gen2Recomp", "use isolated identity")
  assert(os.getenv("POKEPORT_SKIP_LEGACY_MIGRATION") == "1", "disable legacy migration")
  assert(os.getenv("POKEPORT_ISOLATED_TESTING") == "1", "use isolated launcher")
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
  assert(title and not game.overworld, "preview must run at native title without overworld")
  local e = assert(game.mods.exports.portable_encounter_table, "install portable preview example")
  local mapId
  local keys = {}
  for id in pairs(game.data.maps) do
    if type(id) == "string" then
      keys[#keys + 1] = id
    end
  end
  table.sort(keys)
  for _, id in ipairs(keys) do
    local native = game.data.encounters[id]
    if native and native.grass and (tonumber(native.grass.rate) or 0) > 0 then
      mapId = id
      break
    end
  end
  assert(mapId, "native imported encounter map missing")
  local Json = require("src.link.Json")
  local tablesBefore, saveBefore = Json.encode(game.data.encounters), Json.encode(game.save or {})
  local options = V.isGen2() and { daytime = "DAY" } or {}
  local function query()
    local oldMath, oldLove = math.random, love.math.random
    local function reject()
      error("native preview consumed RNG")
    end
    math.random, love.math.random = reject, reject
    local ok, result, why = pcall(e.preview, mapId, "grass", options)
    math.random, love.math.random = oldMath, oldLove
    assert(ok, result)
    return assert(result, why)
  end
  local baseline = query()
  assert(next(baseline.dist) and baseline.chance > 0, "native baseline missing distribution")
  assert(e.state.preview and e.state.mapId == mapId and e.state.terrain == "grass", "native preview context")
  local calls = e.state.calls
  e.state.mode = "replace"
  local custom = query()
  assert(custom.chance == baseline.chance and custom.dist.MEW == 7, "native custom preview result")
  assert(e.state.calls == calls + 1, "native query must dispatch once")
  e.state.mode = "empty"
  assert(next(query().dist) == nil, "empty custom preview rejected")
  e.state.mode = "nil"
  assert(Json.encode(query()) == Json.encode(baseline), "nil fallback lost native distribution")
  e.stop()
  calls = e.state.calls
  assert(Json.encode(query()) == Json.encode(baseline), "unsubscribe lost native preview")
  assert(e.state.calls == calls, "unsubscribe retained callback")
  assert(Json.encode(game.data.encounters) == tablesBefore, "preview mutated imported tables")
  assert(Json.encode(game.save or {}) == saveBefore, "pure consumer mutated native save")
  assert(not game.overworld, "query created an overworld")
  print("PORTABILITY_ENCOUNTER_TABLE_PASS " .. V.get() .. " " .. mapId)
  love.event.quit(0)
end
