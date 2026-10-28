-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Complete menu rounds produce history, then public checkpoints resume it.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness');love=require('tests.love_stub')
local seed=718834
love.math.random=function(a,b)
 seed=(seed*48271)%2147483647;if not a then return seed/2147483647 end
 if not b then a,b=1,a end;return a+seed%(b-a+1)
end
love.math.getRandomState=function()return tostring(seed)end
love.math.setRandomState=function(value)seed=assert(tonumber(value))end
love.math.newRandomGenerator=function()return{setState=function(_,value)assert(tonumber(value))end}end
local F=require('tests.checkpoint_fixture');local Native=require('src.battle.BattleState')
local Serializer=require('src.core.SaveSerializer')
local function copy(v)return assert(Serializer.decode(Serializer.encode(v)))end
local function field(graph,ref,key)
 for _,entry in ipairs(graph.nodes[assert(ref.node)].entries)do if entry.key==key then return entry end end
 error('missing history checkpoint field '..tostring(key))
end
local function moves(actor,id)local rows={{id=id,pp=40}};actor.mon.moves,actor.curMoves=rows,rows end
local function turn(f,switch)
 local b=f.stack:top();local previous=b.turnCount or 0
 f.game.input.wasPressed=function()return true end;f.game.input.pressed=f.game.input.wasPressed
 if switch then
  b:chooseAction({special='playerSwitch',mon=f.game.save.party[3]})
  if b:isDouble()then b:chooseAction({special='playerSwitch',mon=f.game.save.party[4]})end
 else
  for _=1,2 do
   b:chooseMenu('fight');b:chooseMove(1)
   if b.phase=='targetSelect'then b:chooseTarget(1)end
   if b.phase~='menu'then break end
  end
 end
 local ticks=0
 repeat b:update(1/60);ticks=ticks+1
 until b.phase=='menu'and not b.current and #b.queue==0 or ticks>=6000
 T.check(ticks<6000 and b.phase=='menu','actual history round finishes')
 T.check((b.turnCount or 0)>previous,'actual history round advances');return b
end
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,double in ipairs({false,true})do
  local f=F.boot(edition,3,'unified');local game=f.game
  game.save.options.battleAnimations=false;game.save.options.battleStyle='set'
  game.data.moves.FIXED_HIT={id='FIXED_HIT',index=82,name='DRAGON RAGE',effect='SPECIAL_DAMAGE_EFFECT',gen3Effect=41,type='NORMAL',power=1,accuracy=100,pp=40,target=0,flags=51}
  game.data.moves.FIXED_MISS={id='FIXED_MISS',index=201,name='MISS',effect='NO_ADDITIONAL_EFFECT',gen3Effect=0,type='NORMAL',power=35,accuracy=0,pp=40,target=0,flags=51}
  local def=game.data.trainers.OPP_FIX_YOUNGSTER;def.items={};def.doubleBattle=double
  local first=copy(def.parties[1][1]);def.parties[1]={copy(first),copy(first),copy(first),copy(first)}
  local player=game.save.party[1];for i=2,4 do game.save.party[i]=copy(player)end
  local b=Native.newTrainer(game,'OPP_FIX_YOUNGSTER',1);b.phase,b.queue,b.introSlide='menu',{},0;b:syncSides()
  for _,party in ipairs({game.save.party,b.enemyParty})do
   for _,mon in ipairs(party)do mon.stats.hp,mon.stats.defense,mon.stats.spdef,mon.hp=400,400,400,400 end
  end
  for pos=0,3 do local actor=b:battlerAt(pos);if actor then
   actor.shownHP=400;actor.curStats.speed=actor.isPlayer and 200+pos or 50+pos;actor.abilityOverride=false;moves(actor,'FIXED_HIT')
  end end
  f.loaded.loader.exports.checkpoint_fixture.api.hooks:wrap('battle.enemy_switch_or_item',function(_,current)
   if(current.turnCount or 0)>=2 then
    local pending=current.monToSwitchInto or{};return{kind='switch',slot=(pending[1]==3 or pending[3]==3)and 4 or 3}
   end
   return false
  end)
  f.stack.states={f.world,b};turn(f)
  T.eq(b.enemy.expLastLandedMove,82,'actual complete round produces native landed history')
  T.eq(b.enemy.expLastHitById,0,'numeric zero attacker survives actual native round')
  for _,actor in b:activeBattlers()do moves(actor,'FIXED_MISS')end
  local cp,why=f.checkpoints:capture(game);T.check(cp~=nil,'history capture '..tostring(why));assert(cp,why)
  local original=Serializer.encode(cp)
  for _,key in ipairs({'expLastLandedMove','expLastHitByType','expLastHitById'})do
   for _,invalid in ipairs({false,'0',-1,0.5,key=='expLastHitById'and 4 or key=='expLastHitByType'and 256 or 65536})do
    local bad=copy(cp);local graph=bad.runtime.battle.graph
    local actor=field(graph,graph.root,'enemy').value
    field(graph,actor,key).value={scalar=invalid}
    local save,top=game.save,f.stack:top();local ok,reason=f.checkpoints:restore(game,bad)
    T.eq(ok,false,'invalid history rejected in preflight');T.eq(reason,'invalid_battle_state','history preflight reason')
    T.eq(game.save,save,'rejection preserves save');T.eq(f.stack:top(),top,'rejection preserves live controller')
   end
  end
  local function continuation()
   local current=turn(f)
   T.eq(current.enemy.expLastLandedMove,82,'failed complete round retains last landed hit')
   local failed=Serializer.encode(assert(f.checkpoints:capture(game)))
   current=turn(f,true)
   for _,actor in current:activeBattlers()do
    T.eq(actor.expLastLandedMove,nil,'ordinary incoming actor starts without landed history')
    T.eq(actor.expLastHitByType,nil,'ordinary incoming actor starts without type history')
    T.eq(actor.expLastHitById,nil,'ordinary incoming actor starts without HP attacker')
   end
   return {failed,Serializer.encode(assert(f.checkpoints:capture(game)))}
  end
  local expected=continuation()
  T.check(f.checkpoints:restore(game,cp),'public cold restore accepts produced history')
  T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),original,'complete cold checkpoint recaptures identically')
  local resumed=continuation();T.eq(resumed[1],expected[1],'full failed-round continuation matches');T.eq(resumed[2],expected[2],'full switch-round continuation matches')
  T.eq(Serializer.encode(cp),original,'caller checkpoint remains detached');f.close()
 end
end
T.finish('native fixed-damage complete rounds, cold checkpoints and received history')
