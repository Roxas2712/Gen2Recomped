-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local A=require('src.core.game3.battle.anim')
local P=require('src.core.game3.battle.particle_pass')
local Native=require('src.battle.Gen3Battle')
local Battle=require('src.core.game3.battle')
local G=require('src.core.Game3')
local Scope=require('src.render.GraphicsScope')
local Assets=require('src.render.Assets')
local Sprites=require('src.core.game3.battle.anim_sprites')
local image,draw=Assets.image,love.graphics.draw
local original=package.loaded['src.core.Game']
T.eq(A.drawParticles(0,999),false)
T.raises(function()A.drawParticles(0/0,99)end,'finite')
T.eq(A.drawParticles(200,0),false)
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
 package.loaded['src.core.Game']=game
 local gfx={};local events={}
 for _,spec in ipairs{{'rear',3,30},{'back',2,50},{'middle',2,35},{'front',2,20},{'near',1,30}}do
  local tag,priority,sub=spec[1],spec[2],spec[3]
  gfx[tag]={image=tag,frameWidth=16,frameHeight=16,frames=1,held={{0,60}}}
  events[#events+1]={sheet=tag,at=0,explicitLife=32,target=true,priority=priority,subpriority=sub,x=0,y=0}
 end
 game.data.constants.gen3BattleAnimGfx=gfx
 game.data.moves.MOVE_033.anim={duration=40,events=events}
 local b=f.fresh('TACKLE').battle;b.enter=false;game.stack:push(b);b.phase='menu'
 local monImage=love.graphics.newCanvas(64,64)
 b.picImage=function()return monImage end
 b.player.sprite='qa-player';b.enemy.sprite='qa-enemy'
 local images={}
 Assets.image=function(path)
  if not images[path]then local img=love.graphics.newCanvas(16,16);img.tag=path;images[path]=img end
  return images[path]
 end
 local trace={};love.graphics.draw=function(img)table.insert(trace,img.tag or'unknown-image')end
 local anim=assert(b.gen3Anim);T.eq(anim:start('MOVE_033',true,0,1,nil,b),true);b.gen3AnimPlaying=true
 local nativePics=b.drawPicsLayer
 b.drawPicsLayer=function(_,_,_,_,side)table.insert(trace,side)end
 local frame,scriptFrame=b.frame,anim.frame;local hp=b.enemy.mon.hp;local queue=#b.queue
 local rolls=0;b.rng=function()rolls=rolls+1;return 1 end
 T.eq(Native.drawMoveOamObjects(b,0,0,0),true)
 T.same(trace,{'rear','back','enemy','middle','player','front','near'},'native hardware painter establishes the order')
 local expected=trace;trace={}
 local descriptors=anim.oamEventDescriptors;local samples=0
 anim.oamEventDescriptors=function(self,...)samples=samples+1;return descriptors(self,...)end
 local function bands()
  T.eq(A.drawParticles(0,99),true);table.insert(trace,'enemy')
  T.eq(A.drawParticles(101,199),true);table.insert(trace,'player')
  T.eq(A.drawParticles(201,999),true)
 end
 local ok=Scope.call(bands);T.eq(ok,true);T.same(trace,expected);T.eq(samples,1,'three UI bands share one native ordering sample')
 trace={};T.eq(Scope.call(bands),true);T.same(trace,expected);T.eq(samples,2,'a separate capture paints again at the same native frame')
 T.eq(b.frame,frame);T.eq(anim.frame,scriptFrame);T.eq(b.enemy.mon.hp,hp);T.eq(#b.queue,queue);T.eq(rolls,0)
 local middle
 for _,row in ipairs(Sprites.pool())do if row.tag=='middle'then middle=row end end
 T.neq(middle,nil);middle.customDraw=function()table.insert(trace,'custom-middle')end
 trace={};T.eq(Scope.call(bands),true)
 T.same(trace,{'rear','back','enemy','custom-middle','player','front','near'},'source particle decorators keep the native event slot')
 local canvas=love.graphics.newCanvas(80,80);love.graphics.setCanvas(canvas)
 middle.customDraw=function()love.graphics.push('all');love.graphics.setCanvas(monImage);error('native particle decorator failure')end
 T.raises(function()A.drawParticles(101,199)end,'native particle decorator failure')
 T.eq(love.graphics.getCanvas(),canvas,'failed decorators restore the caller target');middle.customDraw=nil
 local save=game.save
 middle.customDraw=function()game.save={};return true end
 local accepted,why=A.drawParticles(101,199);T.eq(accepted,false);T.eq(why,'native particle admission changed')
 game.save=save;Sprites._service.release();P._service.release()
 -- The native copied BG stays below its own OBJ priority and suppresses the
 -- transferred battler through the existing native monbg predicate.
 local drawCopy=b.drawGen3MonBgState
 b.drawGen3MonBgState=function(_,copy)T.eq(copy.battler,b.player);T.eq(copy.bg,2);table.insert(trace,'copy-player')end
 anim.monBgTimeline={{at=0,op='monbg',selector=0}};trace={}
 T.eq(Native.drawMoveOamObjects(b,0,0,0),true)
 T.same(trace,{'rear','copy-player','back','enemy','middle','front','near'})
 trace={};T.eq(Scope.call(function()
  T.eq(A.drawParticles(0,99),true);table.insert(trace,'enemy')
  T.eq(A.drawParticles(101,199),true)
  T.eq(b:gen3AnimMonBgHidden(b.player),true)
  T.eq(A.drawParticles(201,999),true)
 end),true)
 T.same(trace,{'rear','copy-player','back','enemy','middle','front','near'})
 anim.monBgTimeline=nil;b.drawGen3MonBgState=drawCopy;P._service.release()
 -- Exact unknown-key fallback still uses native event order and painter.
 events[3].subpriority=nil;anim.oamRanks={};trace={}
 T.eq(A.drawParticles(0,99),true);T.eq(#trace,0)
 T.eq(A.drawParticles(201,999),true);T.eq(#trace,5);events[3].subpriority=35
 -- Default native doubles retain their established fallback; the explicit
 -- source particle pass can observe all four actual native battler slots.
 local State=require('src.battle.BattleState');local Pokemon=require('src.pokemon.Pokemon')
 for id=2,3 do local mon=Pokemon.new(game.data,'CHARMANDER',30,function(lo)return lo or 0 end)
  b:placeBattler(id,State.makeBattler(game.data,mon,id%2==0,id%2==0 and game.save or nil,b))
  b:battlerAt(id).sprite='qa-slot-'..id
 end
 b.double=true;b:syncSides();P._service.release()
 local accepted,why=Native.drawMoveOamObjects(b,0,0,0);T.eq(accepted,false);T.eq(why,'double-battler-slot')
 local objects=Native.moveOamObjects(b,true);T.check(type(objects)=='table')
 trace={};T.eq(Scope.call(function()
  T.eq(A.drawParticles(0,99),true);table.insert(trace,'enemy-right')
  T.eq(A.drawParticles(101,199),true);table.insert(trace,'enemy-left')
  T.eq(A.drawParticles(201,299),true);table.insert(trace,'player-left')
  T.eq(A.drawParticles(301,399),true);table.insert(trace,'player-right')
  T.eq(A.drawParticles(401,999),true)
 end),true)
 T.same(trace,{'rear','enemy-right','back','enemy-left','middle','player-left','front','player-right','near'})
 b.drawPicsLayer=nativePics;love.graphics.setCanvas();Assets.image=image;love.graphics.draw=draw
 game.stack:pop();T.eq(A.drawParticles(0,999),false)
 Sprites._service.release();P._service.release();A._service.release();Battle._service.release();f.close();G.release()
end
Assets.image=image;love.graphics.draw=draw;package.loaded['src.core.Game']=original
T.finish('native particle order, borrowed painters, capture scope, callbacks, doubles and retirement')
