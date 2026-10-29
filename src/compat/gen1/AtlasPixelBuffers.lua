-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Private fixed-size CPU scratch; returned strings own their bytes. No image,
-- native clock, graphics operation or caller-owned table is changed here.
local ok,ffi=pcall(require,'ffi')
local P={}
local floor=math.floor
local function plain(t)return type(t)=='table'and getmetatable(t)==nil end
function P.compatible(d,Tiles)
 if not ok or not P._workerCompatible()or getmetatable(d)~=Tiles or not plain(d.primary)or(d.secondary~=nil and not plain(d.secondary))or not plain(d.tileCache)then return false end
 local guard=rawget(Tiles,'_workerCompatible');if type(guard)~='function'or not guard()then return false end
 for _,name in ipairs{'entries','tilePixels','tileBank','metatileBank','attributes','topIsAbovePlayer'}do
  if rawget(d,name)~=nil then return false end
 end
 return true
end
function P.new()
 if not ok then return end
 local b={under=ffi.new('uint8_t[256]'),over=ffi.new('uint8_t[256]'),
  lut=ffi.new('uint32_t[256]'),rgbaBytes=ffi.new('uint32_t[256]')}
 return setmetatable(b,{__index=P})
end
function P:palette(lut)
 if not plain(lut)then return false end
 for i=0,255 do
  local color=lut[i]
  if type(color)~='string'or #color~=4 then return false end
  -- Copy bytes rather than interpreting channel arithmetic/endian order.
  ffi.copy(self.lut+i,color,4)
 end
 return true
end
function P:indexed(d,mid)
 ffi.fill(self.under,256);ffi.fill(self.over,256)
 local above=d:topIsAbovePlayer(mid)
 for n,e in ipairs(d:entries(mid))do
  local layer=floor((n-1)/4);local dest=layer==0 and self.under or(above and self.over or self.under)
  local q=(n-1)%4;local base=floor(q/2)*128+(q%2)*8
  local pixels=d:tilePixels(e.tile)
  if not plain(pixels)then return end
  for y=0,7 do
   local sy=e.flipY and 7-y or y;local at=base+y*16
   for x=0,7 do
    local sx=e.flipX and 7-x or x;local color=pixels[sy*8+sx+1]or 0
    if color~=0 or layer==0 then
     local value=color==0 and 0 or(e.palette*16+color)
     -- Keep the ordinary string.char path for unsupported/malformed values.
     -- Positive fractional values truncate exactly as string.char does.
     if type(value)~='number'or value~=value or value<0 or value>=256 then return end
     dest[at+x]=value
    end
   end
  end
 end
 return ffi.string(self.under,256),ffi.string(self.over,256)
end
function P:rgba(indices,over)
 if type(indices)~='string'or #indices<256 then return end
 local src=ffi.cast('const uint8_t*',indices);local out=self.rgbaBytes;local lut=self.lut
 for i=0,255 do local index=src[i];out[i]=over and index==0 and 0 or lut[index]end
 return ffi.string(out,1024)
end
function P:used(under,over)
 if type(under)~='string'or #under<256 or type(over)~='string'or #over<256 then return end
 local u,o=ffi.cast('const uint8_t*',under),ffi.cast('const uint8_t*',over);local used={}
 for i=0,255 do used[floor(u[i]/16)]=true;if o[i]~=0 then used[floor(o[i]/16)]=true end end
 return used
end
local methods={};for key,value in pairs(P)do methods[key]=value end
function P._workerCompatible()
 if getmetatable(P)~=nil then return false end
 for key,value in pairs(methods)do if P[key]~=value then return false end end
 for key in pairs(P)do if key~='_workerCompatible'and methods[key]==nil then return false end end
 return true
end
return P
