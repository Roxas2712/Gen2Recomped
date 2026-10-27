-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local P=require('src.core.game3.battle.pic_coords')
local C=require('src.core.game3.battle.anim_coords')
local G=require('src.core.Game3')
local Version=require('src.core.GameVersion')
local previous=package.loaded['src.core.Game']
local function point(p,x,y)
 T.eq(p.x,x);T.eq(p.y,y);T.eq(p[1],x);T.eq(p[2],y)
end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition)
 package.loaded['src.core.Game']=f.game
 local b=f.fresh('TACKLE').battle;b.enter=false;f.game.stack:push(b)
 local constants=f.data.constants
 local defaultsSingle={{72,80},{176,40},{48,40},{112,80}}
 local defaultsDouble={{32,80},{200,40},{90,88},{152,32}}
 for i=0,3 do
  point(P.battlerCoords(false,i),unpack(defaultsSingle[i+1]))
  point(P.battlerCoords(true,i),unpack(defaultsDouble[i+1]))
 end
 point(P.battlerCoords(),72,80)
 point(P.battlerCoords(false,'1'),176,40)
 local rows={singles={},doubles={}}
 for i=1,4 do rows.singles[i]={x=i*13,y=i*17};rows.doubles[i]={i*19,i*23}end
 constants.gen3BattlerCoords=rows
 local frame,queue=b.frame,#b.queue
 local hp,ap=b.player.mon.hp,b.player.mon.moves[1].pp
 local rolls=0;b.rng=function()rolls=rolls+1;return 0 end
 C.setDouble(true);C.setCoordinateOverrides({[0]={x=999,y=998}})
 for _=1,3 do for i=0,3 do
  point(P.battlerCoords(false,i),(i+1)*13,(i+1)*17)
  point(P.battlerCoords(true,i),(i+1)*19,(i+1)*23)
 end end
 local held=P.battlerCoords(false,0);held.x,held[1]=500,501
 point(P.battlerCoords(false,0),13,17)
 point(C.coords(nil,0),999,998)
 rows.singles[1].x=31;point(P.battlerCoords(false,0),31,17)
 constants.gen3BattlerCoords={singles={{x=7,y=9}}}
 point(P.battlerCoords(false,0),7,9)
 point(P.battlerCoords(true,0),32,80)
 for _,id in ipairs{-1,4,1.5,'invalid',math.huge,-math.huge}do
  local value,why=P.battlerCoords(false,id);T.eq(value,nil);T.check(type(why)=='string')
 end
 T.eq(P.battlerCoords(false,0/0),nil)
 T.eq(P.battlerCoords('double',0),nil)
 for _,bad in ipairs{{x=math.huge,y=2},{x=2,y=0/0},{x='3',y=2},{}}do
  constants.gen3BattlerCoords.singles[1]=bad
  local value,why=P.battlerCoords(false,0);T.eq(value,nil);T.eq(why,'invalid native battler coordinates')
 end
 T.eq(b.frame,frame);T.eq(#b.queue,queue);T.eq(rolls,0)
 T.eq(b.player.mon.hp,hp);T.eq(b.player.mon.moves[1].pp,ap)
 C._service.release();f.game.stack:pop();f.close();G.release()
 -- Existing detached points survive retirement as plain values, and cannot
 -- retain the previous game's native objects or affect a replacement owner.
 T.eq(held.y,17)
 local nextGame={data={constants={gen3BattlerCoords={singles={{x=61,y=63}}}}}}
 package.loaded['src.core.Game']=nextGame
 point(P.battlerCoords(false,0),61,63)
 Version.set('gold');T.eq(P.battlerCoords(false,0),nil)
end
package.loaded['src.core.Game']=previous
T.finish('native base battler coordinates, current cartridge records and render-override isolation')
