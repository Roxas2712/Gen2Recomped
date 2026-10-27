-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local T=require('tests.harness');love=require('tests.love_stub')
local seed=391477
love.math.random=function(a,b)
 seed=(seed*48271)%2147483647;if not a then return seed/2147483647 end
 if not b then a,b=1,a end;return a+seed%(b-a+1)
end
love.math.getRandomState=function()return tostring(seed)end
love.math.setRandomState=function(value)seed=assert(tonumber(value))end
love.math.newRandomGenerator=function()return{setState=function(_,value)assert(tonumber(value))end}end
local F=require('tests.checkpoint_fixture');local Native=require('src.battle.BattleState')
local Serializer=require('src.core.SaveSerializer');local Items=require('src.battle.Gen3TrainerItems')
local function copy(value)return assert(Serializer.decode(Serializer.encode(value)))end
local function field(graph,ref,key)
 for _,entry in ipairs(graph.nodes[assert(ref.node)].entries)do if entry.key==key then return entry end end
 error('missing class checkpoint field '..tostring(key))
end
local function turn(f)
 local b=f.stack:top();local before=b.turnCount or 0
 f.game.input.wasPressed=function()return true end;f.game.input.pressed=f.game.input.wasPressed
 b:chooseMenu('fight');b:chooseMove(1)
 local ticks=0
 repeat b:update(1/60);ticks=ticks+1
 until b.phase=='menu'and not b.current and #b.queue==0 or ticks>=4000
 T.check(ticks<4000 and b.phase=='menu','actual class round finishes')
 T.check((b.turnCount or 0)>before,'actual class round advances');return b
end
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 local f=F.boot(edition,3,'unified');local game=f.game
 game.save.options.battleAnimations=false
 game.data.constants.foreignClassBudget={}
 game.data.items.ITEM_013={id='ITEM_013',index=13,name='POTION'}
 game.data.constants.gen3ItemEffects={ITEM_013={heal=true,amount=20,bytes={0,0,0,0,4,0,20}}}
 game.data.ai_classes.CHECKPOINT_CLASS={kind='class',uses=1,item='ITEM_013'}
 local def=game.data.trainers.OPP_FIX_YOUNGSTER;def.aiClass='CHECKPOINT_CLASS';def.items={'ITEM_013','ITEM_013'}
 local calls=0
 f.loaded.loader.exports.checkpoint_fixture.api.hooks:wrap('battle.enemy_switch_or_item',function()calls=calls+1;return false end)
 local b=Native.newTrainer(game,'OPP_FIX_YOUNGSTER',1)
 b.phase,b.queue,b.introSlide='menu',{},0;b:syncSides()
 for _,actor in b:activeBattlers()do
  actor.mon.stats.hp,actor.mon.stats.defense,actor.mon.stats.spdef=400,400,400;actor.mon.hp,actor.shownHP=400,400
 end
 b.enemy.mon.hp,b.enemy.shownHP=10,10;f.stack.states={f.world,b};turn(f)
 T.eq(calls,0,'native class item precedes the lower seam')
 T.eq(b.modAiUses[b.enemy.mon],0,'one class use consumed for the actual mon')
 T.eq(Items.history(b).slots[1].spent,true,'first duplicate item consumed')
 T.eq(Items.history(b).slots[2].spent,false,'second duplicate remains stocked')
 local cp,why=f.checkpoints:capture(game);T.check(cp~=nil,'native class budget captured '..tostring(why));assert(cp,why)
 local badCases={
  {'budget type',function(g,budget)budget.value={scalar=false}end},
  {'negative uses',function(g,budget)field(g,field(g,budget.value,1).value,'left').value={scalar=-1}end},
  {'fractional uses',function(g,budget)field(g,field(g,budget.value,1).value,'left').value={scalar=0.5}end},
  {'uses type',function(g,budget)field(g,field(g,budget.value,1).value,'left').value={scalar='0'}end},
  {'foreign mon',function(g,budget)field(g,field(g,budget.value,1).value,'mon').value={anchor={'party',1}}end},
  {'imported array',function(g,budget)budget.value={anchor={'data','constants','foreignClassBudget'}}end},
 }
 for _,case in ipairs(badCases)do
  local bad=copy(cp);local g=bad.runtime.battle.graph;case[2](g,field(g,g.root,'modAiUses'))
  local save,top=game.save,f.stack:top();local ok,reason=f.checkpoints:restore(game,bad)
  T.eq(ok,false,case[1]..': rejected');T.eq(reason,'invalid_battle_state','budget rejected in preflight')
  T.eq(game.save,save,'budget rejection preserves save');T.eq(f.stack:top(),top,'budget rejection preserves controller')
 end
 local expected=turn(f);local hp=expected.enemy.mon.hp;local bytes=Serializer.encode(assert(f.checkpoints:capture(game)))
 T.eq(calls,1,'exhausted class falls through to the lower seam')
 T.check(f.checkpoints:restore(game,cp),'native class continuation restores')
 local fresh=f.stack:top()
 T.eq(fresh.modAiUses[fresh.enemy.mon],0,'budget is rebound to the restored native mon')
 T.eq(fresh.modAiUses[b.enemy.mon],nil,'retired mon is not a class-budget owner')
 local continued=turn(f)
 T.eq(calls,2,'restored exhausted class still falls through')
 T.eq(continued.enemy.mon.hp,hp,'class restore does not grant a second heal')
 T.eq(Items.history(continued).slots[2].spent,false,'restored budget preserves the second duplicate')
 T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),bytes,'complete class continuation matches')
 f.close()
end
T.finish('native trainer class budget checkpoint preflight and continuation')
