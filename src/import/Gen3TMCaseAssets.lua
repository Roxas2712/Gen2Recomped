-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- FRLG's HM list tag is four 8x8 OBJ tiles, cropped to twelve rows.
local M={FORMAT=1,PATH='assets/generated/pockets_frlg/hm_tag.png'}
function M.supports(version)return version=='firered'or version=='leafgreen'end
function M.decodeHmTag(raw,palette)
  assert(type(raw)=='table'and#raw==128,'HM tag requires four 4bpp tiles')
  local image=require('src.import.ImageWriter').blank(16,12)
  for y=0,11 do for x=0,15 do
    local tile=math.floor(y/8)*2+math.floor(x/8)
    local byte=raw[tile*32+(y%8)*4+math.floor((x%8)/2)+1]
    local index=x%2==0 and byte%16 or math.floor(byte/16)
    local color=index~=0 and palette[index]
    if color then image:setPixel(x,y,color[1]/255,color[2]/255,color[3]/255,1)end
  end end
  return image
end
function M.valid(record,version)
  return M.supports(version)and type(record)=='table'and record.format==M.FORMAT
    and record.version==version and type(record.images)=='table'and record.images.hm_tag==M.PATH
end
local function imageReady(raw)
  if type(raw)~='string'or#raw<57 or raw:sub(1,8)~='\137PNG\r\n\26\n'
    or raw:sub(13,16)~='IHDR'or raw:sub(-8,-5)~='IEND'then return false end
  local function u32(at)
    local a,b,c,d=raw:byte(at,at+3);return ((a*256+b)*256+c)*256+d
  end
  return u32(17)==16 and u32(21)==12
end
function M.missing(version)
  if not M.supports(version)then return{}end
  local Fs=require('src.import.CacheFs');local raw=Fs.read('data/generated/constants.lua')
  local chunk=raw and loadstring(raw);if chunk then setfenv(chunk,{})end
  local ok,constants=false,nil;if chunk then ok,constants=pcall(chunk)end
  local record=ok and type(constants)=='table'and constants.gen3FRLGPocketArt
  if M.valid(record,version)and imageReady(Fs.read(M.PATH))then return{}end
  return{'<'..version..':tm-case-hm-tag>'}
end
return M
