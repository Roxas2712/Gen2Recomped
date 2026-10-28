-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local original=package.loaded['src.core.Game']
local Q=require('src.compat.gen1.NativeRegionMap')
local FR=require('src.ui.game3.region_map');local RS=require('src.ui.game3.rse.region_map')
local Field=require('src.core.game3.field');local Map=require('src.ui.Gen3RegionMap')
local G=require('src.core.Game3');local V=require('src.core.GameVersion')
local Obs=require('src.compat.gen1.NativeModalObservation')
T.eq(package.loaded['src.core.Game'],original,'queries cannot construct Game')
T.eq(FR.isOpen(),false);T.eq(RS.active(),nil)
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.session-runtime.fixture').new(edition);local game=f.game
 local c=game.data.constants
 c.gen3MapSectionRects={[7]={x=0,y=0,w=1,h=1},[8]={x=1,y=0,w=1,h=1}}
 c.gen3MapSections={[7]='CURRENT',[8]='NEXT'};c.gen3RegionMapPlaces={[7]=true,[8]=true}
 f.map.def.regionMapSection=7
 game.data.maps.NEXT={regionMapSection=8};game.data.field={flyOrder={'TEST','NEXT'},flyWarps={TEST={x=4,y=5},NEXT={x=6,y=7}}}
 game.save.visited={TEST=true}
 local before=require('src.link.Json').encode(game.save)
 local fake=setmetatable({game=game},Map);game.stack:push(fake)
 T.eq(Q.active(),nil,'a class-shaped table has no constructor admission');game.stack:pop()
 local s=Map.new(game,{fly=true});T.eq(Q.active(),nil,'constructor alone is not an open picker')
 game.stack:push(s);local view=assert(Q.active())
 T.eq(view.open,true);T.eq(view.mode,'fly');T.eq(view.mapSecId,7);T.eq(view.state,12)
 T.eq(Q.ready(),true);T.eq(Q.active(),view);T.eq(Q.kind(view,7),2);T.eq(Q.kind(view,8),0)
 local dest=assert(Field.flyDestination(7));T.eq(dest.x,4);T.eq(dest.y,5)
 dest.x=999;T.eq(Field.flyDestination(7).x,4,'destination leaves native warp untouched')
 T.eq(Field.flyDestination(8),nil,'another section is not the current cursor')
 T.raises(function()view.mode='wall'end,'read-only')
 local cursor=view.cursor;cursor.x=999;T.eq(view.cursor.x,s.cx)
 local cover={};game.stack:push(cover);T.eq(Q.active(),view);T.eq(Q.ready(),false,'nested modal owns input');game.stack:pop()
 s.zoomFrame=0;T.eq(Q.ready(),false);s.zoomFrame=Map.ZOOM_FRAMES
 s.cx,s.cy=1,0;T.eq(view.mapSecId,8);T.eq(Q.kind(view,8),0);T.eq(Field.flyDestination(8),nil,'unvisited target is absent')
 T.eq(require('src.link.Json').encode(game.save),before,'queries preserve visits, party and flags')
 for _,key in ipairs{'data','save','mods','stack'}do
  local old=game[key];game[key]={};T.eq(Q.active(),nil);T.eq(view.open,false,key..' replacement retires view');game[key]=old
  local nextView=assert(Q.active());T.neq(view,nextView);view=nextView
 end
 G.release();T.eq(view.open,false);view=assert(Q.active())
 local owned=G._withCallbackOwner('map-owner',Q.active)
 Q._service:releaseOwner('unrelated');T.eq(owned.open,true)
 Q._service:releaseOwner('map-owner');T.eq(owned.open,false);view=assert(Q.active())
 s:close();T.eq(view.open,false);T.eq(Q.active(),nil)
 -- A known off-screen native target is queryable without committing travel.
 T.eq(Field.flyDestination(7).x,4);T.eq(Field.flyDestination(8),nil)
 if V.isFRLG()then
  -- Constructor locates the player's actual page before the FRLG early return.
  c.gen3FRLGRegionMap={sections={kanto={{{7,8}}}},names={[7]='HERE',[8]='NEXT'},none=99}
  local picked;local map=Map.new(game,{fly=true,onFly=function(id)picked=id end});game.stack:push(map)
  T.eq(map.here,7);T.eq(map.playerPage,'kanto');T.eq(FR.isOpen(),true);T.eq(RS.active(),nil)
  T.eq(FR.currentMapSec(),7);T.eq(FR.mode,'fly');T.eq(FR.canFlyToCursor(),true);T.eq(FR.inputReady(),true)
  T.eq(FR.state().selectedRegion,FR.state().playersRegion)
  map.page='sevii123';T.eq(FR.canFlyToCursor(),false);map.page='kanto'
  map:pick();T.eq(picked,'TEST','actual native pick retains its own target identity');T.eq(FR.isOpen(),false)
 else
  local atlas=RS.manifest()
  T.eq(atlas.layout[1][1],7);T.eq(atlas.layout[1][2],8);T.eq(atlas.layout[1][3],false)
  atlas.layout[1][1]=999;T.eq(RS.manifest().layout[1][1],7,'atlas metadata is detached without opening a screen')
  c.gen3RegionMapLayout={width=2,height=1,none=99,cells={8,7}}
  atlas=RS.manifest();T.eq(atlas.layout[1][1],8);T.eq(atlas.layout[1][2],7,'real cell bank wins over rectangle approximations')
  c.gen3RegionMapLayout=nil
  local map=Map.new(game,{fly=true});game.stack:push(map);local live=assert(RS.active())
  T.eq(RS.isOpen(),true)
  T.eq(FR.isOpen(),false);T.eq(live.state,12);T.eq(RS.mapSecType(live,7),RS.TYPE.CITY_CANFLY)
  T.eq(RS.flyWarpDestination(G.forNative(game).session,7).x,4)
  T.eq(RS.flyWarpDestination({},7),nil,'foreign session cannot resolve native destination')
  map:close();T.eq(live.open,false);T.eq(RS.isOpen(),false)
 end
 V.set('crystal');T.eq(Q.active(),nil);T.eq(Field._game,nil);V.set(edition)
 Q._service.release();G.release()
end
-- The actual RS task's phase/cursor/classification is read without advancing it.
local f=require('tools.session-runtime.fixture').new('ruby');local game=f.game
game.data.field={};game.data.maps.TEST.regionMapSection=0
local raw={state=12,mode='fly',inputFn='full',mapSecId=0,posWithinMapSec=1,moveCounter=0}
local calls=0
local rs={state=raw,native={TYPE={CITY_CANFLY=2,BATTLE_FRONTIER=4},mapSecType=function(s,id)
 T.eq(s,raw);T.eq(id,0);return 4 end},destination=function(_,sec,pos)
 calls=calls+1;T.eq(sec,0);T.eq(pos,1);return{map='TEST',x=5,y=6}end}
local s=setmetatable({game=game,fly=true,rsNative=rs},Map);Obs.capture(s,game);game.stack:push(s)
local view=assert(RS.active());T.eq(view.state,12);T.eq(RS.mapSecType(view,0),4)
T.eq(RS.flyWarpDestination(G.forNative(game).session,0,1).y,6)
T.eq(RS.flyWarpDestination(G.forNative(game).session,0,0),nil)
raw.inputFn='move';raw.moveCounter=3;T.eq(Q.ready(),false);T.eq(view.cursor.moveCounter,3)
raw.inputFn='full';raw.state=13;raw.chose=true;T.eq(view.state,13);T.eq(view.chose,true)
T.eq(Q.ready(),false,'exit phase is observed, not advanced or relabelled')
rs.state={};T.eq(view.open,false,'replaced inner native task retires view')
Q._service.release();G.release();package.loaded['src.core.Game']=original;V.set('firered')
T.finish('native region picker admission, cursor/target queries and cohort retirement')
