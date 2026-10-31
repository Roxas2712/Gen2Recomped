-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.import.Gen3FrlgPlayerAssets')
local X=require('src.import.RomExtractorGen3');local Fs=require('src.import.CacheFs')
local Writer=require('src.import.LuaWriter');local J=require('src.link.Json')
local function fixture(version,mode)
 local bytes,words={},{};local pattern=string.char(0,7,1,8,2,9,3,10,4,11,5,12)
 local data=string.rep('x',64)..pattern..string.rep('x',64)
 if mode=='missing'then data=string.rep('x',256)end
 if mode=='ambiguous'then data=data..pattern end
 for id=0,13 do
  local at=1024+id*64;words[512+id*4]=at+0x08000000
  words[at+2]=id<7 and 100 or 200
  words[at+8]=(id==1 or id==8 or id==4 or id==11)and 32 or 16;words[at+10]=32
  bytes[at+12]=(id==2 or id==9)and 128 or 0;bytes[at+13]=(id==1 or id==8)and 2 or 1
 end
 words[1024+12*64+2]=100 -- the original Green VS Seeker row shares Red's palette
 for gender,id in ipairs{3,10}do
  local anims=2048+gender*256;local list=anims+64
  words[1024+id*64+24]=anims+0x08000000;words[anims]=list+0x08000000
  for i=0,4 do words[list+i*4]=i;words[list+i*4+2]=i==4 and 8 or 4 end
  words[list+20]=0xFFFF
  if mode=='bad-animation'then words[list+8]=8 end
  if mode=='bad-duration'then words[list+2]=5 end
  if mode=='bad-end'then words[list+20]=0xFFFE end
 end
 if mode=='bad-bike'then bytes[1024+8*64+13]=1 end
 if mode=='bad-ride'then bytes[1024+9*64+12]=0 end
 if mode=='bad-palette'then words[1024+10*64+2]=100 end
 if mode=='bad-dimensions'then words[1024+2*64+8]=32 end
 local rom={data=data,size=4096}
 function rom:u8(at)return bytes[at]or self.data:byte(at+1)or 0x11 end
 function rom:u16(at)return words[at]or 512 end
 function rom:pointer(at)local n=words[at];return n and n-0x08000000 end
 local file=assert(io.open('tools/rom_manifest_'..version..'.json'));local manifest=J.decode(file:read('*a'));file:close()
 local x=setmetatable({version=version,rom=rom,manifest=manifest,
  symbol=function(_,key)return key=='gObjectEventGraphicsInfoPointers'and 512 or manifest.symbols[key]end,
  layoutValue=function()return 2 end,
  objectGfxPalettes=function()return{[100]={{0,0,0},{120,160,230}},[200]={{0,0,0},{120,160,230}}}end},X)
 return x
end
for _,version in ipairs{'firered','leafgreen'}do
 local x=fixture(version);local record=M.avatars(x)
 T.eq(record.avatarTable,64);T.eq(record.graphicsTable,512);T.eq(record.version,version)
 for key,id in pairs{boy=0,girl=7,boyBike=1,girlBike=8,boySurf=2,girlSurf=9,boyFieldMove=3,girlFieldMove=10}do
  T.eq(record[key],('SPRITE_G3_%03d'):format(id),'FRLG uses its own six-state gender table')
 end
 T.eq(record.boyUnderwater,nil,'the fishing state cannot become Hoenn diving')
 for _,gender in ipairs{'boy','girl','male','female'}do
 T.eq(M.poseDuration(record,gender),24,'the original pose completes before the band starts')
 for age=0,64 do
  T.eq(M.poseFrame(record,gender,age),math.min(4,math.floor(age/4)),'native five-frame timeline holds its last field pose')
 end end
 for _,mode in ipairs{'missing','ambiguous','bad-bike','bad-ride','bad-palette','bad-dimensions','bad-animation','bad-duration','bad-end'}do
  T.raises(function()M.avatars(fixture(version,mode))end)
 end
 local expected=version=='firered'and 0x3A0010 or 0x39FFF0
 T.eq(x:symbol('gFieldEffectObjectTemplatePointers'),expected,'edition-specific original table symbol')
 x.fieldEffectTemplates=function()return{}end
 x.fieldEffectShape=function(_,at,index)
  T.eq(at,expected,'actual surf extractor uses this edition, including LeafGreen')
  return{width=index==7 and 32 or 16,height=32,frames=6,images=3000}
 end
 x.fieldEffectPalettes=function(_,at,count)T.eq(at,expected);T.eq(count,36);return{[100]={ {0,0,0},{120,160,230} }}end
 local pointer=x.rom.pointer;x.rom.pointer=function(self,at)if at==3000 then return 3500 end;return pointer(self,at)end
 local blob=x:surfBlob();T.eq(blob.table,expected);T.eq(blob.index,7);T.eq(blob.frames,6)
 T.eq(blob.paletteSource,'FRLG player OBJ palette slot 0')
 x.objectGfxPalettes=function()return{[100]={{0,0,0},{120,160,230}},[200]={{0,0,0},{230,160,120}}}end
 T.raises(function()x:surfBlob()end,'Native FRLG mount colors disagree')
 local constants={gen3PlayerSprites=record,gen3SurfBlob={frames=6,frameWidth=32,frameHeight=32,
  paletteSource='FRLG player OBJ palette slot 0',image='assets/generated/overworld/g3_surf_blob.png'}}
 local read,exists=Fs.read,Fs.exists
 Fs.read=function()return Writer.encode(constants)end;Fs.exists=function()return true end
 T.eq(#M.missing(version),0)
 constants.gen3PlayerSprites=nil;T.eq(M.missing(version)[1],'<'..version..':native-player-forms-and-surf-mount>')
 constants.gen3PlayerSprites=record;constants.gen3SurfBlob=nil;T.eq(#M.missing(version),1)
 constants.gen3SurfBlob={frames=3,frameWidth=32,frameHeight=32,paletteSource='FRLG player OBJ palette slot 0',image='assets/generated/overworld/g3_surf_blob.png'}
 T.eq(#M.missing(version),1,'Hoenn three-frame blob cannot certify FRLG')
 constants.gen3SurfBlob.frames=6;Fs.exists=function()return false end
 T.eq(M.missing(version)[1],constants.gen3SurfBlob.image,'missing image requires proper reimport')
 Fs.read,Fs.exists=read,exists
end
for _,version in ipairs{'ruby','sapphire','emerald','red','crystal'}do T.eq(#M.missing(version),0)end
T.eq(M.poseFrame(nil,'boy',100),nil,'unimported/other-edition timelines preserve the existing runtime path')
T.eq(M.poseDuration(nil,'boy'),nil)
T.finish('FRLG native gender forms, edition-specific surf extraction and completed-cache admission')
