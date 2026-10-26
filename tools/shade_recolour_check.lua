-- Run:  luajit tools/shade_recolour_check.lua
--
-- G7 -- THE GEN 1/2 SHADE BAKES AS FFI REGION COPIES, against the loops.
--
-- `ShadeRecolour.region` replaces six getPixel / setPixel loops that all go
-- through `recolorSample` (TileRenderer) or the OBP rule (SpriteRenderer).
-- The byte it writes must equal the byte the loop wrote for EVERY red value
-- and every alpha, with and without colours, in both modes; the shifted
-- water tile must equal the loop's wrap; and the wiring must leave each loop
-- in place as the fallback.  ImageData is stood in for with an FFI buffer
-- that answers getPixel / setPixel the way LÖVE's rgba8 does (byte / 255 out,
-- round(v * 255) in).
package.path = './?.lua;./?/init.lua;' .. package.path
local ffi = require('ffi')
love = love or require('tests.love_stub')
love.image = love.image or {}
local function imageData(w, h)
  local buf = ffi.new('uint8_t[?]', w * h * 4)
  local id = { w = w, h = h, buf = buf }
  function id:getDimensions() return w, h end
  function id:getWidth() return w end
  function id:getHeight() return h end
  function id:getFFIPointer() return buf end
  function id:getPixel(x, y)
    local o = (y * w + x) * 4
    return buf[o] / 255, buf[o + 1] / 255, buf[o + 2] / 255, buf[o + 3] / 255
  end
  function id:setPixel(x, y, r, g, b, a)
    local o = (y * w + x) * 4
    buf[o] = math.floor(r * 255 + 0.5); buf[o + 1] = math.floor(g * 255 + 0.5)
    buf[o + 2] = math.floor(b * 255 + 0.5); buf[o + 3] = math.floor(a * 255 + 0.5)
  end
  function id:release() end
  function id:bytes() return ffi.string(buf, w * h * 4) end
  return id
end
function love.image.newImageData(w, h, format) return imageData(w, h) end

local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end

local Performance = require('src.core.Performance')
check(Performance.shadeRecolourFfi == true, 'G7 is on by default')
local R = require('src.render.ShadeRecolour')
check(R.available() == true, 'the FFI path is available under LuaJIT')

-- ---------------------------------------------- the loops, transcribed
local function recolorSample(r, g, b, a, colors)
  if not (colors and a > 0) then return r, g, b, a end
  local col = r > 0.83 and colors[1] or r > 0.5 and colors[2]
              or r > 0.17 and colors[3] or colors[4]
  return col[1] / 255, col[2] / 255, col[3] / 255, a
end
local function obpSample(r, g, b, a, colors)
  if a == 0 then return r, g, b, a end
  if r > 0.83 then return r, g, b, 0 end
  local col = r > 0.5 and colors[2] or r > 0.17 and colors[3] or colors[4]
  return col[1] / 255, col[2] / 255, col[3] / 255, a
end

-- a source that holds every red byte x four alphas x a few g/b patterns
local W, H = 256, 8
local src = imageData(W, H)
local alphas = { 0, 1, 128, 255 }
for y = 0, H - 1 do
  for x = 0, W - 1 do
    local o = (y * W + x) * 4
    src.buf[o] = x
    src.buf[o + 1] = (x * 7 + y * 31) % 256
    src.buf[o + 2] = (x * 3 + y * 101) % 256
    src.buf[o + 3] = alphas[(y % 4) + 1]
  end
end
local colors = { { 248, 240, 200 }, { 160, 120, 90 }, { 80, 60, 40 }, { 10, 5, 0 } }

-- ------------------------------------------------- 1. whole, both modes
for _, mode in ipairs({ 'tile', 'obp' }) do
  local fast = R.whole(src, colors, mode)
  check(fast ~= nil, mode .. ': the FFI pass produced a surface')
  local ref = imageData(W, H)
  local sample = (mode == 'tile') and recolorSample or obpSample
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local r, g, b, a = src:getPixel(x, y)
      ref:setPixel(x, y, sample(r, g, b, a, colors))
    end
  end
  check(fast and fast:bytes() == ref:bytes(), mode .. ': every byte equals the loop (256 reds x 4 alphas)')
end
-- no colours: a straight copy in tile mode (recolorSample's own rule)
do
  local fast = R.whole(src, false, 'tile')
  check(fast and fast:bytes() == src:bytes(), 'tile with colors=false copies the pixels')
  local copy = R.whole(src, nil, 'copy')
  check(copy and copy:bytes() == src:bytes(), 'copy mode copies the pixels')
end

-- -------------------------------------------- 2. the threshold bytes
do
  local one = imageData(1, 1)
  local function shadeOf(red)
    one.buf[0], one.buf[1], one.buf[2], one.buf[3] = red, 0, 0, 255
    local out = imageData(1, 1)
    R.region(one, out, 0, 0, 1, 1, 0, 0, colors, 'tile')
    for i = 1, 4 do
      if out.buf[0] == colors[i][1] and out.buf[1] == colors[i][2] then return i end
    end
  end
  check(shadeOf(212) == 1 and shadeOf(211) == 2, 'the 0.83 cut falls between bytes 211 and 212')
  check(shadeOf(128) == 2 and shadeOf(127) == 3, 'the 0.5 cut falls between bytes 127 and 128')
  check(shadeOf(44) == 3 and shadeOf(43) == 4, 'the 0.17 cut falls between bytes 43 and 44')
  -- ...which is exactly where the loop's float compare puts them
  check((212 / 255 > 0.83) and not (211 / 255 > 0.83), 'float: 212 passes 0.83, 211 does not')
  check((128 / 255 > 0.5) and not (127 / 255 > 0.5), 'float: 128 passes 0.5, 127 does not')
  check((44 / 255 > 0.17) and not (43 / 255 > 0.17), 'float: 44 passes 0.17, 43 does not')
end

-- ------------------------------------------------- 3. the shifted tile
do
  local sheet = imageData(16, 16)
  for y = 0, 15 do for x = 0, 15 do
    local o = (y * 16 + x) * 4
    sheet.buf[o], sheet.buf[o + 1], sheet.buf[o + 2], sheet.buf[o + 3] = (x * 16 + y * 3) % 256, x, y, (x % 3 == 0) and 0 or 255
  end end
  for o = 0, 7 do
    local fast = R.shiftedTile(sheet, 8, 8, o, colors)
    local ref = imageData(8, 8)
    for y = 0, 7 do for x = 0, 7 do
      local r, g, b, a = sheet:getPixel(8 + x, 8 + y)
      r, g, b, a = recolorSample(r, g, b, a, colors)
      ref:setPixel((x + o) % 8, y, r, g, b, a)
    end end
    check(fast and fast:bytes() == ref:bytes(), ('shift %d equals the loop'):format(o))
  end
end

-- ----------------------------------------------- 4. bounds and the flag
do
  local out = imageData(4, 4)
  check(R.region(src, out, 0, 0, 8, 8, 0, 0, colors, 'tile') == nil, 'a block that does not fit the destination is refused')
  check(R.region(src, out, 254, 0, 4, 4, 0, 0, colors, 'tile') == nil, 'a block past the source edge is refused')
  check(R.region(src, out, 0, 0, 4, 4, 0, 0, colors, 'tile') == true, 'a block that fits is copied')
  Performance.shadeRecolourFfi = false
  check(R.whole(src, colors, 'tile') == nil and R.region(src, out, 0, 0, 4, 4, 0, 0, colors, 'tile') == nil, 'the flag turns the path off')
  Performance.shadeRecolourFfi = true
end

-- ------------------------------------------------------- 5. the wiring
do
  local tr = assert(io.open('src/render/TileRenderer.lua')):read('*a')
  local sr = assert(io.open('src/render/SpriteRenderer.lua')):read('*a')
  check(sr:find('local baked = ShadeRecolour.whole(id, colors, "obp")', 1, true) ~= nil, 'OBP sprite variants take the FFI pass')
  check(sr:find('id:mapPixel(function(_, _, r, g, b, a)', 1, true) ~= nil, 'and keep mapPixel as the fallback')
  check(tr:find('local v = ShadeRecolour.shiftedTile(id, sx, sy, o, colors)', 1, true) ~= nil, 'water shifts take the FFI pass')
  check(tr:find('local out2 = ShadeRecolour.whole(id, colors, "tile")', 1, true) ~= nil, 'animation frames take it')
  check(tr:find('ShadeRecolour.region(strip, clone, sx, 0, 8, 8, dx, dy, nil, "copy")', 1, true) ~= nil, 'toggles take it (copy)')
  check(tr:find('ShadeRecolour.region(strip, page, sx, sy, 8, 8, dx, dy, tint, "tile")', 1, true) ~= nil, 'atlas frames take it')
  check(tr:find('ShadeRecolour.region(src, out, ox, oy, 8, 8, ox, oy, colors, "tile")', 1, true) ~= nil, 'the RED++ atlas takes it')
  check(tr:find('ShadeRecolour.region(src, out, sxo, syo, 8, 8, dxo, dyo, colors, "tile")', 1, true) ~= nil, 'and its tile aliases')
  local _, loops = tr:gsub('r, g, b, a = recolorSample%(r, g, b, a, ', '')
  check(loops >= 5, 'every per-pixel loop is still there as the fallback (' .. loops .. ')')
end

print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
