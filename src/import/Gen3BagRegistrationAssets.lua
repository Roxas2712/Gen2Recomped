-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Existing pinned version tables provide each cartridge's own source offsets.
local M={}
function M.supports(version)return version=='firered'or version=='leafgreen'end
function M.addresses(version)
  assert(M.supports(version))
  local load=require('compat.gen1-rs.Loader').new(version,{
    ['src.core.GameVersion']=require('src.core.GameVersion'),__package={loaded={}}})
  local V=load('src.import.gba.versions_frlg');V.select(version)
  return assert(V.BAG_SELECT_BUTTON),assert(V.BAG_WINDOW_PAL),load
end
function M.extract(x)
  if not M.supports(x.version)then return end
  local screen=assert(x._constants.gen3BagScreen)
  assert(screen.layout=='frlg','Own native FRLG bag screen is required')
  local gfx,pal,load=M.addresses(x.version)
  local Image=require('src.import.ImageWriter')
  local Bake=load('src.import.gba.bg_bake')
  local image=Image.blank(24,16);local inked=0
  for y=0,15 do for px=0,23 do
    local tile=math.floor(y/8)*3+math.floor(px/8)
    local byte=x.rom:u8(gfx+tile*32+(y%8)*4+math.floor((px%8)/2))
    local index=px%2==0 and byte%16 or math.floor(byte/16)
    if index~=0 then
      local r,g,b=Bake.bgr555ToRgb8(x.rom:u16(pal+index*2))
      image:setPixel(px,y,r/255,g/255,b/255,1);inked=inked+1
    end
  end end
  assert(inked>0,'Own native SELECT bitmap is empty')
  local path='ui/bag_registered.png';x:saveImage(image,path)
  screen.registered={format=1,version=x.version,male='assets/generated/'..path,
    female='assets/generated/'..path,x=112,dy=0,width=24,height=16,
    source=('ROM:sBlit_SelectButton %07X, sBagWindowPalF %07X'):format(gfx,pal)}
  x:write('constants',x._constants)
end
function M.valid(spec,version)
  return M.supports(version)and type(spec)=='table'and spec.format==1 and spec.version==version
    and type(spec.male)=='string'and spec.male~=''and spec.female==spec.male
    and spec.width==24 and spec.height==16 and spec.x==112 and spec.dy==0
end
function M.missing(version)
  if not M.supports(version)then return{}end
  local Fs=require('src.import.CacheFs');local raw=Fs.read('data/generated/constants.lua')
  local f=raw and loadstring(raw);if f then setfenv(f,{})end
  local ok,c=false,nil;if f then ok,c=pcall(f)end
  local spec=ok and type(c)=='table'and type(c.gen3BagScreen)=='table'and c.gen3BagScreen.registered
  if M.valid(spec,version)and Fs.exists(spec.male)then return{}end
  return{'<'..version..':native-bag-registration>'}
end
return M
