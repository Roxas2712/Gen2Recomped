package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local V = require("src.core.GameVersion")
local P = require("src.render.Pipelines")
local Json = require("src.link.Json")
love.graphics.setDepthMode = function() end
local file = assert(io.open("tests/native_foundation/consumer.lua", "rb"))
local consumer = file:read("*a")
file:close()
local function load(version, api)
  V.set(version)
  return T.sdk.loadMods({ "mods/native_foundation" }, {
    data = T.fixtures.fresh(),
    fs = T.sdk.memfs({
      ["mods/native_foundation/manifest.json"] = Json.encode({
        id = "native_foundation", name = "Foundation probe", version = "1.0.0",
        api = api or 2, entry = "main.lua", affects_link = false,
        games = { "gen1", "gen2", "gen3" }, gen2compat = true,
      }),
      ["mods/native_foundation/main.lua"] = consumer,
    }),
  })
end
local function plain(value)
  local kind = type(value)
  T.check(kind == "table" or kind == "number" or kind == "string" or kind == "boolean", "data only")
  if kind == "table" then
    T.eq(getmetatable(value), nil, "no native metatable")
    for _, v in pairs(value) do plain(v) end
  end
end
for _, case in ipairs({ { "emerald", 1 }, { "emerald", 2 }, { "firered", 1 }, { "firered", 2 } }) do
  local version, api = case[1], case[2]
  -- Assemble native-shaped resident state from the independent synthetic
  -- fixtures. Only the test driver uses engine internals; the consumer above
  -- reaches every family through the actual loader's public API.
  local f = require("tests.actor_render.fixture").new(".", version, 2)
  f.result.release()
  local e = require("tests.field_effect_render.fixture").new(".", version, 2)
  e.result.release()
  local surf = require("tests.surf_mount_render.fixture").new(".", version, 2)
  surf.result.release()
  local s = require("tests.render_contract.fixture").new("gen2", version, ".")
  s.map.id, s.neighbor.id = "A", "B"
  f.world.map, f.world.neighbors = s.map, s.world.neighbors
  f.world.ripples, f.world.sparkles = e.world.ripples, e.world.sparkles
  f.game.data.map_tilesets = s.game.data.map_tilesets
  f.game.data.sprites = e.game.data.sprites
  f.game.data.constants = e.game.data.constants
  f.game.data.constants.gen3Layout = s.game.data.constants.gen3Layout
  f.game.data.constants.gen3SurfBlob = surf.game.data.constants.gen3SurfBlob
  for _, map in ipairs({ s.map, s.neighbor }) do
    map.def.elevationCells = { 3, 15, 0, 4, 1, 6 }
    map.def.collisionCells = { 0, 1, 2, 3, 0, 1 }
    map.tileset.behaviourBytes = true
    map.tileset.collision = { [1] = 2, [2] = 0x15, [3] = 0x70,
      [s.split + 1] = 0x71, [s.split + 2] = 0x72, [s.split + 3] = 0x73 }
    map.grassTiles = { [2] = true }
  end
  f.player.cellX, f.player.cellY = 0, 0
  f.player.targetX, f.player.targetY, f.player.stepFrames = 1, 0, 16
  f.player.bobTimer = 7
  local run = load(version, api)
  T.eq(#run.errors, 0, version .. " public consumer loads")
  run.loader.game = f.game
  run.loader.fs.newFile = f.result.loader.fs.newFile
  local exports = assert(run.loader.exports.native_foundation)
  local r = exports.renderData
  for _, method in ipairs({ "supports", "supportsSurface", "supportsActors", "supportsFieldEffects", "supportsSurfMounts" }) do
    T.eq(r[method](r, 1), true, "all families on one handle: " .. method)
  end
  T.eq(r.getGame, nil, "resolver stays private")
  local beforeDraw = f.player.animDrawn
  local scene = assert(exports.observe("A"))
  T.eq(#scene.actors.actors, 4, "active and neighboring actors coexist with terrain")
  T.check(#scene.effects.effects > 2, "ripples, sparkles and actor grass coexist")
  T.eq(#scene.mounts.mounts, 0, "walking has no surf mount")
  T.same(scene.terrain.elevations, { 3, 15, 0, 4, 1, 6 }, "raw bridge and ground elevations")
  T.same(scene.terrain.collisions, { 0, 1, 2, 3, 0, 1 }, "raw collision codes")
  T.same(scene.terrain.behaviors, { 2, 0x71, 0x15, 0x70, 0x72, 0x73 }, "native combined tileset behaviors")
  T.eq(f.player.animDrawn, beforeDraw, "combined observation never records a draw")
  T.eq(s.map.def._blockArray, nil, "combined observation never decodes the layout cache")
  plain(scene)
  scene.terrain.elevations[1] = 99
  scene.terrain.placements[1].x = 999
  T.eq(assert(r:surface(1, "A")).elevations[1], 3, "surface detached from host")
  T.eq(assert(r:surface(1, "A")).placements[1].x, 0, "placements detached from host")
  s.map:setBlock(1, 0, 1, false)
  s.map.elevationPatch[2] = 0
  local changed = assert(r:surface(1, "A"))
  T.eq(changed.metatiles[2], 1, "live script metatile patch")
  T.eq(changed.behaviors[2], 0x15, "behavior follows patched metatile")
  T.eq(changed.collisions[2], 0, "zero collision patch overrides blocked base")
  T.eq(changed.elevations[2], 0, "zero elevation patch overrides under-bridge marker")
  local neighbor = assert(r:surface(1, "A", { mapId = "B", region = { x = 1, y = 0, width = 1, height = 2 } }))
  T.same(neighbor.elevations, { 15, 1 }, "resident neighbor crop, local row-major coordinates")
  T.same(neighbor.collisions, { 1, 0 }, "neighbor collision is not active-map collision")
  T.eq(neighbor.mapId, "B", "neighbor identity")
  f.player.surfing = true
  local riding = assert(exports.observe("A"))
  T.eq(#riding.mounts.mounts, 1, "surf and actor observations compose")
  T.eq(riding.mounts.mounts[1].ownerId, "player", "mount refers to public player identity")
  T.eq(f.player.bobTimer, 7, "combined snapshot never advances surf bob")
  T.eq(assert(r:actorSheet(1, "A", riding.actors.actors[1].sheetId)).format, "png", "actor source available on combined handle")
  T.eq(assert(r:fieldEffectSheet(1, "A", riding.effects.effects[1].sheetId)).format, "png", "effect source available on combined handle")
  T.eq(assert(r:surfMountSheet(1, "A", riding.mounts.mounts[1].sheetId)).format, "png", "surf source available on combined handle")
  -- Drive the real registry-installed world callback, with native fallback.
  P.install(run.data)
  P.setLevel("native_foundation", 1)
  local key = P.worldPipeline()
  T.check(key ~= nil, "pipeline selectable through public registry")
  T.eq(P.drawWorld(key, { state = f.world, cam = { x = 0, y = 0 }, vw = 240, vh = 160,
    pixelWidth = 480, pixelHeight = 320, unitWidth = 480, unitHeight = 320,
    width = 480, height = 320, level = 1 }), nil, "consumer deliberately returns native fallback")
  T.eq(exports.lastError, nil, "all data families accessible inside portable world callback")
  T.eq(exports.lastFrame.state, nil, "public world frame has no native state")
  T.eq(exports.lastScene.terrain.mapId, "A", "same active map in callback")
  s.map.id = "WARPED"
  local value, reason = exports.observe("A")
  T.eq(value, nil, "stale frame cannot read the new map")
  T.eq(reason, "active map changed", "explicit stale-frame reason")
  run.release()
end
for _, version in ipairs({ "red", "gold" }) do
  local run = load(version)
  T.eq(#run.errors, 0, "older generations still load public consumer")
  local r = run.loader.exports.native_foundation.renderData
  T.eq(r:supportsSurface(1), false, "Gen3-only surface negotiation")
  local value, reason = r:surface(1, "A")
  T.eq(value, nil, "unsupported host cannot fabricate elevations")
  T.eq(reason, "unsupported generation", "explicit generation gate")
  run.release()
end
T.finish("Native foundation public-loader integration")
