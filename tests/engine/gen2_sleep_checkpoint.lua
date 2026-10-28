-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
local Status=require('src.battle.Status')
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
 b.player.mon.status,b.player.mon.sleepTurns,b.player.sleepTurns='SLP',4,4
 T.eq(Status.beforeMove(b.player,b.rng,b,{id='FIX_TACKLE'}),false)
 T.eq(b.player.sleepTurns,3);T.eq(b.player.mon.sleepTurns,3)
 local checkpoint,why=f.checkpoints:capture(game)
 T.check(checkpoint~=nil,'actual native sleep counter captures: '..tostring(why))
 if checkpoint then
  b.player.sleepTurns,b.player.mon.sleepTurns=99,99
  local ok,reason=f.checkpoints:restore(game,checkpoint)
  T.check(ok,'semantic checkpoint restores sleep: '..tostring(reason))
  if ok then
   local restored=game.stack:top()
   T.neq(restored,b,'native checkpoint constructs a fresh battle')
   T.eq(restored.player.mon,game.save.party[1],'restored counter belongs to the actual party Pokemon')
   T.eq(restored.player.mon.status,'SLP')
   T.eq(restored.player.sleepTurns,3);T.eq(restored.player.mon.sleepTurns,3)
   for turn=1,3 do
    local allowed=Status.beforeMove(restored.player,restored.rng,restored,{id='FIX_TACKLE'})
    T.eq(allowed,turn==3,'restored native counter ticks exactly once per status attempt')
   end
   T.eq(restored.player.mon.status,nil);T.eq(restored.player.mon.sleepTurns,nil)
   T.eq(b.player.sleepTurns,99,'retired original wrapper does not share the reconstructed counter')
  end
 end
end
V.set(old)
T.finish('native GSC sleep counter across real semantic checkpoint reconstruction')
