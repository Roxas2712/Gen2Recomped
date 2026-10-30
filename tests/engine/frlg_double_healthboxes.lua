-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local G=require('src.battle.Gen3Battle')
local H=require('src.battle.Gen3NativeHealthbox')
local V=require('src.core.GameVersion')
local S=require('src.core.SaveSerializer')
-- Independent FRLG InitBattlerHealthboxCoords facts, including its player
-- rows one pixel above Emerald's. Values here are sprite centres.
local centres={[0]={159,75},[1]={44,19},[2]={171,100},[3]={32,44}}
local oldCenter,oldSource=H.center,package.loaded['src.core.game3.battle.healthbox']
local painted={}
package.loaded['src.core.game3.battle.healthbox']={_nativeDraw=function(b,a,x,y,player)
 painted[#painted+1]={id=a.position,x=x,y=y,player=player};return true
end}
H.center=function(_,id)local p=centres[id];return p[1],p[2]end
local actors={}
for id=0,3 do actors[id]={position=id,isPlayer=id%2==0,mon={hp=20},shownHP=20}end
local b={data={constants={gen3BattlerCoords={singles={},doubles={}}}},
 player=actors[0],enemy=actors[1],frame=0,
 isDouble=function()return true end,battlerAt=function(_,id)return actors[id]end,
 growInScale=function()return nil end,gen3SurfaceWidth=function()return 240 end}
for _,edition in ipairs{'firered','leafgreen'}do
 V.set(edition);local before=S.encode(b.data)
 for _,width in ipairs{240,320}do
  b.gen3SurfaceWidth=function()return width end
  painted={};G.drawHUDs(b,0)
  T.eq(#painted,4,'actual HUD dispatch paints all four without optional imported healthbox rows')
  for _,p in ipairs(painted)do
   local native=centres[p.id]
   T.eq(p.x,native[1]-32+(p.player and width-240 or 0),'right edge shifts exactly once')
   T.eq(p.y,native[2]-16,'native Kanto vertical placement')
   local x,y=G.healthboxGeometry(b,p.id);T.eq(x,p.x);T.eq(y,p.y,'observer and painter agree')
  end
 end
 T.eq(S.encode(b.data),before,'fallback never rewrites imported metadata')
 b.showPlayerBack=true;painted={};G.drawHUDs(b,0);T.eq(#painted,2,'unsent player pair stays hidden')
 b.showEnemyTrainer=true;painted={};G.drawHUDs(b,0);T.eq(#painted,0,'trainer intro owns the space')
 b.showPlayerBack,b.showEnemyTrainer=nil,nil
 b.statusHUDVisible=function()return false end;painted={};G.drawHUDs(b,0);T.eq(#painted,0,'explicit visibility hook remains authoritative')
 b.statusHUDVisible=nil
end
b.data.constants.gen3BattlerCoords.healthbox={playerLeft={x=188,y=88}}
local x,y=G.healthboxGeometry(b,0);T.eq(x,236);T.eq(y,72,'explicit imported centres precede the fallback')
H.center=oldCenter;package.loaded['src.core.game3.battle.healthbox']=oldSource
T.finish('Actual FRLG double healthbox dispatch, native fallback, visibility and geometry ownership')
