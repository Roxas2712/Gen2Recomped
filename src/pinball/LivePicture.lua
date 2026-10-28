-- Validate the compressed envelope before asking an image decoder to allocate.
-- Contributions by Roxas2712.
local M={}
local function u32(s,p)local a,b,c,d=s:byte(p,p+3);return ((a*256+b)*256+c)*256+d end
function M.validate(bytes,width,height)
 if type(bytes)~='string'or #bytes<33 or #bytes>20000 or bytes:sub(1,8)~='\137PNG\13\10\26\10'
  or bytes:sub(13,16)~='IHDR'or u32(bytes,9)~=13 then return false end
 local w,h=u32(bytes,17),u32(bytes,21)
 if not(w==width and h==height and w>=1 and w<=512 and h>=1 and h<=512)then return false end
 local depth,color=bytes:byte(25,26)
 if not((color==2 or color==6)and depth==8 or color==3 and (depth==1 or depth==2 or depth==4 or depth==8))then return false end
 local position=9;local idat=false
 local limits={IHDR=13,PLTE=768,tRNS=256,gAMA=4,sRGB=1,pHYs=9,IDAT=20000,IEND=0}
 while position+11<=#bytes do
  local size=u32(bytes,position);local kind=bytes:sub(position+4,position+7)
  if not limits[kind]or size>limits[kind]or position+11+size>#bytes or kind=='IHDR'and position~=9 then return false end
  if kind=='IDAT'then idat=true end
  if kind=='IEND'then return idat and size==0 and position+11==#bytes end
  position=position+12+size
 end
 return false
end
return M
