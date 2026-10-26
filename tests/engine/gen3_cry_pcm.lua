-- Independent GFDPCM block, render and owned-cartridge oracle checks.
local C=require('src.core.Gen3CryPCM')
local seed=string.char(127,0xF1)..string.rep(string.char(0x12),31)
local p=assert(C.decode(seed,0,64));assert(#p==64 and p:byte(1)==127 and p:byte(2)==128 and p:byte(3)==129 and p:byte(4)==133)
assert(C.decode(seed:sub(1,32),0,64)==nil)
assert(C.decode(seed,0,65)==nil and C.decode(seed,-1,1)==nil)
local two=assert(C.decode(seed..string.char(99)..string.rep('\0',32),0,65));assert(two:byte(65)==99)
local rawBefore=love
love={sound={newSoundData=function(n,rate,bits,channels)
 local d={n=n,rate=rate,bits=bits,channels=channels,values={}}
 function d:setSample(i,c,v)self.values[i*2+c]=v end
 return d
end}}
local function u32(v)return string.char(v%256,math.floor(v/256)%256,math.floor(v/65536)%256,math.floor(v/16777216)%256)end
local record=string.char(32,60,0,0)..u32(0x08000010)..string.char(255,0,255,0)
local image=record..string.rep('\0',4)..string.char(1,0,0,0)..u32(44100*1024)..u32(0)..u32(64)..seed
local sd,handled=C.render(image,0,{table=0,count=1},0)
assert(handled and sd.n==64 and sd.rate==44100 and sd.channels==2)
for i=0,63 do local b=p:byte(i+1);if b>=128 then b=b-256 end;assert(sd.values[i*2+1]==b/128*(94/256) and sd.values[i*2+2]==b/128*(96/256))end
assert(sd.values[129]==nil and sd.values[130]==nil,'Read past decoded cry')
assert(select(2,C.render(image,0,{table=0,count=1},1))==false)
assert(select(2,C.render(image:sub(1,-2),0,{table=0,count=1},0))==true)
local rev=string.char(48)..image:sub(2);local rd=C.render(rev,0,{table=0,count=1},0);local b=p:byte(64);if b>=128 then b=b-256 end;assert(rd.values[1]==b/128*(94/256))
local ordinary=image:sub(1,16)..'\0\0'..image:sub(19);assert(select(2,C.render(ordinary,0,{table=0,count=1},0))==false)
if arg[1]then
 local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
 local rom,tableAt,oracle=read(arg[1]),assert(tonumber(arg[2])),read(arg[3]);local cursor=1
 local function nextInt()local a,b,c,d=oracle:byte(cursor,cursor+3);cursor=cursor+4;return a+b*256+c*65536+d*16777216 end
 local function word(at)local a,b,c,d=rom:byte(at+1,at+4);return a+b*256+c*65536+d*16777216 end
 local count=nextInt();assert(count==388)
 -- Optional private original engine decoder; not shipped with native tests.
 local original=arg[4]and assert(loadfile(arg[4]))()
 package.loaded['src.core.WorkerFs']={read=function()return rom end}
 local M=require('src.core.M4ASynth');assert(M.cryPCMVersion==1)
 for i=0,count-1 do
  local size=nextInt();local expected=oracle:sub(cursor,cursor+size-1);cursor=cursor+size
  local at=word(tableAt+i*12+4)-0x08000000;assert(word(at+12)==size)
  assert(C.decode(rom,at+16,size)==expected,'Native sample mismatch '..i)
  if original then assert(original.decodeGfdpcm(rom:sub(at+17,at+16+math.ceil(size/64)*33),size)==expected,'Original decoder mismatch '..i)end
  if i==0 or i==3 or i==6 or i==24 or i==251 or i==280 or i==311 then
   local data={audio={gen3={file='owned-ROM',base=0},gen3Cries={table=tableAt,count=count}}}
   local out=assert(M.renderCry(data,i));local step=word(at+4)/1024/44100
   assert(out.n==math.ceil(size/step))
   for j=0,out.n-1 do
    local position=j*step;local pos=math.floor(position);local v=pos<size and expected:byte(pos+1)or 0;local v2=pos+1<size and expected:byte(pos+2)or v
    if v>=128 then v=v-256 end;if v2>=128 then v2=v2-256 end
    local value=(v+(v2-v)*(position-pos))/128
    assert(out.values[j*2+1]==value*(94/256) and out.values[j*2+2]==value*(96/256),'Rendered PCM mismatch '..i..':'..j)
   end
  end
 end
 assert(cursor==#oracle+1);print('PASS_OWNED_CRY_ORACLE',count,'all decoded bytes, seven real native renderer cases')
end
love=rawBefore
print('PASS_GEN3_CRY_PCM low-first, byte wrap, block restart, partial block, truncation, stereo, bounds, reverse, raw fallback')
