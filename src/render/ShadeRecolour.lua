-- G7 -- THE GEN 1/2 SHADE BAKES AS ONE FFI REGION COPY.
--
-- Six bakes in TileRenderer and SpriteRenderer do the same thing: walk a
-- region of a DMG-grey ImageData pixel by pixel through `recolorSample`
-- (a threshold on red picks one of four colours) and write it into another
-- ImageData -- with getPixel / setPixel, a C call each way per pixel.  The
-- RED++ atlas does it for a whole sheet on every map change; an OBP sprite
-- variant for a whole sheet per palette and time of day.  Those are the
-- Gen 1/2 map-change hitches.
--
-- The thresholds the bakes compare against are `r > 0.83 / 0.5 / 0.17` on a
-- byte read back as byte / 255: 212/255 = 0.8314 passes 0.83 and 211 does
-- not, 128 passes 0.5 and 127 does not, 44 passes 0.17 and 43 does not.
-- So on bytes the cuts are >= 212, >= 128, >= 44 -- exact, no float.  The
-- colour written is `col / 255` through setPixel, which lands on the byte
-- `col` again, and alpha is carried as is.  Every pixel therefore comes out
-- identical to the loop it replaces; tools/shade_recolour_check.lua holds
-- the two against each other on every byte value.
--
-- Without the FFI, or with Performance.shadeRecolourFfi = false, every
-- function answers nil and the caller runs its loop as before.
local Performance = require("src.core.Performance")

local R = {}

local ffiOk, ffi = pcall(require, "ffi")
if not ffiOk then ffi = nil end

local function pointer(imageData)
  if not (imageData and imageData.getFFIPointer) then return nil end
  local ok, ptr = pcall(imageData.getFFIPointer, imageData)
  if not ok or ptr == nil then return nil end
  return ffi.cast("uint8_t *", ptr)
end

function R.available()
  return ffi ~= nil and Performance.shadeRecolourFfi ~= false
end

-- The four colours as bytes, index 1..4 for shades 0..3; `false` (no colours)
-- means "copy the pixels as they are", exactly as recolorSample does.
local function table4(colors)
  if not colors then return nil end
  local out = {}
  for i = 1, 4 do
    local c = colors[i]
    out[i] = { math.floor(c[1]), math.floor(c[2]), math.floor(c[3]) }
  end
  return out
end

-- region(src, dst, sx, sy, w, h, dx, dy, colors, mode)
--
-- Copies the w x h block at (sx, sy) of `src` to (dx, dy) of `dst`, both
-- rgba8 ImageData, recolouring through `colors` by `mode`:
--   "tile"  recolorSample: a > 0 -> shade colour (colors[1..4]); a == 0 kept
--   "obp"   getObpImage:   a == 0 kept; shade 0 -> rgb kept, alpha 0;
--                          shades 1..3 -> colors[2..4], alpha kept
--   "copy"  no colours: bytes copied
-- Returns true, or nil when the FFI path is unavailable or the block does
-- not fit either image (the caller then runs its own loop).
function R.region(src, dst, sx, sy, w, h, dx, dy, colors, mode)
  if not R.available() then return nil end
  local sw, sh = src:getDimensions()
  local dw, dh = dst:getDimensions()
  if sx < 0 or sy < 0 or dx < 0 or dy < 0 or w <= 0 or h <= 0
     or sx + w > sw or sy + h > sh or dx + w > dw or dy + h > dh then
    return nil
  end
  local s, d = pointer(src), pointer(dst)
  if not (s and d) then return nil end
  local tab = (mode ~= "copy") and table4(colors) or nil
  if mode ~= "copy" and not tab then mode = "copy" end
  local obp = mode == "obp"
  for y = 0, h - 1 do
    local so = ((sy + y) * sw + sx) * 4
    local dob = ((dy + y) * dw + dx) * 4
    for x = 0, w - 1 do
      local si, di = so + x * 4, dob + x * 4
      local r, g, b, a = s[si], s[si + 1], s[si + 2], s[si + 3]
      if mode == "copy" or a == 0 then
        d[di], d[di + 1], d[di + 2], d[di + 3] = r, g, b, a
      elseif obp and r >= 212 then
        d[di], d[di + 1], d[di + 2], d[di + 3] = r, g, b, 0
      else
        local c
        if r >= 212 then c = tab[1]
        elseif r >= 128 then c = tab[2]
        elseif r >= 44 then c = tab[3]
        else c = tab[4] end
        d[di], d[di + 1], d[di + 2], d[di + 3] = c[1], c[2], c[3], a
      end
    end
  end
  return true
end

-- whole(src, colors, mode) -> a new ImageData the size of `src`, or nil
function R.whole(src, colors, mode)
  if not R.available() then return nil end
  local w, h = src:getDimensions()
  local ok, dst = pcall(love.image.newImageData, w, h, "rgba8")
  if not ok or not dst then return nil end
  if not R.region(src, dst, 0, 0, w, h, 0, 0, colors, mode) then
    if dst.release then dst:release() end
    return nil
  end
  return dst
end

-- shiftedTile(src, sx, sy, o, colors) -> an 8x8 ImageData of the tile at
-- (sx, sy) with every column moved right by `o` (wrapping), recoloured as
-- "tile"; the water animation's eight variants.  nil when unavailable.
function R.shiftedTile(src, sx, sy, o, colors)
  if not R.available() then return nil end
  local ok, dst = pcall(love.image.newImageData, 8, 8, "rgba8")
  if not ok or not dst then return nil end
  o = o % 8
  local okA = true
  if o == 0 then
    okA = R.region(src, dst, sx, sy, 8, 8, 0, 0, colors, "tile")
  else
    -- columns 0..7-o land at o..7; columns 8-o..7 land at 0..o-1
    okA = R.region(src, dst, sx, sy, 8 - o, 8, o, 0, colors, "tile")
      and R.region(src, dst, sx + 8 - o, sy, o, 8, 0, 0, colors, "tile")
  end
  if not okA then
    if dst.release then dst:release() end
    return nil
  end
  return dst
end

return R
