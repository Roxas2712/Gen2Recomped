-- BPS1 decoder. Copyright (c) 2026 Roxas2712, GPL-3.0.
-- Original implementation; format: https://www.romhacking.net/documents/746/
local bit=require('bit')
local B={}
local crcTable={}
for i=0,255 do
 local n=i
 for _=1,8 do n=bit.bxor(bit.rshift(n,1),bit.band(n,1)==1 and 0xedb88320 or 0)end
 crcTable[i]=n
end
local function unsigned(n)return n<0 and n+4294967296 or n end
function B.crc32(bytes,progress,phase)
 local crc=-1
 for i=1,#bytes do
  crc=bit.bxor(bit.rshift(crc,8),crcTable[bit.band(bit.bxor(crc,bytes:byte(i)),255)])
  if progress and i%262144==0 then progress(i,#bytes,phase or 'verify')end
 end
 return unsigned(bit.bnot(crc))
end
local function u32(bytes,at)
 local a,b,c,d=bytes:byte(at,at+3);assert(d,'Truncated BPS checksum')
 return a+b*256+c*65536+d*16777216
end
function B.apply(source,patch,limit,progress)
 assert(type(source)=='string' and type(patch)=='string','BPS requires byte strings')
 assert(#patch>=19 and patch:sub(1,4)=='BPS1','Invalid BPS header')
 limit=limit or 32*1024*1024
 assert(type(limit)=='number' and limit>=0 and limit<=64*1024*1024,'Invalid BPS output limit')
 local last=#patch-12;local at=5
 local function number()
  local value,shift=0,1
  for _=1,8 do
   assert(at<=last,'Truncated BPS integer')
   local b=patch:byte(at);at=at+1
   value=value+(b%128)*shift;assert(value<=9007199254740991,'BPS integer overflow')
   if b>=128 then return value end
   shift=shift*128;value=value+shift
  end
  error('BPS integer overflow')
 end
 local sourceSize,targetSize,metadata=number(),number(),number()
 assert(sourceSize==#source,'BPS source size mismatch')
 assert(targetSize<=limit,'BPS output exceeds its limit')
 assert(metadata<=last-at+1,'Truncated BPS metadata');at=at+metadata
 assert(B.crc32(patch:sub(1,-5),progress,'patch')==u32(patch,#patch-3),'BPS patch checksum mismatch')
 assert(B.crc32(source,progress,'source')==u32(patch,#patch-11),'BPS source checksum mismatch')
 local out,starts,written,sourceAt,targetAt={},{},0,0,0
 local nextProgress=262144
 local function produced(position,length)
  local lo,hi=1,#starts
  while lo<=hi do local mid=math.floor((lo+hi)/2)
   if starts[mid]<=position then lo=mid+1 else hi=mid-1 end
  end
  local chunks={};local index=hi
  while length>0 do
   local chunk=assert(out[index]);local offset=position-starts[index]
   local take=math.min(length,#chunk-offset);assert(take>0,'Invalid BPS target span')
   chunks[#chunks+1]=chunk:sub(offset+1,offset+take)
   position=position+take;length=length-take;index=index+1
  end
  return table.concat(chunks)
 end
 while written<targetSize do
  local action=number();local kind=action%4;local length=math.floor(action/4)+1
  assert(length<=targetSize-written,'BPS action exceeds output size')
  local bytes
  if kind==0 then
   assert(written+length<=#source,'BPS source read outside input')
   bytes=source:sub(written+1,written+length)
  elseif kind==1 then
   assert(length<=last-at+1,'Truncated BPS literal')
   bytes=patch:sub(at,at+length-1);at=at+length
  else
   local offset=number();local delta=math.floor(offset/2)*(offset%2==1 and -1 or 1)
   if kind==2 then
    sourceAt=sourceAt+delta
    assert(sourceAt>=0 and sourceAt+length<=#source,'BPS source copy outside input')
    bytes=source:sub(sourceAt+1,sourceAt+length);sourceAt=sourceAt+length
   else
    targetAt=targetAt+delta
    assert(targetAt>=0 and targetAt<written,'BPS target copy outside output')
    -- TargetCopy permits overlap: repeat the already-produced seed, without
    -- exposing uninitialised bytes or retaining a table per output byte.
    local seed=produced(targetAt,math.min(length,written-targetAt))
    bytes=seed:rep(math.ceil(length/#seed)):sub(1,length);targetAt=targetAt+length
   end
  end
  out[#out+1]=bytes;starts[#starts+1]=written;written=written+length
  if progress and (written>=nextProgress or written==targetSize) then
   progress(written,targetSize,'apply');nextProgress=written+262144
  end
 end
 assert(at==last+1,'BPS has trailing actions')
 local result=table.concat(out)
 assert(#result==targetSize,'BPS output size mismatch')
 assert(B.crc32(result,progress,'target')==u32(patch,#patch-7),'BPS target checksum mismatch')
 return result
end
return B
