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

-- Sixteen four-color rows, 256 bytes total, nearest/linear sampling. Snapshot
-- byte values rather than palette table identity: mods edit ramps in place.
local Lut = {}; Lut.__index = Lut
local function channels(colors)
  assert(type(colors)=='table' and type(colors[1])=='table', 'palette rows required')
  local single = type(colors[1][1])=='number'
  local count = single and 1 or #colors
  assert(count >= 1 and count <= 16, 'palette LUT supports 1..16 rows')
  for p=1,count do
    local row=single and colors or colors[p]
    assert(type(row)=='table', 'palette row required')
    for i=1,4 do
      assert(type(row[i])=='table', 'four palette colors required')
      for c=1,3 do
        local v=row[i][c]
        assert(type(v)=='number' and v==v and v>=0 and v<=255, 'invalid palette channel')
      end
    end
  end
  return single,count
end
function Lut:update(colors)
  assert(not self.released, 'palette LUT released')
  local single,count=channels(colors)
  local changed=self.count~=count
  for p=1,16 do for i=1,4 do for c=1,3 do
    local row=p<=count and (single and colors or colors[p])
    local value=row and math.floor(row[i][c]+.5) or 0
    if self.last[(p-1)*12+(i-1)*3+c]~=value then changed=true end
  end end end
  if not changed then return false end
  for p=1,16 do for i=1,4 do
    local row=p<=count and (single and colors or colors[p])
    local color=row and row[i]
    self.data:setPixel((p-1)*4+i-1,0,color and color[1]/255 or 0,
      color and color[2]/255 or 0,color and color[3]/255 or 0,1)
  end end
  self.image:replacePixels(self.data)
  for p=1,16 do for i=1,4 do for c=1,3 do
    local row=p<=count and (single and colors or colors[p])
    self.last[(p-1)*12+(i-1)*3+c]=row and math.floor(row[i][c]+.5) or 0
  end end end
  self.count,self.revision=count,self.revision+1
  return true
end
function Lut:release()
  if self.released then return end
  self.image:release();self.data:release();self.released=true
end
function M.lut(colors)
  channels(colors) -- validate before allocating GPU resources
  local data=love.image.newImageData(64,1,'rgba8')
  local image=love.graphics.newImage(data,{linear=true,mipmaps=false})
  image:setFilter('nearest','nearest')
  local out=setmetatable({data=data,image=image,width=64,last={},revision=0},Lut)
  out:update(colors)
  return out
end

local shader,shaderFactory
function M.shader()
  local factory=love.graphics.newShader
  if shaderFactory~=factory then shaderFactory,shader=factory,nil end
  if shader==nil then
    local ok,value=pcall(factory, [[
      extern Image paletteLut;
      extern float paletteSlot;
      extern float paletteWidth;
      extern bool keyZero;
      vec4 effect(vec4 tint, Image source, vec2 uv, vec2 screen) {
        vec4 pixel = Texel(source, uv);
        float index = floor(pixel.r * 255.0 + 0.5);
        vec3 rgb = Texel(paletteLut, vec2((paletteSlot*4.0+index+0.5)/paletteWidth, 0.5)).rgb;
        float alpha = keyZero && index < 0.5 ? 0.0 : pixel.g;
        return vec4(rgb, alpha) * tint;
      }
    ]])
    shader=ok and value or false
  end
  return shader or nil
end
function M.bind(shader,lut,slot,keyed)
  assert(not lut.released and type(slot)=='number' and slot%1==0 and slot>=0 and slot<lut.count,
    'invalid palette slot')
  -- Public shader objects may have foreign uniform writes between draws.
  shader:send('paletteLut',lut.image)
  shader:send('paletteWidth',lut.width)
  shader:send('paletteSlot',slot)
  shader:send('keyZero',keyed==true)
end
return M
