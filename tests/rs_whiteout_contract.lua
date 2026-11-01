love=require('tests.love_stub');love.filesystem.load=loadfile
local R=require('src.import.RomGba');local X=require('src.import.RomExtractorGen3')
local W=require('src.import.Gen3RsWhiteout');local J=require('src.link.Json')
for _,version in ipairs({'ruby','sapphire','emerald'})do
 local f=assert(io.open(os.getenv('RS_RECOVERY_'..version:upper()..'_ROM'),'rb'));local raw=f:read('*a');f:close()
 local x=setmetatable({rom=R.new(raw),version=version,manifest={}},X)
 local spec,scripts=W.read(x);assert(W.valid(spec,version,{scripts=scripts}))
 local data={constants={gen3RsWhiteout=spec},map_scripts={source='RomExtractorGen3',scripts=scripts}}
 local game={data=data,stack={states={}}};local V=require('src.core.GameVersion');V.set(version)
 local outcomes={}
 for location=0,3 do
  local flags={UNRELATED_SENTINEL=true}
  for _,id in ipairs({738,739,740,741,742,743,744,881,1245,1246,1247,1248,1275,1276,1277,1278})do flags[('FLAG_G3_%04X'):format(id)]=true end
  game.save={flags=flags,gen3Vars={[16534]=location,[16540]=9},inventory={POKE_BALL=21},money=1000}
  local world={map={id='MAP_G00_N25'},entities={},syncObjectVisibility=function()end}
  assert(W.apply(game,world),'Native reset was not executed')
  assert(flags.UNRELATED_SENTINEL and game.save.inventory.POKE_BALL==21 and game.save.money==1000)
  local elite=version=='emerald'and{1275,1276,1277,1278}or{1245,1246,1247,1248}
  for _,id in ipairs(elite)do assert(not flags[('FLAG_G3_%04X'):format(id)])end
  assert(game.save.gen3Vars[16540]==0)
  if location==1 then assert(not flags.FLAG_G3_02E6 and not flags.FLAG_G3_02E3)
  elseif location==2 then assert(not flags.FLAG_G3_02E4 and not flags.FLAG_G3_02E7)
  elseif location==3 then assert(not flags.FLAG_G3_02E5 and not flags.FLAG_G3_02E8)end
  outcomes[#outcomes+1]=location
 end
 if version=='emerald'then
  for _,map in ipairs{'MAP_G16_N10','MAP_G00_N08','MAP_G16_N00','MAP_G16_N01','MAP_G16_N02','MAP_G16_N03','MAP_G16_N04'}do
   game.save={player={map=map},flags={FLAG_G3_04FB=true,UNRELATED_SENTINEL=true},gen3Vars={[16540]=1},inventory={POKE_BALL=21},money=1000}
   local before=J.encode(game.save);local outside=map=='MAP_G16_N10'or map=='MAP_G00_N08'
   assert(W.repairEmeraldLeagueReturn(game)==outside)
   if outside then assert(not game.save.flags.FLAG_G3_04FB and game.save.gen3Vars[16540]==0)
   else assert(J.encode(game.save)==before,'Mid-League SAVE changed')end
   assert(game.save.flags.UNRELATED_SENTINEL and game.save.inventory.POKE_BALL==21 and game.save.money==1000)
  end
  game.save={player={map='MAP_G16_N10'},flags={FLAG_G3_04FB=true},gen3Vars={[16540]=0}}
  assert(not W.repairEmeraldLeagueReturn(game),'Completed/idle League state must remain untouched')
 end
 assert(not W.valid(spec,version,{scripts={}}),'Missing script roots must invalidate the cache')
 print('NATIVE_WHITEOUT_CHECKED',version,#spec.labels,#outcomes)
end
