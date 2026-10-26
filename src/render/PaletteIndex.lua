-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Private RAM-only derivation. Authored PNGs and public RGBA images stay intact.
local M = {}
local ffiOK, ffi = pcall(require, 'ffi')
local derived = setmetatable({}, {__mode='k'})

local function shade(r)
  return r > 0.83 and 0 or r > 0.5 and 1 or r > 0.17 and 2 or 3
end

-- RG8: R is the integer shade index divided by 255; G is source alpha.
-- Transparent pixels canonicalize to index zero. Partial alpha is preserved.
-- Weak source keys cannot keep a decoded PNG alive after its asset is dropped.
function M.fromImageData(source)
  local cached = derived[source]
  if cached then return cached end
  local w, h = source:getDimensions()
  local out = love.image.newImageData(w, h, 'rg8')
  local fast = ffiOK and source.getFormat and source:getFormat() == 'rgba8'
    and source.getFFIPointer and out.getFFIPointer
  if fast then
    local input, output = source:getFFIPointer(), out:getFFIPointer()
    if input ~= nil and output ~= nil then
      local src, dst = ffi.cast('const uint8_t*', input), ffi.cast('uint8_t*', output)
      for i = 0, w*h-1 do
        local r, a = src[i*4], src[i*4+3]
        dst[i*2] = a == 0 and 0 or r > 211.65 and 0 or r > 127.5 and 1 or r > 43.35 and 2 or 3
        dst[i*2+1] = a
      end
      derived[source] = out
      return out
    end
  end
  for y = 0, h-1 do for x = 0, w-1 do
    local r, _, _, a = source:getPixel(x, y)
    out:setPixel(x, y, (a == 0 and 0 or shade(r))/255, a, 0, 1)
  end end
  derived[source] = out
  return out
end

-- A caller mutating its ImageData must invalidate before deriving again.
-- Existing returned data remains caller-usable; no foreign handle is released.
function M.invalidate(source)
  if source then derived[source] = nil
  else derived = setmetatable({}, {__mode='k'}) end
end
return M
