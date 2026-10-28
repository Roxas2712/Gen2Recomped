-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Source-facing views are transient; their actual native flags/counters must
-- survive semantic reconstruction without serializing a view/controller.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
local V=require('src.core.GameVersion')
local old=V.get()
local seed=7183
love.math.random=function(lo,hi)
 seed=(seed*48271)%2147483647
 if not lo then return seed/2147483647 end
 if not hi then lo,hi=1,lo end
 return lo+seed%(hi-lo+1)
end
love.math.getRandomState=function()return tostring(seed)end
love.math.setRandomState=function(value)seed=assert(tonumber(value))end
love.math.newRandomGenerator=function()return{setState=function(_,value)assert(tonumber(value))end}end
for _,edition in ipairs{'gold','silver','crystal'}do
 local f=Fixture.boot(edition);local game=f.game
 local b=Native.newWild(game,'FIXMON_B',15);game.stack.states={f.world,b}
 b.queue,b.current,b.phase,b.afterQueue,b.introSlide={},nil,'menu','menu',0
 local view=b.battle:volatile(b.player.mon)
 view.flinched=true;view.confuseCount=3;view.endure=true;view.protectCount=2
 view._consumerMetadata={dispose=function()end}
 local checkpoint,why,detail=f.checkpoints:capture(game)
 T.check(checkpoint~=nil,'native counter/flags capture without opaque view: '..tostring(why)..' '..tostring(detail))
 if checkpoint then
  view.confuseCount=99
  local ok,reason=f.checkpoints:restore(game,checkpoint)
  T.check(ok,'actual semantic state restores: '..tostring(reason))
  if ok then
   local restored=game.stack:top()
   T.neq(restored,b,'restore constructs a fresh native battle')
   T.eq(restored.player.mon,game.save.party[1],'source state keeps actual saved-mon identity')
   local nextView=restored.battle:volatile(restored.player.mon)
   T.check(nextView~=view,'new native owner constructs a new source view')
   T.eq(nextView.confuseCount,3,'actual counter, not the old view snapshot, restores')
   T.eq(nextView.flinched,true,'native flinch restores')
   T.eq(nextView.endure,true,'native Endure restores')
   T.eq(nextView.protectCount,2,'native consecutive-protection counter restores')
   T.eq(nextView._consumerMetadata,nil,'opaque presentation metadata is not serialized')
   T.eq(restored:statusInterrupt(restored.player,restored.enemy,{id='FIX_TACKLE'}),true,'restored source flinch blocks actual native move')
   T.eq(not not nextView.flinched,false,'native admission clears restored source flinch')
   T.eq(nextView.confuseCount,3,'flinch precedes confusion without decrementing it')
   restored:statusInterrupt(restored.player,restored.enemy,{id='FIX_TACKLE'})
   T.eq(nextView.confuseCount,2,'next actual attempt decrements restored counter exactly once')
   T.eq(view.confuseCount,99,'retired original view cannot mutate resumed state')
   T.eq(restored.player.mon.volatile,nil,'no transient source state enters party serialization')
  end
 end
 require('src.mods.Loader').teardown();f.close()
end
V.set(old)
T.finish('native GSC source volatile state across semantic checkpoint reconstruction')
