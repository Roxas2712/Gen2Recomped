-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real native turns, public checkpoint restoration and timed side protection.
local T=require('tests.harness');love=require('tests.love_stub')
local seed=714821
love.math.random=function(a,b)
 seed=(seed*48271)%2147483647
 if not a then return seed/2147483647 end
 if not b then a,b=1,a end
 return a+seed%(b-a+1)
end
love.math.getRandomState=function()return tostring(seed)end
love.math.setRandomState=function(value)seed=assert(tonumber(value))end
love.math.newRandomGenerator=function()return{setState=function(_,value)assert(tonumber(value))end}end
local Fixture=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState');local Serializer=require('src.core.SaveSerializer')
local function copy(value)return assert(Serializer.decode(Serializer.encode(value)))end
local function field(graph,ref,key)
 for _,entry in ipairs(graph.nodes[assert(ref.node)].entries)do if entry.key==key then return entry end end
 error('missing checkpoint field '..tostring(key))
end
local function moves(actor,id)
 local rows={{id=id,pp=40}};actor.mon.moves,actor.curMoves=rows,rows
end
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
 T.check(ticks<4000 and battle.phase=='menu','native turn finishes')
 T.check((battle.turnCount or 0)>previous,'native turn advances')
 return battle
end
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,double in ipairs({false,true})do
  local f=Fixture.boot(edition,3,'unified');local game=f.game
  game.save.options.battleAnimations=false
  game.data.moves.MIST_CHECKPOINT={id='MIST_CHECKPOINT',index=54,name='MIST',effect='MIST_EFFECT',gen3Effect=46,type='ICE',power=0,accuracy=100,pp=40,target=16}
  game.data.moves.GROWL_CHECKPOINT={id='GROWL_CHECKPOINT',index=45,name='GROWL',effect='ATTACK_DOWN1_EFFECT',gen3Effect=18,type='NORMAL',power=0,accuracy=100,accuracyRaw=255,pp=40,target=0}
  local def=game.data.trainers.OPP_FIX_YOUNGSTER;def.items={};def.doubleBattle=double
  if double then game.save.party[2]=copy(game.save.party[1])end
  local battle=Native.newTrainer(game,'OPP_FIX_YOUNGSTER',1)
  battle.phase,battle.queue,battle.introSlide='menu',{},0;battle:syncSides()
  for _,actor in battle:activeBattlers()do
   actor.mon.stats.hp,actor.mon.stats.defense,actor.mon.stats.spdef=400,400,400
   actor.mon.hp,actor.shownHP=400,400;actor.curStats.speed=actor.isPlayer and 50 or 200
   moves(actor,actor.isPlayer and'GROWL_CHECKPOINT'or'MIST_CHECKPOINT')
  end
  f.stack.states={f.world,battle};turn(f)
  T.eq(battle.sides[2].gen3MistTurns,4,'MIST application turn counts as the first round')
  for _,actor in battle:activeBattlers()do
   if not actor.isPlayer then
    T.eq(actor.stages.attack or 0,0,'same-turn primary drop blocked')
    T.eq(actor.mist,true,'native battler reads side protection')
    moves(actor,'FIX_TACKLE')
   end
  end
  local cp,why=f.checkpoints:capture(game);T.check(cp~=nil,'native Mist checkpoint captured '..tostring(why))
  assert(cp,why)
  local initial=Serializer.encode(cp)
  -- Invalid countdowns must fail before replacing the live save/controller.
  for _,value in ipairs({-1,6,1.5,'4',false})do
   local bad=copy(cp);local graph=bad.runtime.battle.graph
   local sides=field(graph,graph.root,'sides').value
   local own=field(graph,sides,2).value
   field(graph,own,'gen3MistTurns').value={scalar=value}
   local save,top=game.save,f.stack:top();local ok,reason=f.checkpoints:restore(game,bad)
   T.eq(ok,false,'invalid side duration rejected')
   T.eq(reason,'invalid_battle_state','duration rejected in native preflight')
   T.eq(game.save,save,'invalid duration preserves save')
   T.eq(f.stack:top(),top,'invalid duration preserves live controller')
  end
  local function continuation()
   local rows={}
   for i=1,5 do
    local b=turn(f)
    T.eq(b.sides[2].gen3MistTurns or 0,math.max(0,4-i),'side ticks once per round, independent of flank count')
    T.eq(b.enemy.stages.attack or 0,i<5 and 0 or double and -2 or -1,'protection ends after its fifth round')
    if i>=4 then T.eq(b.enemy.mist,nil,'expired side projection cleared')end
    rows[i]=Serializer.encode(assert(f.checkpoints:capture(game)))
   end
   return rows
  end
  local expected=continuation()
  T.check(f.checkpoints:restore(game,cp),'public native Mist checkpoint restored')
  T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),initial,'full captured side and projection recapture identically')
  local resumed=continuation()
  for i=1,5 do T.eq(resumed[i],expected[i],'complete next checkpoint matches at resumed round '..i)end
  T.eq(Serializer.encode(cp),initial,'caller checkpoint stays detached')
  f.close()
 end
end
T.finish('native five-round Mist turns, expiry and checkpoint validation')
