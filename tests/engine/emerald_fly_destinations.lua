-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');love.filesystem.load=loadfile
local T=require('tests.harness')
local V=require('src.core.GameVersion');V.set('emerald')
local Targets=require('src.world.Gen3FlyTargets')
local Serialize=require('src.core.SaveSerializer')
local city,home='MAP_G00_N08','MAP_G00_N09'
local cells={};for i=1,28*15 do cells[i]=213 end
cells[8*28+28],cells[9*28+28]=15,15
cells[11*28+5]=0
local game={data={maps={[city]={id=city,group=0,number=8,regionMapSection=15},
 [home]={id=home,group=0,number=9,regionMapSection=0}},
 field={flyOrder={city,home},flyWarps={[city]={x=27,y=49},[home]={x=5,y=9}}},
 constants={gen3RegionMapLayout={width=28,height=15,none=213,cells=cells},
  gen3RegionMapGrid={width=28,height=15},
  gen3MapSections={[0]='LITTLEROOT TOWN',[15]='EVER GRANDE CITY'},
  gen3RegionMapPlaces={[0]=true,[15]=true},
  gen3MapSectionRects={[0]={x=4,y=11,w=1,h=1},[15]={x=27,y=8,w=1,h=2}},
  gen3HealLocations={[11]={map=city,x=27,y=49},[20]={map=city,x=18,y=6},
   [12]={map=home,x=5,y=9},[13]={map=home,x=14,y=9}}}},
 save={visited={[city]=true,[home]=true},player={gender='boy'},flags={},options={}}}
local before=Serialize.encode(game.save)
T.eq(Targets.positionWithin(game,15,27,8),0,'actual north atlas cell is the first city position')
T.eq(Targets.positionWithin(game,15,27,9),1,'actual south atlas cell is the second city position')
T.eq(Targets.positionWithin(game,15,26,8),nil,'foreign cell is not a position within this section')
local dest=Targets.destination(game,15,nil,0)
T.eq(dest.x,27,'locked League falls back to original south heal row');T.eq(dest.y,49)
for _,value in ipairs{true,1}do
 game.save.flags.FLAG_G3_08B4=value
 local north=Targets.destination(game,15,nil,0)
 local south=Targets.destination(game,15,nil,1)
 T.eq(north.x,18,'opened League uses its original northern heal coordinates');T.eq(north.y,6)
 T.eq(north.healLocation,20);T.eq(north.nativeEmerald,true)
 T.eq(south.x,27,'southern center stays separately selectable');T.eq(south.y,49)
 T.eq(south.healLocation,11)
 T.eq(Targets.matchesEmeraldHeal(game,city,north),true,'native warp matches the imported heal record')
 north.x=19;T.eq(Targets.matchesEmeraldHeal(game,city,north),false,'changed coordinates cannot masquerade as a native heal row')
 T.eq(game.data.constants.gen3HealLocations[20].x,18,'returned coordinates never alias source rows')
end
game.save.flags.FLAG_G3_08B4=false
T.eq(Targets.destination(game,15,nil,0).y,49,'cleared flag never unlocks the League')
game.save.flags.FLAG_G3_08B4=nil;game.save.flags[0x8B4]=true
T.eq(Targets.destination(game,15,nil,0).y,6,'native numeric flag representation is accepted')
for _,gender in ipairs{'girl','female','F',1}do
 game.save.player.gender=gender
 dest=Targets.destination(game,0,nil,0)
 T.eq(dest.x,14,'female Littleroot selects May outside home');T.eq(dest.healLocation,13)
end
game.save.player.gender='boy'
T.eq(Targets.destination(game,0,nil,0).x,5,'male Littleroot selects Brendan outside home')
-- Existing metadata callers without an actual cursor retain their map-level view.
T.eq(Targets.destination(game,15).y,49,'existing cursor-free destination calls retain their original contract')
local pops,chosen,warp=0
game.stack={pop=function()pops=pops+1 end}
game.overworld={map={def=game.data.maps[city]},player={cellX=18,cellY=6}}
local picker=require('src.ui.Gen3RegionMap').new(game,{fly=true,onFly=function(id,w)chosen,warp=id,w end})
picker.cx,picker.cy=27,8;picker:pick()
T.eq(chosen,city,'actual native picker keeps stable map identity')
T.eq(warp.y,6,'actual native picker forwards the selected League coordinates')
T.eq(pops,1,'one selected destination closes the picker once')
local saved=Serialize.encode(game.save)
for _=1,3 do Targets.positionWithin(game,15,27,9);Targets.destination(game,15,nil,1)end
T.eq(Serialize.encode(game.save),saved,'destination observations never change story flags, visits or player data')
-- Public read-only observations use the same cursor-owned destination.
do
 local f=require('tools.session-runtime.fixture').new('emerald');local g=f.game
 g.data.field=game.data.field;g.data.constants=game.data.constants
 g.data.maps[city],g.data.maps[home]=game.data.maps[city],game.data.maps[home]
 f.map.def.regionMapSection=15
 g.save.visited={[city]=true,[home]=true};g.save.flags.FLAG_G3_08B4=true
 local map=require('src.ui.Gen3RegionMap').new(g,{fly=true});g.stack:push(map)
 map.cx,map.cy=27,8
 local Q=require('src.compat.gen1.NativeRegionMap');T.check(Q.active()~=nil,'real open picker admits read-only observations')
 local old=Serialize.encode(g.save)
 T.eq(Q.destination(15,0).y,6,'source observation reads the actual northern cursor')
 T.eq(Q.destination(15,1),nil,'another cursor position cannot be substituted')
 T.eq(require('src.core.game3.field').flyDestination(15).y,6,'field facade agrees with the actual picker')
 map.cy=9;T.eq(Q.destination(15,1).y,49,'source observation follows the actual southern cell')
 T.eq(Q.destination(15,0),nil,'stale northern observation is refused')
 T.eq(Serialize.encode(g.save),old,'public observations leave native SAVE unchanged')
 g.stack:pop();Q._service.release();require('src.core.Game3').release()
end
for _,version in ipairs{'ruby','sapphire','firered','leafgreen'}do
 V.set(version);T.eq(Targets.destination(game,15,nil,0).y,49,'other edition adapters keep their existing destination owner')
end
V.set('emerald')
game.save.flags={};game.save.player.gender='boy'
T.eq(Serialize.encode(game.save),before,'authored scenario restores its initial save exactly')
T.finish('Emerald Fly native cursor, League/home heal records and real picker handoff')
