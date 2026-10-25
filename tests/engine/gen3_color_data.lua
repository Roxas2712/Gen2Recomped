package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local F = require("tests.terrain_animation.fixture")
local Copy = require("src.mods.Merge").deepCopy
local Renderer = require("src.render.TileRenderer")
local Tiles = require("src.render.Gen3Tiles")
local Json = require("src.link.Json")
local function layer(decoder, mid, which)
  local pixels = {}
  for i = 1, 256 do pixels[i] = "\0\0\0\0" end
  decoder:drawLayer(mid, which, 0, 0, function(x,y,r,g,b)
    pixels[y * 16 + x + 1] = string.char(r,g,b,255)
  end)
  return table.concat(pixels)
end
for _, version in ipairs({ "emerald", "firered" }) do
  for _, api in ipairs({ 1, 2 }) do
    local f = F.new(version, api, true)
    local s, e = f.state, f.exports
    local split = s.game.data.constants.gen3Layout.palettesInPrimary
    local first = split * 16 + 1
    f.records.P.paletteCycles = { { kind = "rotate", first = 17, count = 4, direction = 1, step = 3 } }
    local frameA, frameB = string.char(250,10,20, 30,240,50), string.char(1,2,230, 190,40,80)
    f.records.S.paletteCycles = { { kind = "frames", first = first, count = 2, step = 5,
      phase = 1, frames = { frameA, frameB } } }
    f.records.T.paletteCycles = {}
    T.eq(e.supports(1), true, "color contract on Gen3 API " .. api)
    T.eq(e.supports("1"), false, "color negotiation requires numeric version")
    local original = Json.encode(f.records)
    local base = assert(e.base(s.mapId))
    for tick = 0, 89 do
      local live = assert(e.colors(1, s.mapId))
      local ticks = Renderer.animFrame()
      local a, b = math.floor(ticks / 3) % 4, math.floor((ticks + 1) / 5) % 2
      T.eq(live.paletteAnimation.primaryFrames[1], a, "primary cycle keeps its own cadence")
      T.eq(live.paletteAnimation.secondaryFrames[1], b, "secondary cycle keeps its own cadence and phase")
      T.eq(live.animation.step, 8, "palette cadence never replaces native tile cadence")
      T.eq(live.paletteAnimation.ticks, live.animation.ticks, "all pictures sampled atomically at one clock")
      local expectedP, expectedS = Copy(f.records.P), Copy(f.records.S)
      for c = 0, 3 do expectedP.palettes[2][c + 2] = Copy(f.records.P.palettes[2][(c - a) % 4 + 2]) end
      local bytes = b == 0 and frameA or frameB
      for c = 0, 1 do expectedS.palettes[split + 1][c + 2] = { bytes:byte(c*3+1,c*3+3) } end
      local decoder = Tiles.new({ primary = expectedP, secondary = expectedS }, base.layout)
      decoder:setAnimFrame(live.animation.frame)
      for _, mid in ipairs({ 0, 1, 2, s.split, s.split + 1, s.split + 2 }) do
        for l = 1, 2 do
          T.eq(e.layer(live, mid, l), layer(decoder, mid, l), "public pixels equal independently selected native colors")
        end
      end
      local raw = assert(e.read(s.mapId))
      T.same(raw.primary.palettes, f.records.P.palettes, "legacy animated-source palettes retain base semantics")
      T.eq(assert(e.colors(1, s.mapId)).contentKey, live.contentKey, "read is stable without clock movement")
      Renderer.tick(1/60)
    end
    T.eq(Json.encode(f.records), original, "color and tile reads never mutate sources")
    local live = assert(e.colors(1, s.mapId))
    local nativeClock = Renderer.animFrame
    local start = nativeClock()
    Renderer.animFrame = function() return start + 480 end
    T.eq(assert(e.colors(1,s.mapId)).contentKey,live.contentKey,"full independent tile/palette period reuses content key")
    Renderer.animFrame = nativeClock
    local oldKey = live.contentKey
    f.records.P.palettes[2][2][1] = (f.records.P.palettes[2][2][1] + 1) % 256
    T.check(assert(e.colors(1, s.mapId)).contentKey ~= oldKey, "same-id cycle source edit invalidates content")
    live.primary.palettes[2][2][1] = -10
    T.check(assert(e.colors(1, s.mapId)).primary.palettes[2][2][1] >= 0, "result palette is detached")
    T.eq(#assert(e.colors(1,s.mapId)).secondary.paletteRGB8, 768, "complete packed secondary bank")
    local neighbor = assert(e.colors(1,s.mapId,s.neighborId))
    T.eq(#neighbor.paletteAnimation.secondaryFrames, 0, "resident neighbor uses its own palette cycles")
    T.check(neighbor.id ~= live.id, "different resident pair remains distinct")
    local clock, rand, file, gpu, now = Renderer.animFrame(), math.random, io.open, love.graphics.newImage, os.time
    math.random = function() error("unexpected random") end
    io.open = function() error("unexpected IO") end
    love.graphics.newImage = function() error("unexpected GPU") end
    os.time = function() error("observer must not update calendar") end
    local gameBefore = package.loaded["src.core.Game"]
    assert(e.colors(1,s.mapId))
    math.random, io.open, love.graphics.newImage, os.time = rand, file, gpu, now
    T.eq(Renderer.animFrame(), clock, "color observation never advances shared clock")
    T.eq(package.loaded["src.core.Game"], gameBefore, "color observation never bootstraps Game")
    T.eq(e.colors(1,"stale"), nil, "stale active map refused")
    T.eq(e.colors(1,s.mapId,"missing"), nil, "unloaded target refused")
    T.eq(e.colors(2,s.mapId), nil, "unsupported color version refused")
    f.run.release()
  end
end
T.finish("Public Gen3 palette cycle pixels and independent timing")
