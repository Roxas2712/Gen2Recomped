-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Haze must retain native conditions through actual rounds and restore.
local T=require('tests.harness');love=require('tests.love_stub')
local seed=391477
love.math.random=function(a,b)
 seed=(seed*48271)%2147483647
 if not a then return seed/2147483647 end
 if not b then a,b=1,a end
 return a+seed%(b-a+1)
end
love.math.getRandomState=function()return tostring(seed)end
love.math.setRandomState=function(value)seed=assert(tonumber(value))end
love.math.newRandomGenerator=function()return{setState=function(_,value)assert(tonumber(value))end}end
local Fixture=require('tests.checkpoint_fixture');local Native=require('src.battle.BattleState')
local Serializer=require('src.core.SaveSerializer')
local function copy(value)return assert(Serializer.decode(Serializer.encode(value)))end
local function turn(f)
 local battle=f.stack:top();local previous=battle.turnCount or 0
 f.game.input.wasPressed=function()return true end;f.game.input.pressed=f.game.input.wasPressed
 for _=1,2 do
  battle:chooseMenu('fight');battle:chooseMove(1)
  if battle.phase=='targetSelect'then battle:chooseTarget(1)end
  if battle.phase~='menu'then break end
 end
 local ticks=0
 repeat battle:update(1/60);ticks=ticks+1
 until battle.phase=='menu'and not battle.current and #battle.queue==0 or ticks>=4000
 T.check(ticks<4000 and battle.phase=='menu','native Haze round finishes')
 T.check((battle.turnCount or 0)>previous,'native Haze round advances')
 return battle
end
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,double in ipairs({false,true})do
  local f=Fixture.boot(edition,3,'unified');local game=f.game
  game.save.options.battleAnimations=false
  game.data.moves.HAZE_CHECKPOINT={id='HAZE_CHECKPOINT',index=114,name='HAZE',effect='HAZE_EFFECT',gen3Effect=25,type='ICE',power=0,accuracy=100,pp=40,target=64}
  local def=game.data.trainers.OPP_FIX_YOUNGSTER;def.items={};def.doubleBattle=double
  if double then game.save.party[2]=copy(game.save.party[1])end
  local battle=Native.newTrainer(game,'OPP_FIX_YOUNGSTER',1)
  battle.phase,battle.queue,battle.introSlide='menu',{},0;battle:syncSides()
  local stages={}
  for position=0,3 do
   local actor=battle:battlerAt(position)
   if actor then
    stages[position]=actor.stages;actor.stages.attack,actor.stages.defense=2,-2
    actor.mon.stats.hp,actor.mon.stats.defense,actor.mon.stats.spdef=400,400,400
    actor.mon.hp,actor.shownHP=400,400;actor.curStats.speed=actor.isPlayer and 200 or 50
    if actor.isPlayer then
     local moves={{id='HAZE_CHECKPOINT',pp=40}};actor.mon.moves,actor.curMoves=moves,moves
    else actor.mon.status='BRN';actor.focusEnergy,actor.reflect,actor.lightScreen=true,true,true end
   end
  end
  f.stack.states={f.world,battle};turn(f)
  for position,pointer in pairs(stages)do
   local actor=battle:battlerAt(position)
   T.eq(actor.stages,pointer,'real Haze preserves the native stage table')
   T.eq(actor.stages.attack,0,'all active Attack stages reset')
   T.eq(actor.stages.defense,0,'all active Defense stages reset')
   if not actor.isPlayer then
    T.eq(actor.mon.status,'BRN','Haze does not cure native burn')
    T.eq(actor.focusEnergy,true,'Haze does not remove Focus Energy')
    T.eq(actor.reflect,true,'Haze does not remove Reflect')
    T.eq(actor.lightScreen,true,'Haze does not remove Light Screen')
    T.eq(actor.hazeStatReset,nil,'Haze does not lift the native burn penalty')
   end
  end
  local cp,reason=f.checkpoints:capture(game);T.check(cp~=nil,'actual Haze continuation captured '..tostring(reason));assert(cp,reason)
  local expectedBattle=turn(f);local expected=Serializer.encode(assert(f.checkpoints:capture(game)))
  local expectedHP=expectedBattle.enemy.mon.hp
  T.check(f.checkpoints:restore(game,cp),'public Haze continuation restores')
  local fresh=f.stack:top()
  T.eq(fresh.enemy.mon.status,'BRN','restored foe retains native burn')
  T.eq(fresh.enemy.focusEnergy,true,'restored foe retains Focus Energy')
  T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),Serializer.encode(cp),'entire captured Haze state recaptures identically')
  local resumed=turn(f)
  T.eq(resumed.enemy.mon.hp,expectedHP,'restored next round has identical residual HP')
  T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),expected,'complete next Haze checkpoint matches')
  f.close()
 end
end
T.finish('native Haze turns and preserved-state checkpoint continuation')
