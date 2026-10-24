local F = {}
function F.bytes(seed, count)
  local b = {}
  for i = 0, count * 32 - 1 do
    local tileSeed = seed + math.floor(i / 32) * 7
    b[#b + 1] = string.char((tileSeed + i * 3) % 16 + ((tileSeed + i * 5 + 1) % 16) * 16)
  end
  return table.concat(b)
end
function F.new(version, api)
  local T = require("tests.modkit")
  require("src.core.GameVersion").set(version)
  local state = require("tests.render_contract.fixture").new("gen2", version, ".")
  for index, name in ipairs({ "P", "S", "T" }) do
    local record = state.game.data.map_tilesets[name]
    record.metatileCount = #record.metatiles / 16
    record.animations = {}
    -- Distinct bank colors catch an incorrect primary/secondary palette split.
    for _, p in ipairs(record.palettes) do
      for _, rgb in ipairs(p) do
        rgb[1], rgb[2], rgb[3] = (rgb[1] + index * 11) % 256,
          (rgb[2] + index * 23) % 256, (rgb[3] + index * 37) % 256
      end
    end
  end
  local records = state.game.data.map_tilesets
  records.P.animations = { { tile = 0, count = 1, step = 8,
    frames = { F.bytes(1, 1), F.bytes(3, 1), F.bytes(5, 1), F.bytes(7, 1) } } }
  records.S.animations = { { tile = 0, count = 2, step = 12,
    frames = { F.bytes(2, 2), F.bytes(4, 2), F.bytes(6, 2) } } }
  records.T.animations = { { tile = 1, count = 1, step = 4,
    frames = { F.bytes(9, 1), F.bytes(11, 1) } } }
  local file = assert(io.open("tests/terrain_animation/consumer.lua", "rb"))
  local entry = file:read("*a")
  file:close()
  local Json = require("src.link.Json")
  local run = T.sdk.loadMods({ "mods/terrain_animation" }, { data = T.fixtures.fresh(), fs = T.sdk.memfs({
    ["mods/terrain_animation/manifest.json"] = Json.encode({ id = "terrain_animation", name = "Terrain animation probe",
      version = "1.0.0", api = api, entry = "main.lua", games = { "gen1", "gen2", "gen3" }, gen2compat = true }),
    ["mods/terrain_animation/main.lua"] = entry,
  }) })
  assert(#run.errors == 0 and run.loader.exports.terrain_animation, "public terrain consumer loads")
  run.loader.game = state.game
  return { state = state, run = run, records = records, exports = run.loader.exports.terrain_animation }
end
return F
