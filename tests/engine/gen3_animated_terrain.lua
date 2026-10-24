package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local F = require("tests.terrain_animation.fixture")
local Tiles = require("src.render.Gen3Tiles")
local Renderer = require("src.render.TileRenderer")
local Json = require("src.link.Json")
local function nativeLayer(decoder, mid, layer)
  local pixels = {}
  for i = 1, 256 do pixels[i] = string.char(0, 0, 0, 0) end
  decoder:drawLayer(mid, layer, 0, 0, function(x, y, r, g, b)
    pixels[y * 16 + x + 1] = string.char(r, g, b, 255)
  end)
  return table.concat(pixels)
end
for _, case in ipairs({ { "emerald", 1 }, { "emerald", 2 }, { "firered", 1 }, { "firered", 2 } }) do
  local f = F.new(case[1], case[2])
  local s, e = f.state, f.exports
  T.eq(e.supports(1), true, "Gen3 animation contract on API " .. case[2])
  T.eq(e.supports("1"), false, "numeric version required")
  local base = assert(e.base(s.mapId))
  T.eq(base.graphicsState, "base", "original base contract remains unchanged")
  local native = Tiles.new({ primary = f.records.P, secondary = f.records.S }, base.layout)
  local total = native:animFrameCount()
  T.eq(total, 12, "four- and three-frame native cycles compose")
  local pseudoRenderer = { gen3 = { animSlots = {}, animFrames = total, animStep = native:animStep() } }
  local before = Json.encode(f.records)
  for tick = 0, 97 do
    local live = assert(e.read(s.mapId))
    local frame = Renderer.gen3AnimFrame(pseudoRenderer)
    T.eq(live.animation.frame, frame, "public pose uses native renderer frame")
    T.eq(live.animation.ticks, Renderer.animFrame(), "public clock is the native clock")
    T.eq(live.animation.step, 8, "native shortest cadence retained")
    if tick % 7 == 0 or tick == 97 then
      native:setAnimFrame(frame)
      for _, mid in ipairs({ 0, 1, 2, s.split, s.split + 1, s.split + 2 }) do
        for layer = 1, 2 do
          T.eq(e.layer(live, mid, layer), nativeLayer(native, mid, layer),
            "public pixels equal native compositing across banks, flips and palettes")
        end
      end
    end
    local clock = Renderer.animFrame()
    T.eq(assert(e.read(s.mapId)).contentKey, live.contentKey, "repeated reads have stable content")
    T.eq(Renderer.animFrame(), clock, "observation cannot advance the clock")
    Renderer.tick(1/60)
  end
  T.eq(Json.encode(f.records), before, "neither source frames nor palettes are mutated")
  T.eq(s.map.def._blockArray, nil, "no engine layout decode cache")
  T.eq(f.records.P._anims, nil, "no animation cache on source records")
  local live = assert(e.read(s.mapId))
  T.eq(live.graphicsState, "animated-source", "live source state explicitly named")
  T.eq(base.primary.tiles4bpp, f.records.P.tiles, "original source bytes stay original")
  T.check(live.primary.tiles4bpp ~= base.primary.tiles4bpp, "frame zero/current overrides shipped bytes")
  local key = live.contentKey
  local pixelsBefore = e.layer(live, 0, 1)
  f.records.P.palettes[2][2] = { 255, 7, 63 }
  local recolored = assert(e.read(s.mapId))
  T.check(recolored.contentKey ~= key, "palette change invalidates even with unchanged source identity")
  T.eq(recolored.id, live.id, "palette edits need no invented tileset identity")
  T.eq(recolored.primary.paletteRGB8:sub(52, 54), string.char(255, 7, 63), "packed RGB source palette")
  native:setAnimFrame(recolored.animation.frame)
  T.eq(e.layer(recolored, 0, 1), nativeLayer(native, 0, 1), "updated palette pixels equal native source compositing")
  T.check(e.layer(recolored, 0, 1) ~= pixelsBefore, "source palette update changes the decoded picture")
  recolored.primary.palettes[2][2][1] = 0
  T.eq(f.records.P.palettes[2][2][1], 255, "returned palette is detached")
  local neighbor = assert(e.read(s.mapId, s.neighborId))
  T.eq(neighbor.animation.step, 4, "resident neighbor has its own cadence on the same clock")
  T.eq(neighbor.animation.frames, 4, "neighbor has its own combined cycle")
  T.check(neighbor.contentKey ~= live.contentKey, "same renderer alias does not alias source pairs")
  local oldGame, draw, random, read = package.loaded["src.core.Game"], love.graphics.newImage, math.random, f.run.loader.fs.read
  love.graphics.newImage = function() error("read must not build graphics") end
  math.random = function() error("read must not consume RNG") end
  f.run.loader.fs.read = function() error("read must not read files") end
  assert(e.read(s.mapId))
  love.graphics.newImage, math.random, f.run.loader.fs.read = draw, random, read
  T.eq(package.loaded["src.core.Game"], oldGame, "reader never bootstraps Game")
  local value, reason = e.read("stale")
  T.eq(value, nil, "stale active map rejected")
  T.eq(reason, "active map changed", "stale map reason")
  T.eq(e.read(s.mapId, "ABSENT"), nil, "unloaded map rejected")
  while Renderer.animFrame() % 8 ~= 0 do Renderer.tick(1/60) end
  local first = assert(e.read(s.mapId))
  Renderer.tick(1/60)
  local sameFrame = assert(e.read(s.mapId))
  T.eq(sameFrame.animation.ticks, first.animation.ticks + 1, "native time advances independently of content")
  T.eq(sameFrame.contentKey, first.contentKey, "a mid-frame tick does not invalidate unchanged content")
  for _ = 1, 7 do Renderer.tick(1/60) end
  T.check(assert(e.read(s.mapId)).contentKey ~= first.contentKey, "next animation picture invalidates content")
  for _ = 1, 88 do Renderer.tick(1/60) end
  T.eq(assert(e.read(s.mapId)).contentKey, first.contentKey, "a complete native cycle reuses the same content key")
  local current = assert(e.read(s.mapId))
  f.records.P.animations[1].frames[current.animation.frame % 4 + 1] = F.bytes(14, 1)
  local replaced = assert(e.read(s.mapId))
  T.check(replaced.contentKey ~= current.contentKey, "a replaced source animation frame invalidates content")
  local oldEntries = f.records.P.metatiles
  f.records.P.metatiles = string.char((oldEntries:byte(1) + 1) % 256) .. oldEntries:sub(2)
  local entriesChanged = assert(e.read(s.mapId))
  T.check(entriesChanged.contentKey ~= replaced.contentKey, "metatile composition edits invalidate content")
  local oldAttributes = f.records.P.attributes
  f.records.P.attributes = oldAttributes:sub(1, 1) .. string.char(16) .. oldAttributes:sub(3)
  local layersChanged = assert(e.read(s.mapId))
  T.eq(layersChanged.primary.layerTypes:byte(1), 1, "layer change reaches source graphics")
  T.check(layersChanged.contentKey ~= entriesChanged.contentKey, "layer edits invalidate content")
  f.run.release()
end
T.finish("Animated terrain public pixels and native clock")
