love=require('tests.love_stub');love.filesystem.load=loadfile
local R=require('src.import.RomGba');local J=require('src.link.Json');local B=require('src.import.Gen3RsBike')
local X=require('src.import.RomExtractorGen3')
for _,v in ipairs({'ruby','sapphire'})do
 local f=assert(io.open(os.getenv('RS_BIKE_'..v:upper()..'_ROM'),'rb'));local raw=f:read('*a');f:close()
 local r=R.new(raw);local c=B.new(v,r);local S=c.S
 local a=S.off('sPlayerAvatarGfxIds');local bytes={}
 for i=0,S.size('sPlayerAvatarGfxIds')-1 do bytes[#bytes+1]=r:u8(a+i)end
 print('AVATARS',v,J.encode(bytes))
 local spec=require('src.import.Gen3RsBikeSprites').read(v,r)
 assert(require('src.import.Gen3RsBikeSprites').valid(spec,v))
 print('SPRITE_ROWS',v,spec.avatars.boy.acro.frameCount,spec.avatars.girl.acro.frameCount,#spec.resources)
 if v=='ruby'then
  local x=setmetatable({rom=r},X)
  for _,name in ipairs({'MovementAction_AcroWheelieFaceDown_Step0','MovementAction_AcroWheelieHopFaceDown_Step0',
   'MovementAction_AcroWheelieMoveDown_Step0','GetAcroWheelieDirectionAnimNum','GetAcroPopWheelieDirectionAnimNum'})do
   if S.hasFunc(name)then
    local at,n=c:func(name);local words={};for i=0,n-2,2 do words[#words+1]=('%04X'):format(r:u16(at+i))end
    print('BIKE_SPRITE_FUNCTION',name,J.encode({words=words,calls=x:blTargets(at,n/2),pool=x:poolWords(at,n/2)}))
   end
  end
  for _,name in ipairs({'gAcroWheelieDirectionAnimNums','gAcroPopWheelieDirectionAnimNums','gAcroEndWheelieDirectionAnimNums',
    'gObjectEventImageAnimTable_AcroBike'})do
   if S.has(name)then
    local at,n=S.off(name),S.size(name);local data={}
    if name:find('AnimTable')then
     for i=0,n/4-1 do
      local p=r:pointer(at+i*4);local seq={}
      for j=0,12 do local word=r:u32(p+j*4);seq[#seq+1]=('%08X'):format(word);if word%65536>=0xFFFD then break end end
      data[i+1]=seq
     end
    else for i=0,n-1 do data[#data+1]=r:u8(at+i)end end
    print('BIKE_SPRITE_TABLE',name,J.encode(data))
   end
  end
 end
end
