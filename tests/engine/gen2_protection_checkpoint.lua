-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
local Guard=require('src.battle.Gen2Protection')
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
 b.turnCount=4;Guard.actionStarted(b,b.enemy);b.player.protectRun=2
 local checkpoint,why=f.checkpoints:capture(game)
 T.check(checkpoint~=nil,'native first-action state captures: '..tostring(why))
 if checkpoint then
  local ok,reason=f.checkpoints:restore(game,checkpoint)
  T.check(ok,'actual protection owner reconstructs: '..tostring(reason))
  if ok then
   local restored=game.stack:top()
   T.neq(restored,b,'semantic reconstruction uses a fresh controller')
   T.eq(restored._gen2ProtectionTurn,4,'native first-action round reconstructs')
   T.eq(restored._gen2ProtectionFirst,'enemy','native first side reconstructs')
   local draws=0;restored.rng=function(lo)draws=draws+1;return lo end
   T.eq(Guard.apply(restored,restored.player,'protecting'),false,'resumed second actor still fails')
   T.eq(restored.player.protectRun,0,'resumed failure clears counter')
   T.eq(draws,0,'resumed restriction does not consume RNG')
   restored:beginTurn();Guard.actionStarted(restored,restored.player)
   T.eq(Guard.apply(restored,restored.player,'protecting'),true,'next native round retires prior first side')
   T.eq(draws,1,'next native protection draws exactly once')
  end
 end
 require('src.mods.Loader').teardown();f.close()
end
V.set(old)
T.finish('native GSC protection first-action state across semantic checkpoint reconstruction')
