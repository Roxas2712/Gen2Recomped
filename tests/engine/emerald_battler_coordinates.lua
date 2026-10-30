-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local X=require('src.import.RomExtractorGen3')
local W=require('src.import.LuaWriter')
local Fs=require('src.import.CacheFs')
local Assets=require('src.import.Gen3NativeHealthboxAssets')
-- Independent facts from pokeemerald's front/back_pic_coordinates.h.
local front=string.char(0x88,0,0,0,0x45,14,0,0,0x56,10,0,0,0x88,3,0,0)
local back=string.char(0x88,0,0,0,0x64,16,0,0,0x66,9,0,0,0x87,7,0,0)
local function fixture(mode)
 local bytes={};for i=1,4096 do bytes[i]=0xEE end
 local function put(at,s)for i=1,#s do bytes[at+i]=s:byte(i)end end
 put(128,front);put(1024,back)
 for index,row in pairs({[9]={0x88,0,0x86,8},[84]={0x57,5,0x66,8},[143]={0x87,5,0x86,11}})do
  put(128+index*4,string.char(row[1],row[2],0,0))
  put(1024+index*4,string.char(row[3],row[4],0,0))
 end
 if mode=='duplicate-front'then put(2500,front)end
 if mode=='missing-back'then put(1024,string.rep('x',16))end
 local chunks={};for i=1,#bytes do chunks[i]=string.char(bytes[i])end
 local rom={data=table.concat(chunks)}
 function rom:u8(at)return self.data:byte(at+1)end
 function rom:s8(at)local n=self:u8(at);return n>=128 and n-256 or n end
 local x=setmetatable({version='emerald',manifest={},rom=rom,
  _pokemon={BLASTOISE={index=9},DODUO={index=84},SNORLAX={index=143}},
  _constants={sentinel=true},beginStage=function()end,
  need=function()return 3500 end,
  symbol=function(_,key)return key=='gMonFrontPicCoords'and 1024 or nil end,
  write=function(self,key,value)self.written=self.written or{};self.written[key]=value end},{__index=X})
 x:extractDexEntries();return x
end
local x=fixture()
for species,row in pairs({BLASTOISE={0,8},DODUO={5,8},SNORLAX={5,11}})do
 local d=x._pokemon[species]
 T.eq(d.frontPicCoords.yOffset,row[1],'actual extractor reads original front offset')
 T.eq(d.backPicCoords.yOffset,row[2],'actual extractor reads the separate back offset')
 T.eq(d.picCoords.yOffset,row[2],'legacy metadata stays unchanged for existing consumers')
end
T.eq(x.written.pokemon,x._pokemon);T.eq(x.written.constants,x._constants)
T.same(x._constants.gen3BattlerFrames,{format=1,version='emerald',frontTable=128,backTable=1024})
T.eq(x._constants.sentinel,true)
for _,mode in ipairs{'duplicate-front','missing-back'}do
 local bad=fixture(mode)
 T.eq(bad._constants.gen3BattlerFrames,nil,'incomplete/ambiguous tables cannot certify a ready cache')
 if mode=='duplicate-front'then T.eq(bad._pokemon.SNORLAX.frontPicCoords,nil)
 else T.eq(bad._pokemon.SNORLAX.backPicCoords,nil)end
end
local read,exists,valid=Fs.read,Fs.exists,Assets.valid
local constants={gen3BattleHud={native={}}}
Fs.read=function()return W.encode(constants)end;Fs.exists=function()return true end
Assets.valid=function()return true end
T.eq(Assets.missing('emerald')[1],'<emerald:native-front-back-coordinates>',
 'old completed imports require their missing native coordinates once')
constants.gen3BattlerFrames=x._constants.gen3BattlerFrames
T.eq(#Assets.missing('emerald'),0,'fresh separate tables satisfy readiness')
constants.gen3BattlerFrames.backTable=128
T.eq(Assets.missing('emerald')[1],'<emerald:native-front-back-coordinates>',
 'the old back-as-front label cannot certify both tables')
Fs.read,Fs.exists,Assets.valid=read,exists,valid
T.finish('Actual Emerald front/back coordinate extraction and completed-cache readiness')
