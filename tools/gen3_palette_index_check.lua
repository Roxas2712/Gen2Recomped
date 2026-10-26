-- Run:  luajit tools/gen3_palette_index_check.lua
--
-- G5 -- THE GEN 3 PALETTE CYCLE AS AN INDEX LOOKUP, against the RGBA bake.
--
-- A palette cycle used to re-walk every metatile into a new RGBA sheet.  G5
-- bakes the sheet once as one byte per pixel (palette * 16 + colour) and
-- resolves it through `Gen3Tiles:colourTable()` in an FFI loop.  The pixels
-- must come out identical, so this check drives `Gen3Tiles:drawLayer` both
-- ways over a synthetic pair -- flips, several palettes, index 0 holes, a
-- missing palette, a missing colour, out-of-sheet plots -- and compares the
-- recoloured bytes with the bake's bytes, under two different palette
-- states.  No GPU, ROM or window: ImageData is stood in for with an FFI
-- buffer that offers exactly what the engine asks of it.

package.path = './?.lua;./?/init.lua;' .. package.path
local ffi = require('ffi')
love = love or require('tests.love_stub')
love.image = love.image or {}
function love.image.newImageData(w, h, format, data)
  assert(format == 'rgba8', 'the engine asks for rgba8 and nothing else')
  local buf = ffi.new('uint8_t[?]', w * h * 4)
  if data then
    assert(#data == w * h * 4, 'a string-backed ImageData is exactly w*h*4 bytes')
    ffi.copy(buf, data, #data)
  end
  return {
    buf = buf,
    getFFIPointer = function() return buf end,
    getWidth = function() return w end,
    getHeight = function() return h end,
    bytes = function() return ffi.string(buf, w * h * 4) end,
  }
end

local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end

local Gen3Tiles = require('src.render.Gen3Tiles')
local TileRenderer = require('src.render.TileRenderer')
local P = assert(TileRenderer._gen3IndexProbe, 'TileRenderer must export its G5 probe')
check(P.available() == true, 'the index path is available under LuaJIT with the flag on')

-- ------------------------------------------------- a synthetic tile pair
-- two 8x8 tiles: a diagonal of colour 1..7 on a hole of 0, and a solid 9
local function tile(fn)
  local px = {}
  for y = 0, 7 do for x = 0, 7 do px[y * 8 + x + 1] = fn(x, y) end end
  return px
end
local tiles = {
  [0] = tile(function(x, y) return (x == y) and (x % 7 + 1) or 0 end),
  [1] = tile(function() return 9 end),
  [2] = tile(function(x, y) return ((x + y) % 2 == 0) and 15 or 3 end),
}
local function word(t, flipX, flipY, pal)
  return t + (flipX and 1024 or 0) + (flipY and 2048 or 0) + pal * 4096
end
local function metatile(words)
  local out = {}
  for i = 1, 8 do
    local w = words[i] or 0
    out[#out + 1] = string.char(w % 256, math.floor(w / 256))
  end
  return table.concat(out)
end
-- three metatiles: layer 1 = entries 1..4, layer 2 = entries 5..8
local metatiles = table.concat({
  metatile({ word(0, false, false, 0), word(1, true, false, 2), word(2, false, true, 5), word(0, true, true, 0),
             word(1, false, false, 1), 0, 0, word(2, false, false, 7) }),
  metatile({ word(2, false, false, 9), word(2, true, true, 9), word(0, false, false, 14), word(1, false, false, 15),
             word(0, true, false, 3), word(0, false, true, 3), 0, 0 }),
  metatile({ word(1, false, false, 11), word(1, false, false, 11), word(1, false, false, 11), word(1, false, false, 11),
             word(2, false, false, 11), word(2, false, false, 11), word(2, false, false, 11), word(2, false, false, 11) }),
})
local function palettes(seed)
  local out = {}
  for pal = 0, 15 do
    local p = {}
    for v = 0, 15 do
      p[v + 1] = { (pal * 17 + v * 13 + seed) % 256, (pal * 7 + v * 29 + seed * 3) % 256, (v * 16 + seed * 5) % 256 }
    end
    -- palette 14 lacks colour 15 entirely; palette 15 is missing
    if pal == 14 then p[16] = nil end
    if pal ~= 15 then out[pal] = p end
  end
  return out
end
local function pair(seed)
  local pals = palettes(seed)
  local record = { metatiles = metatiles, attributes = string.rep('\0', 6) }
  return setmetatable({
    primary = record, secondary = nil,
    metatilesInPrimary = 3, tilesInPrimary = 3, palettesInPrimary = 16,
    layers = 2, tileCache = {},
    tilePixels = function(_, index) return tiles[index] end,
    palette = function(_, index) return pals[index] end,
    metatileCount = function() return 3 end,
  }, { __index = Gen3Tiles })
end

-- ---------------------------------------- 1. byte-identical sheets
local W, H = 48, 16
for _, seed in ipairs({ 1, 90 }) do
  local t = pair(seed)
  for layer = 1, 2 do
    local plot, finish = P.pixelCanvas(W, H)
    t:bakeLayer(layer, plot)
    local reference = finish():bytes()
    local iplot, ifinish = P.indexCanvas(W, H)
    t:bakeLayer(layer, iplot, true)
    local index = ifinish()
    check(#index == W * H, ('seed %d layer %d: one byte per pixel'):format(seed, layer))
    local surface = P.recolour(index, W, H, t:colourTable())
    check(surface ~= nil, ('seed %d layer %d: the FFI recolour produces a surface'):format(seed, layer))
    check(surface and surface:bytes() == reference,
          ('seed %d layer %d: recoloured bytes equal the RGBA bake'):format(seed, layer))
  end
end

-- ------------------------------------- 2. a cycle is only a new table
do
  local a, b = pair(1), pair(90)
  local iplot, ifinish = P.indexCanvas(W, H)
  a:bakeLayer(1, iplot, true)
  local index = ifinish()
  local iplot2, ifinish2 = P.indexCanvas(W, H)
  b:bakeLayer(1, iplot2, true)
  check(ifinish2() == index, 'the index sheet does not depend on the palettes')
  local plot, finish = P.pixelCanvas(W, H)
  b:bakeLayer(1, plot)
  check(P.recolour(index, W, H, b:colourTable()):bytes() == finish():bytes(),
        'the same indices under the second palette state equal the second bake')
  check(a:colourTable() ~= b:colourTable(), 'and the two states have different colour tables')
end

-- --------------------------------------------------- 3. the table itself
do
  local t = pair(1)
  local lut = t:colourTable()
  check(#lut == 1024, 'the colour table is 256 entries of four bytes')
  check(lut:sub(1, 4) == '\0\0\0\0', 'entry 0 is transparent')
  for pal = 0, 15 do
    check(lut:sub(pal * 64 + 1, pal * 64 + 4) == '\0\0\0\0', ('colour 0 of palette %d is transparent'):format(pal))
  end
  local c = t:palette(2)[10]
  check(lut:sub(2 * 64 + 9 * 4 + 1, 2 * 64 + 9 * 4 + 4) == string.char(c[1], c[2], c[3], 255),
        'entry pal * 16 + v is palette pal colour v, opaque')
  check(lut:sub(14 * 64 + 15 * 4 + 1, 14 * 64 + 15 * 4 + 4) == '\0\0\0\0', 'a missing colour is transparent')
  check(lut:sub(15 * 64 + 1, 15 * 64 + 64) == string.rep('\0', 64), 'a missing palette is transparent throughout')
end

-- -------------------------------------------------- 4. out-of-sheet plots
do
  local plot, finish = P.indexCanvas(4, 4)
  plot(-1, 0, 1, 1); plot(4, 0, 1, 1); plot(0, 4, 1, 1); plot(3, 3, 2, 5)
  local s = finish()
  check(#s == 16 and s:byte(16) == 2 * 16 + 5 and s:sub(1, 15) == string.rep('\0', 15),
        'plots outside the sheet are dropped, inside ones land at y * w + x')
end

-- ------------------------------------------------------ 5. the wiring
do
  local src = assert(io.open('src/render/TileRenderer.lua')):read('*a')
  check(src:find('record.gen3Index = index', 1, true) ~= nil, 'the sheet record keeps its indices')
  check(src:find('local idx = record.gen3Index', 1, true) ~= nil, 'recolor resolves them before considering a bake')
  check(src:find('if not index then', 1, true) ~= nil, 'the RGBA bake remains as the fallback')
  local g3 = assert(io.open('src/render/Gen3Tiles.lua')):read('*a')
  check(g3:find('function Gen3Tiles:bakeLayer(layer, plot, indexed)', 1, true) ~= nil, 'bakeLayer passes indexed through')
  check(g3:find('function Gen3Tiles:bakeMetatileInto(id, layer, slot, plot, indexed)', 1, true) ~= nil, 'bakeMetatileInto passes indexed through')
  local Performance = require('src.core.Performance')
  check(Performance.gen3PaletteIndex == true, 'G5 is on by default')
end

print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
