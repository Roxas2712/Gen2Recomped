-- No image assets: synthetic PNG envelope validation only. By Roxas2712.
local Picture=require('src.pinball.LivePicture')
local function u32(n)return string.char(math.floor(n/16777216)%256,math.floor(n/65536)%256,math.floor(n/256)%256,n%256)end
local function chunk(kind,value)return u32(#value)..kind..value..'0000'end
local function picture(w,h,color,extra)
 return '\137PNG\13\10\26\10'..chunk('IHDR',u32(w)..u32(h)..string.char(8,color or 6,0,0,0))..(extra or '')..chunk('IDAT','fake')..chunk('IEND','')
end
assert(Picture.validate(picture(240,160),240,160))
assert(Picture.validate(picture(256,388,3),256,388),'native LOVE palette PNG is supported')
assert(not Picture.validate(picture(65535,65535),65535,65535),'allocation dimensions are bounded before decoding')
assert(not Picture.validate(picture(240,160),256,388),'claimed and encoded dimensions must agree')
assert(not Picture.validate(picture(240,160,6,chunk('iCCP',string.rep('x',50))),240,160),'compressed ancillary profiles are rejected')
assert(not Picture.validate(picture(240,160,6,chunk('IHDR',string.rep('x',13))),240,160),'duplicate headers are rejected')
assert(not Picture.validate(picture(240,160)..string.rep('a',20000),240,160),'wire image byte budget is enforced')
assert(not Picture.validate(picture(240,160):sub(1,-3),240,160),'truncated chunks are rejected')
print('Live pictures: palette PNG, dimension/byte limits, profile rejection and complete chunks passed')
