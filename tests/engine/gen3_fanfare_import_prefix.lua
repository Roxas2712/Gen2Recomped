package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local checks=0;local function check(v,why)checks=checks+1;assert(v,why)end
local Cache=require('src.import.CacheFs');local measurements=0
local pairsFromRom={{367,80},{370,160},{371,220},{372,220},{368,160},{369,340},
 {378,180},{387,120},{388,710},{389,250},{390,150},{391,160},{550,450},{530,170},
 {529,196},{459,313},{466,318},{460,135}}
package.loaded['src.core.M4ASynth']={newEngine=function(data,def,options)
 check(data.audio.programPrefix==Cache.prefix,'Import measurements must read the importing cartridge image')
 check(options.allowLoops==false,'Proof must remain finite')
 measurements=measurements+1;local frames=0
 return{finished=function()return frames>=def.duration end,frame=function()frames=frames+1 end}
end}
local X=require('src.import.RomExtractorGen3')
for _,prefix in ipairs({'emerald/','firered/',''})do
 Cache.prefix=prefix;local songs={};local words={}
 for i,row in ipairs(pairsFromRom)do
  words[(i-1)*4]=row[1];words[(i-1)*4+2]=row[2]
  songs['SONG_'..row[1]]={index=row[1],tracks={1},duration=row[2]}
 end
 local audio={gen3={file='assets/generated/audio/m4a.bin',base=0},unrelated='unchanged'}
 local written={};local extractor=setmetatable({rom={size=76,u16=function(_,at)return words[at]or 0 end},
  manifest={},_songs=songs,_audio=audio,_constants={},beginStage=function()end,
  write=function(_,name,value)written[name]=value end},{__index=X})
 extractor:extractFanfares()
 local meta=assert(written.constants and written.constants.gen3Fanfares,'Cold import lost its fanfare table')
 check(meta.count==18 and meta.agreed==18,'All eighteen original table rows must be measured')
 check(written.audio.special.heal=='SONG_170','The original Pokemon Center heal cue must be restored')
 check(written.audio.sfx.Get_Item1.m4a==370 and written.audio.sfx.Get_Key_Item.m4a==530,'Keep native item/key item song identities')
 check(written.audio.programPrefix==nil and written.audio.unrelated=='unchanged','Transient filesystem context must not enter cache data')
 check(Cache.prefix==prefix,'Fanfare proof must not switch the global active cartridge')
end
check(measurements==54,'Every cartridge context must execute all measurements')
print('PASS_GEN3_FANFARE_IMPORT_PREFIX '..checks)
