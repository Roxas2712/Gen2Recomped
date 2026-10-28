-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Source adapters stay transient while the real native random state resumes.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
local V=require('src.core.GameVersion')
local old=V.get()
local seed,calls=7183,0
love.math.random=function(lo,hi)
 seed=(seed*48271)%2147483647;calls=calls+1
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
 local count=calls
 local loveRng,random,roller=b.battle.rng,b.battle.random,b.battle:roller()
 T.eq(calls,count,'creating every source adapter draws no native randomness')
 b.rng(256);random(255);loveRng(2,5)
 T.eq(calls,count+3,'native and both source domains advance one actual stream')
 local captured=seed
 local checkpoint,why,detail=f.checkpoints:capture(game)
 T.check(checkpoint~=nil,'opaque source adapter caches stay outside checkpoint: '..tostring(why)..' '..tostring(detail))
 if checkpoint then
  roller(256);roller(256)
  local ok,reason=f.checkpoints:restore(game,checkpoint)
  T.check(ok,'actual native random state reconstructs: '..tostring(reason))
  if ok then
   local restored=game.stack:top();local model=restored.battle
   T.neq(restored,b,'checkpoint creates a fresh native controller')
   T.neq(model,b.battle,'checkpoint creates a fresh source model')
   T.neq(model.rng,loveRng,'new controller gets its own source LOVE adapter')
   T.neq(model:roller(),roller,'new controller gets its own source cart adapter')
   T.eq(seed,captured,'the actual native RNG state restores before the next draw')
   local beforeCalls=calls
   local expected=(captured*48271)%2147483647
   T.eq(model.random(256),expected%256,'source random resumes the next real native byte')
   T.eq(calls,beforeCalls+1,'resumed zero-based draw consumes exactly once')
   expected=(expected*48271)%2147483647
   T.eq(model.rng(8,13),8+expected%6,'source LOVE range continues the same restored stream')
   T.eq(calls,beforeCalls+2,'resumed LOVE draw consumes exactly once')
   T.eq(model.player.rng,nil,'no RNG closure is added to restored party mon')
   T.eq(model.player._nativeRoller,nil,'no adapter cache is added to restored party mon')
  end
 end
 require('src.mods.Loader').teardown();f.close()
end
V.set(old)
T.finish('native source model RNG adapters across semantic checkpoint reconstruction')
