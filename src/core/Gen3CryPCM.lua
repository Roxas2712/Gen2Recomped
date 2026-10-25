-- Compressed Gen 3 cry recordings. Contributions by Roxas2712.
-- Existing project licences and LICENSE-ROXAS2712.md apply by provenance.
-- The decoder follows SoundMainRAM_Unk2's 64-sample / 33-byte blocks:
-- seed, low nibble, then high/low pairs; STRB wraps rather than saturates.
local C = {}
local delta = {[0]=0,1,4,9,16,25,36,49,-64,-49,-36,-25,-16,-9,-4,-1}
function C.decode(image, offset, size)
  if type(image)~='string' or type(offset)~='number' or offset<0 or offset%1~=0
     or type(size)~='number' or size<1 or size%1~=0 or size>4*1024*1024 then return nil,'invalid sample range' end
  local blocks=math.ceil(size/64)
  if offset+blocks*33>#image then return nil,'truncated compressed sample' end
  local out,remaining={},size
  for block=0,blocks-1 do
    local p=offset+block*33+1
    local acc=image:byte(p);local row={string.char(acc)}
    local function add(nibble)
      acc=(acc+delta[nibble])%256
      row[#row+1]=string.char(acc)
    end
    add(image:byte(p+1)%16)
    for j=2,32 do local b=image:byte(p+j);add(math.floor(b/16));add(b%16) end
    out[#out+1]=table.concat(row):sub(1,math.min(64,remaining));remaining=remaining-64
  end
  return table.concat(out)
end
local function u16(s,p)local a,b=s:byte(p+1,p+2);if b then return a+b*256 end end
local function u32(s,p)local a,b,c,d=s:byte(p+1,p+4);if d then return a+b*256+c*65536+d*16777216 end end
-- handled=false leaves existing file/chip/uncompressed/custom cry paths alone.
-- Recognized but damaged compressed data is silent, never adjacent ROM bytes.
function C.render(image,base,cries,index,options)
  if type(image)~='string' or type(cries)~='table' or type(cries.table)~='number'
     or type(index)~='number' or index<0 or index%1~=0 or index>=(cries.count or 4096) then return nil,false end
  base=base or 0;options=options or {}
  local at=cries.table+index*12-base
  if at<0 or at+12>#image then return nil,false end
  local kind,key=image:byte(at+1,at+2)
  if (kind~=0x20 and kind~=0x30) or key~=60
     or image:sub(at+9,at+12)~=string.char(255,0,255,0) then return nil,false end
  local pointer=u32(image,at+4)
  if not pointer or pointer<0x08000000 or pointer>=0x0A000000 then return nil,true end
  local wave=pointer-0x08000000-base
  if wave<0 or wave+16>#image then return nil,true end
  if u16(image,wave)~=1 then return nil,false end
  local rate=(u32(image,wave+4) or 0)/1024;local size=u32(image,wave+12)
  if rate<=0 or rate>88200 then return nil,true end
  local pcm=C.decode(image,wave+16,size)
  if not pcm then return nil,true end
  local seconds=math.min(5,math.max(.05,options.seconds or size/rate))
  local n=math.floor(44100*seconds)
  local result=love.sound.newSoundData(n,44100,16,2)
  local gain=(options.volume or 1)*.5;local step=rate/44100
  local reverse=kind==0x30
  for i=0,n-1 do
    local position=i*step
    if reverse then position=size-1-position end
    local pos=math.floor(position);local fraction=position-pos
    local b=pos>=0 and pos<size and pcm:byte(pos+1) or 0
    local nextByte=pos>=0 and pos+1<size and pcm:byte(pos+2) or b
    if b>=128 then b=b-256 end
    if nextByte>=128 then nextByte=nextByte-256 end
    -- Same linear reconstruction as the original OASC DirectSound music.
    -- Preserve native rate, output length, gain, pan and Source ownership.
    local v=math.max(-1,math.min(1,(b+(nextByte-b)*fraction)/128*gain))
    result:setSample(i,1,v);result:setSample(i,2,v)
  end
  return result,true,{rate=rate,sourceSamples=size,outputSamples=n,compressed=true,reverse=reverse}
end
return C
