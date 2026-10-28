-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local A=require('src.core.game3.battle.anim')
local Battle=require('src.core.game3.battle')
local Clock=require('src.battle.PresentationClock')
local G=require('src.core.Game3')
local Seams=require('src.mods.ModSeams')
local baseAnimation,baseBattle=A.update,Battle.update
local original=package.loaded['src.core.Game']
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local function run(mode)
  A.update=baseAnimation;Battle.update=baseBattle
  local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
  package.loaded['src.core.Game']=game
  local b=f.fresh('TACKLE').battle;b.enter=false;b:syncSides();game.stack:push(b)
  b.phase='messages';b.queue={};b.current=nil;b.waitFrames=0
  local commands,callbacks,age,rolls=0,0,0,0;b.rng=function()rolls=rolls+1;return 1 end
  b:act(function()commands=commands+1 end);b.queue[#b.queue+1]={wait=3};b:act(function()commands=commands+1 end)
  local decorator=function(dt)
   callbacks=callbacks+1;age=age+dt
   T.eq(dt,1/60,'native delta reaches decorations');T.eq(G._callbackOwner(),'qa_animation_owner')
   T.eq(baseAnimation(999),true);T.eq(baseAnimation(-999),true)
   return nil,7,nil
  end
  if mode~='baseline'then
   A.update=decorator
   Seams._journal[#Seams._journal+1]={tbl=A,key='update',after=decorator,owner='qa_animation_owner'}
  end
  if mode=='explicit'then
   Battle.update=function(dt)A.update(dt);return baseBattle(dt)end
   Seams._journal[#Seams._journal+1]={tbl=Battle,key='update',after=Battle.update,owner='qa_animation_owner'}
  end
  local trace={}
  for i=1,12 do
   b:update(1/60)
   trace[i]={frame=b.frame,phase=b.phase,wait=b.waitFrames,queue=#b.queue,commands=commands,
    hp=b.player.mon.hp,shown=b.player.shownHP,enemyHP=b.enemy.mon.hp}
   T.eq(Clock.active(b),false,'the native phase closes after every update')
  end
  if mode~='baseline'then
   T.eq(callbacks,12,'one decoration per native update, including explicit source calls')
   T.check(math.abs(age-12/60)<1e-9,'presentation age follows the actual native delta')
   local frame=b.frame;local cover={};game.stack:push(cover);b:update(1/60)
   T.eq(callbacks,12,'a covered native battle cannot notify decorations');T.eq(b.frame,frame);game.stack:pop()
   -- Failure poisons the phase even if another caller catches the same base
   -- failure. Another native tick is never consumed for a retry.
   A.update=function()error('animation decoration failed')end
   T.raises(function()b:update(1/60)end,'animation decoration failed')
   T.eq(Clock.active(b),false);T.eq(b.frame,frame+(mode=='explicit'and 0 or 1))
   if mode=='explicit'then table.remove(Seams._journal)end
   table.remove(Seams._journal)
  end
  T.eq(rolls,0);A.update=baseAnimation;Battle.update=baseBattle
  game.stack:pop();f.close();A.reset();Battle._service.release();G.release()
  return trace
 end
 local baseline=run('baseline')
 T.same(run('decoration'),baseline,'native commands/HP/timers match the undecorated owner')
 T.same(run('explicit'),baseline,'an explicit source update cannot add another native step')
end
A.update=baseAnimation;Battle.update=baseBattle;package.loaded['src.core.Game']=original
T.finish('native animation update decorators, native delta, once-only holds and failure/coverage fencing')
