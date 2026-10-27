-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local ffi = require('ffi')
local checks = 0
local function check(v,label)checks=checks+1;assert(v,label)end
local function data(w,h,format)
  local stride = format == 'rg8' and 2 or 4
  local bytes = ffi.new('uint8_t[?]', w*h*stride)
  local d = {}
  function d:getDimensions()return w,h end
  function d:getFormat()return format end
  function d:getFFIPointer()return bytes end
  function d:getPixel(x,y)
    local i=(y*w+x)*stride
    return bytes[i]/255,bytes[i+1]/255,stride==4 and bytes[i+2]/255 or 0,stride==4 and bytes[i+3]/255 or 1
  end
  function d:setPixel(x,y,r,g,b,a)
    local i=(y*w+x)*stride
    bytes[i],bytes[i+1]=math.floor(r*255+.5),math.floor(g*255+.5)
    if stride==4 then bytes[i+2],bytes[i+3]=math.floor(b*255+.5),math.floor(a*255+.5)end
  end
  function d:bytes()return ffi.string(bytes,w*h*stride)end
  return d
end
love={image={newImageData=data}}
local P=require('src.render.PaletteIndex')
local source=data(256,256,'rgba8')
for a=0,255 do for r=0,255 do source:setPixel(r,a,r/255,(255-r)/255,1,a/255)end end
local original=source:bytes()
local fast=P.fromImageData(source)
check(fast:getFormat()=='rg8','index/alpha result uses RG8')
check(#fast:bytes()==256*256*2,'derived texture uses two bytes per source pixel')
check(source:bytes()==original,'derivation cannot mutate authored source')
check(P.fromImageData(source)==fast,'source identity cache reuses derived data')
for a=0,255 do for r=0,255 do
  local index,alpha=fast:getPixel(r,a)
  local red=r/255
  local expected=a==0 and 0 or red>.83 and 0 or red>.5 and 1 or red>.17 and 2 or 3
  check(math.floor(index*255+.5)==expected,'red-channel shader threshold at '..r..'/'..a)
  check(math.floor(alpha*255+.5)==a,'source alpha at '..r..'/'..a)
end end
source.getFFIPointer=nil
P.invalidate(source)
local portable=P.fromImageData(source)
check(portable:bytes()==fast:bytes(),'portable setPixel and FFI loops are byte identical')
source:setPixel(10,10,1,1,1,1)
check(P.fromImageData(source)==portable,'mutation requires explicit invalidation')
P.invalidate(source)
check(P.fromImageData(source)~=portable,'invalidating a mutable source replaces only its cache entry')
local boundary={getDimensions=function()return 6,1 end,getPixel=function(_,x)
  local r=({.83,.830001,.5,.500001,.17,.170001})[x+1];return r,r,r,1
end}
local b=P.fromImageData(boundary)
for x,index in ipairs{1,0,2,1,3,2}do local r=b:getPixel(x-1,0);check(math.floor(r*255+.5)==index,'strict floating threshold '..x)end
local weak=setmetatable({source},{__mode='v'})
source=nil;collectgarbage();collectgarbage()
check(weak[1]==nil,'derived data does not retain the source ImageData')
P.invalidate()
check(P.fromImageData(boundary)~=b,'global invalidation starts a fresh cache')
print('PALETTE_INDEX_DERIVE_PASS '..checks..' checks')
