-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real semantic reconstruction must not replay the constructor's award.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
local Pokemon=require('src.pokemon.Pokemon')
local V=require('src.core.GameVersion')
local old=V.get()
local seed=7231
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
 game.save.party[2]=Pokemon.new(game.data,'FIXMON_B',15)
 game.save.party[1].happiness,game.save.party[2].happiness=100,199
 game.data.trainers.OWN_RED={id='OWN_RED',index=63,name='RED',baseMoney=10,
  parties={{{level=5,species='FIXMON_C'}}}}
 local b=Native.newTrainer(game,'OWN_RED',1,{playerPartyIndices={2}})
 game.stack.states={f.world,b}
 b.queue,b.current,b.phase,b.afterQueue,b.introSlide={},nil,'menu','menu',0
 T.eq(game.save.party[1].happiness,100,'excluded native mon receives no constructor bonus')
 T.eq(game.save.party[2].happiness,201,'selected mon receives pre-turn Red bonus')
 local captured,why,detail=f.checkpoints:capture(game)
 T.check(captured~=nil,'actual trainer checkpoint captures: '..tostring(why)..' '..tostring(detail))
 if captured then
  game.save.party[2].happiness=17
  local ok,reason=f.checkpoints:restore(game,captured)
  T.check(ok,'actual native trainer checkpoint restores: '..tostring(reason))
  if ok then
   local restored=game.stack:top()
   T.neq(restored,b,'restore constructs a fresh native controller')
   T.eq(game.save.party[1].happiness,100,'excluded native mon remains unchanged')
   T.eq(game.save.party[2].happiness,201,'restore preserves one award without replay')
   T.eq(restored:playerPartyView()[1],game.save.party[2],'restored scope uses actual restored party')
   T.eq(restored.battle.player,game.save.party[2],'source model and native scope share restored mon')
   restored:resumeCheckpoint()
   T.eq(game.save.party[2].happiness,201,'presentation resume cannot award friendship again')
  end
 end
 require('src.mods.Loader').teardown();f.close()
end
V.set(old)
T.finish('native trainer friendship across semantic checkpoint reconstruction')
