package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local V = require("src.core.GameVersion")
local Fixture = require("tests.render_contract.fixture")
local P = require("src.render.Pipelines")
local RenderData = require("src.mods.RenderData")
-- With no mods, none of the new per-mod handles is even constructed.
local calls, originalNew = 0, RenderData.new
RenderData.new = function(...)
  calls = calls + 1
  return originalNew(...)
end
for _, version in ipairs({ "emerald", "firered", "red", "gold" }) do
  V.set(version)
  local data = T.fixtures.fresh()
  local pokemon, maps = data.pokemon, data.maps
  local run = T.sdk.loadNone({ data = data })
  T.eq(#run.errors, 0, "no-mod boot succeeds")
  T.eq(calls, 0, "no-mod boot constructs no render observation handle")
  T.eq(data.pokemon, pokemon, "no-mod species namespace unchanged")
  T.eq(data.maps, maps, "no-mod map namespace unchanged")
  T.eq(data.renderData, nil, "no observational data injected into content")
  P.install(data)
  T.eq(P.worldPipeline(), nil, "no-mod native world fallback")
  T.eq(P.wantsPresent(), false, "no-mod render requires no presentation canvas")
  run.release()
end
RenderData.new = originalNew
for _, version in ipairs({ "emerald", "firered" }) do
  V.set(version)
  local run = T.sdk.loadMods({ "mods/surface_probe" }, {
    data = T.fixtures.fresh(),
    fs = T.sdk.memfs({
      ["mods/surface_probe/manifest.json"] = '{"id":"surface_probe","name":"Surface probe",'
        .. '"version":"1.0.0","api":2,"entry":"main.lua","games":["gen3"]}',
      ["mods/surface_probe/main.lua"] = 'local mod = ...; mod.exports.data = assert(mod.renderData)',
    }),
  })
  T.eq(#run.errors, 0, "public loader exposes surface observations")
  local r = run.loader.exports.surface_probe.data
  local function fresh()
    local s = Fixture.new("gen2", version, ".")
    for _, map in ipairs({ s.map, s.neighbor }) do
      map.def.elevationCells = { 3, 15, 0, 4, 1, 6 }
      map.def.collisionCells = { 0, 1, 2, 3, 0, 1 }
      map.tileset.behaviourBytes = true
      map.tileset.collision = {}
      for _, mid in ipairs({ 0, 1, 2, s.split, s.split + 1, s.split + 2 }) do
        map.tileset.collision[mid + 1] = mid % 256
      end
    end
    run.loader.game = s.game
    return s
  end
  local function rejected(change, message, query)
    local s = fresh()
    change(s)
    local ok, value, reason = pcall(r.surface, r, 1, s.mapId, query)
    T.eq(ok, true, "invalid source/query returns a failure without throwing")
    T.eq(value, nil, "invalid source/query cannot become plausible terrain")
    T.eq(reason, message, "surface decline reason")
  end
  for _, field in ipairs({ "elevationCells", "collisionCells" }) do
    rejected(function(s) s.map.def[field] = "bad" end, "surface data unavailable")
  end
  for _, field in ipairs({ "elevationPatch", "collisionPatch" }) do
    rejected(function(s) s.map[field] = false end, "surface data unavailable")
  end
  rejected(function(s) s.map.def.elevationCells = nil end, "surface data unavailable")
  rejected(function(s) s.map.tileset.behaviourBytes = false end, "surface data unavailable")
  rejected(function(s) s.map.tileset.collision = nil end, "surface data unavailable")
  for _, bad in ipairs({ -1, 16, 1.5, false, 0/0, math.huge }) do
    rejected(function(s) s.map.elevationPatch[1] = bad end, "surface cell unavailable")
    rejected(function(s) s.map.def.elevationCells[1] = bad end, "surface cell unavailable")
  end
  for _, bad in ipairs({ -1, 4, 0.5, false, 0/0, math.huge }) do
    rejected(function(s) s.map.collisionPatch[1] = bad end, "surface cell unavailable")
    rejected(function(s) s.map.def.collisionCells[1] = bad end, "surface cell unavailable")
  end
  for _, bad in ipairs({ -1, 256, 0.5, false, 0/0, math.huge }) do
    rejected(function(s) s.map.tileset.collision[1] = bad end, "surface cell unavailable")
  end
  rejected(function(s) s.map.tileset.collision[1] = nil end, "surface cell unavailable")
  rejected(function() end, "invalid render query", { path = "anything" })
  rejected(function() end, "invalid region (maximum 4096 cells)", { region = { x = -1, y = 0, width = 1, height = 1 } })
  rejected(function() end, "map not resident", { mapId = "ABSENT" })
  rejected(function(s) s.world.isOverworld = false end, "no overworld")
  rejected(function(s) s.large() end, "invalid region (maximum 4096 cells)")
  local s = fresh()
  local value, reason = r:surface(2, s.mapId)
  T.eq(value, nil, "unknown surface version declines")
  T.eq(reason, "unsupported render data version", "unknown version reason")
  T.eq(r:supportsSurface("1"), false, "numeric version required")
  s.map.def.collisionCells = nil
  s.map.collisionPatch[1] = 3
  T.same(assert(r:surface(1, s.mapId)).collisions, { 3, 0, 0, 0, 0, 0 }, "native missing-collision fallback retains live patches")
  s.map.def.elevationCells = { [1] = 15 }
  T.same(assert(r:surface(1, s.mapId)).elevations, { 15, 0, 0, 0, 0, 0 }, "native sparse elevation fallback")
  s = fresh()
  local random, draw, read = math.random, love.graphics.draw, run.loader.fs.read
  math.random = function() error("observation consumed RNG") end
  love.graphics.draw = function() error("observation drew") end
  run.loader.fs.read = function() error("observation read filesystem") end
  local loadedGame = package.loaded["src.core.Game"]
  local packed, patches, neighbors = s.map.def.blocks, s.map.blockPatch, s.world.neighbors
  local observed = assert(r:surface(1, s.mapId))
  math.random, love.graphics.draw, run.loader.fs.read = random, draw, read
  T.eq(#observed.elevations, 6, "observation succeeds without RNG, drawing or filesystem")
  T.eq(package.loaded["src.core.Game"], loadedGame, "no Game bootstrap")
  T.eq(s.map.def.blocks, packed, "packed bytes unchanged")
  T.eq(s.map.def._blockArray, nil, "no layout decode cache")
  T.eq(s.map.blockPatch, patches, "live patch identity unchanged")
  T.eq(next(patches), nil, "live patches untouched")
  T.eq(s.world.neighbors, neighbors, "resident placements untouched")
  run.release()
end
T.finish("Gen3 public surface data and no-mod parity")
