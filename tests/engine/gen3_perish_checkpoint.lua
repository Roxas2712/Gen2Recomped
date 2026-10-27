-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real menu rounds and public cold checkpoints, including the live zero turn.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness');love=require('tests.love_stub')
local seed=814733
love.math.random=function(a,b)
 seed=(seed*48271)%2147483647;if not a then return seed/2147483647 end
 if not b then a,b=1,a end;return a+seed%(b-a+1)
end
love.math.getRandomState=function()return tostring(seed)end
love.math.setRandomState=function(value)seed=assert(tonumber(value))end
love.math.newRandomGenerator=function()return{setState=function(_,value)assert(tonumber(value))end}end
local F=require('tests.checkpoint_fixture');local Native=require('src.battle.BattleState')
local Serializer=require('src.core.SaveSerializer')
local function copy(value)return assert(Serializer.decode(Serializer.encode(value)))end
local function drain(f,b,previous)
 local ticks=0
 repeat b:update(1/60);ticks=ticks+1
 until b.phase=='menu'and not b.current and #b.queue==0 or ticks>=6000
 T.check(ticks<6000 and b.phase=='menu','actual Perish round returns to its menu')
 T.check((b.turnCount or 0)>previous,'actual Perish round advances')
 return b
end
local function turn(f,escape)
 local b=f.stack:top();local previous=b.turnCount or 0
 f.game.input.wasPressed=function()return true end;f.game.input.pressed=f.game.input.wasPressed
 if escape then
  b:chooseAction({special='playerSwitch',mon=f.game.save.party[3]})
  if b:isDouble()then b:chooseAction({special='playerSwitch',mon=f.game.save.party[4]})end
 else
  for _=1,2 do
   b:chooseMenu('fight');b:chooseMove(1)
   if b.phase=='targetSelect'then b:chooseTarget(1)end
   if b.phase~='menu'then break end
  end
 end
 return drain(f,b,previous)
end
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,double in ipairs({false,true})do
  for _,escape in ipairs({false,true})do
   local f=F.boot(edition,3,'unified');local game=f.game
   game.save.options.battleAnimations=false;game.save.options.battleStyle='set'
   game.data.moves.PERISH_CHECKPOINT={id='PERISH_CHECKPOINT',index=195,name='PERISH SONG',effect='PERISH_SONG_EFFECT',gen3Effect=114,type='NORMAL',power=0,accuracy=0,pp=40,target=16,flags=0}
   game.data.moves.SPLASH_CHECKPOINT={id='SPLASH_CHECKPOINT',index=150,name='SPLASH',effect='SPLASH_EFFECT',gen3Effect=85,type='NORMAL',power=0,accuracy=0,pp=40,target=16,flags=0}
   local def=game.data.trainers.OPP_FIX_YOUNGSTER;def.items={};def.doubleBattle=double
   local first=copy(def.parties[1][1]);def.parties[1]={copy(first),copy(first),copy(first),copy(first)}
   local player=game.save.party[1];for i=2,4 do game.save.party[i]=copy(player)end
   local b=Native.newTrainer(game,'OPP_FIX_YOUNGSTER',1)
   b.phase,b.queue,b.introSlide='menu',{},0;b:syncSides()
   for _,party in ipairs({game.save.party,b.enemyParty})do
    for _,mon in ipairs(party)do mon.stats.hp,mon.stats.defense,mon.stats.spdef=400,400,400;mon.hp=400 end
   end
   for pos=0,3 do
    local actor=b:battlerAt(pos)
    if actor then
     actor.shownHP=400;actor.curStats.speed=actor.isPlayer and 200+pos or 50+pos
     actor.abilityOverride=not escape and actor.isPlayer and'SOUNDPROOF'or false
     local moves={{id=actor.isPlayer and'PERISH_CHECKPOINT'or'SPLASH_CHECKPOINT',pp=40}}
     actor.mon.moves,actor.curMoves=moves,moves
    end
   end
   local zeroRequests=0
   f.loaded.loader.exports.checkpoint_fixture.api.hooks:wrap('battle.enemy_switch_or_item',function(_,current)
    if current.enemy and current.enemy.perishTurns==0 then
     zeroRequests=zeroRequests+1
     if escape then
      local pending=current.monToSwitchInto or{}
      local chosen=(pending[1]==3 or pending[3]==3)and 4 or 3
      return{kind='switch',slot=chosen}
     end
    end
    return false
   end)
   f.stack.states={f.world,b}
   local function counters(expected)
    local current=f.stack:top()
    for _,actor in current:activeBattlers()do
     if not escape and actor.isPlayer then T.eq(actor.perishTurns,nil,'Soundproof remains outside the countdown')
     else T.eq(actor.perishTurns,expected,'real round exposes the native Perish counter')end
     T.check(actor.mon.hp>0,'zero countdown still has a living native actor')
    end
   end
   turn(f);counters(2);turn(f);counters(1)
   local before,why=f.checkpoints:capture(game);T.check(before~=nil,'Perish continuation captured '..tostring(why));assert(before,why)
   local bytesBefore=Serializer.encode(before)
   turn(f);counters(0)
   local zero,reason=f.checkpoints:capture(game);T.check(zero~=nil,'live zero captured '..tostring(reason));assert(zero,reason)
   local zeroBytes=Serializer.encode(zero)
   T.check(f.checkpoints:restore(game,before),'public restore returns to before the zero window')
   counters(1);turn(f);counters(0)
   T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),zeroBytes,'complete next zero checkpoint matches')
   T.eq(Serializer.encode(before),bytesBefore,'caller checkpoint remains detached')
   local function afterZero()
    local current=f.stack:top();local old={}
    for pos=0,3 do local actor=current:battlerAt(pos);if actor then old[pos]=actor end end
    local requests=zeroRequests
    turn(f,escape)
    current=f.stack:top()
    T.eq(zeroRequests-requests,double and 2 or 1,'actual enemy controller sees a living zero-turn window')
    for pos,previous in pairs(old)do
     local fresh=current:battlerAt(pos)
     if escape then
      T.neq(fresh,previous,'real queued action switches every requested position')
      T.eq(previous.mon.hp,400,'switch prevents the Perish faint')
     elseif not previous.isPlayer then
      T.eq(previous.mon.hp,0,'next actual round expires the zero counter')
      T.neq(fresh,previous,'native faint processing sends in a reserve')
     else T.eq(fresh,previous,'Soundproof player remains on the field')end
     T.check(fresh and fresh.mon.hp>0,'native round finishes with a living controller')
     T.eq(fresh and fresh.perishTurns,nil,'ordinary switch/expiry does not spread Perish to reserves')
    end
    return Serializer.encode(assert(f.checkpoints:capture(game)))
   end
   local expected=afterZero()
   T.check(f.checkpoints:restore(game,zero),'public restore preserves the exact live zero decision')
   counters(0)
   T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),zeroBytes,'full zero checkpoint recaptures identically')
   T.eq(afterZero(),expected,'complete switch/expiry continuation matches after cold reconstruction')
   f.close()
  end
 end
end
T.finish('native Perish rounds, live zero switching/expiry and cold checkpoint continuation')
