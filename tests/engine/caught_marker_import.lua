package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Extractor = require("src.import.RomExtractorGen3")
local previous = love.image
love.image = {}
local pixels
love.image.newImageData = function(w, h)
  pixels = { w = w, h = h }
  return {
    setPixel = function(_, x, y, ...)
      pixels[y * w + x] = { ... }
    end,
    mapPixel = function(self, fn)
      for y = 0, h - 1 do
        for x = 0, w - 1 do
          self:setPixel(x, y, fn(x, y, 0, 0, 0, 0))
        end
      end
    end,
  }
end
local extractor = setmetatable({
  saveImage = function(_, image, path)
    T.eq(path, "battle/hud/caught.png", "native marker has a dedicated cache asset")
  end,
}, { __index = Extractor })
local elements = {}
for i = 1, 71 * 32 do
  elements[i] = 0
end
-- Tile 69 differs deliberately; decoding its neighbor would fail every pixel.
for i = 69 * 32 + 1, 70 * 32 do
  elements[i] = 0x33
end
for i = 70 * 32 + 1, 71 * 32 do
  elements[i] = i % 2 == 0 and 0x21 or 0x10
end
local palette = { { 0, 0, 0 }, { 255, 0, 0 }, { 0, 255, 0 }, { 0, 0, 255 } }
T.eq(
  extractor:battleCaughtMarker(elements, palette),
  "assets/generated/battle/hud/caught.png",
  "import publishes tile 70 path"
)
T.eq(pixels.w, 8, "native caught marker is eight pixels wide")
T.eq(pixels.h, 8, "native caught marker is eight pixels high")
for y = 0, 7 do
  for x = 0, 7 do
    local value = pixels[y * 8 + x]
    local byte = elements[70 * 32 + y * 4 + math.floor(x / 2) + 1]
    local index = x % 2 == 0 and byte % 16 or math.floor(byte / 16)
    local expected = palette[index + 1]
    T.eq(value[4], index == 0 and 0 or 1, "4bpp zero remains transparent")
    if index > 0 then
      for channel = 1, 3 do
        T.eq(value[channel], expected[channel] / 255, "native tile/palette channel")
      end
    end
  end
end
T.eq(extractor:battleCaughtMarker({}, palette), nil, "short optional old sheet is unavailable")
love.image = previous
T.finish("native caught-marker 4bpp import")
