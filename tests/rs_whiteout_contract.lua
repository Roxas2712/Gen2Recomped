love=require('tests.love_stub');love.filesystem.load=loadfile
local R=require('src.import.RomGba');local X=require('src.import.RomExtractorGen3')
local W=require('src.import.Gen3RsWhiteout');local J=require('src.link.Json')
for _,version in ipairs({'ruby','sapphire'})do
 local f=assert(io.open(os.getenv('RS_RECOVERY_'..version:upper()..'_ROM'),'rb'));local raw=f:read('*a');f:close()
 local x=setmetatable({rom=R.new(raw),version=version,manifest={}},X)
 local spec,scripts=W.read(x);assert(W.valid(spec,version,{scripts=scripts}))
 local data={constants={gen3RsWhiteout=spec},map_scripts={source='RomExtractorGen3',scripts=scripts}}
 local game={data=data,stack={states={}}};local V=require('src.core.GameVersion');V.set(version)
 local outcomes={}
 for location=0,3 do
  local flags={UNRELATED_SENTINEL=true}
  for _,id in ipairs({738,739,740,741,742,743,744,881,1245,1246,1247,1248})do flags[('FLAG_G3_%04X'):format(id)]=true end
  game.save={flags=flags,gen3Vars={[16534]=location,[16540]=9},inventory={POKE_BALL=21},money=1000}
  local world={map={id='MAP_G00_N25'},entities={},syncObjectVisibility=function()end}
  assert(W.apply(game,world),'Native reset was not executed')
  assert(flags.UNRELATED_SENTINEL and game.save.inventory.POKE_BALL==21 and game.save.money==1000)
  for _,id in ipairs({1245,1246,1247,1248})do assert(not flags[('FLAG_G3_%04X'):format(id)])end
  assert(game.save.gen3Vars[16540]==0)
  if location==1 then assert(not flags.FLAG_G3_02E6 and not flags.FLAG_G3_02E3)
  elseif location==2 then assert(not flags.FLAG_G3_02E4 and not flags.FLAG_G3_02E7)
  elseif location==3 then assert(not flags.FLAG_G3_02E5 and not flags.FLAG_G3_02E8)end
  outcomes[#outcomes+1]=location
 end
 assert(not W.valid(spec,version,{scripts={}}),'Missing script roots must invalidate the cache')
 print('NATIVE_WHITEOUT_CHECKED',version,#spec.labels,#outcomes)
end
