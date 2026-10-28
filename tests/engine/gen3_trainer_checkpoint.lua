-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Actual native turns and public checkpoint restore must retain the opposing
-- bag observed before later edits to the trainer's item definitions.
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
local Native=require('src.battle.BattleState')
local Items=require('src.battle.Gen3TrainerItems')
local Serializer=require('src.core.SaveSerializer')
local function copy(value)return assert(Serializer.decode(Serializer.encode(value)))end
local function field(graph,reference,key)
 for _,entry in ipairs(assert(graph.nodes[assert(reference.node)]).entries)do
  if entry.key==key then return entry end
 end
 error('missing owned checkpoint field '..tostring(key))
end
local function stockGraph(cp)
 local graph=cp.runtime.battle.graph
 local state=field(graph,graph.root,'_gen3TrainerItems')
 local history=field(graph,state.value,'history')
 local slots=field(graph,history.value,'slots')
 return graph,state,history,slots
end
local function turn(f)
 local b=f.stack:top();local before=b.turnCount or 0
 f.game.input.wasPressed=function()return true end
 f.game.input.pressed=f.game.input.wasPressed
 b:chooseMenu('fight');b:chooseMove(1)
 local ticks=0
 repeat b:update(1/60);ticks=ticks+1
 until b.phase=='menu' and not b.current and #b.queue==0 or ticks>=4000
 T.check(ticks<4000 and b.phase=='menu','actual native turn reaches its next decision')
 T.check((b.turnCount or 0)>before,'native turn actually advanced')
 return b
end
for _,version in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,policy in ipairs({{1,'native'},{2,'native'},{2,'unified'},{3,'unified'}})do
 local edition=version..'/'..policy[1]..'/'..policy[2]
 local f=Fixture.boot(version,policy[1],policy[2]);local game=f.game
 game.save.options.battleAnimations=false
 game.data.constants.checkpointStockTrap={}
 local calls=0
 f.loaded.loader.exports.checkpoint_fixture.api.hooks:wrap('battle.enemy_switch_or_item',function(next,battle)
  calls=calls+1;return next(battle)
 end)
 for _,row in ipairs({{13,{0,0,0,0,4,0,20}},{19,{0,0,0,63,4,0,255}},{501,{0,0,0,128,0,0,0}}})do
  local key=('ITEM_%03d'):format(row[1]);game.data.items[key]={id=key,index=row[1],name=key}
  game.data.constants.gen3ItemEffects=game.data.constants.gen3ItemEffects or{}
  game.data.constants.gen3ItemEffects[key]={bytes=row[2]}
 end
 local def=game.data.trainers.OPP_FIX_YOUNGSTER
 def.items={[1]='ITEM_013',[3]='ITEM_501',[4]='ITEM_019'}
 local battle=Native.newTrainer(game,'OPP_FIX_YOUNGSTER',1)
 battle.phase,battle.queue,battle.introSlide='menu',{},0;battle:syncSides()
 for _,actor in ipairs({battle.player,battle.enemy})do
  actor.mon.stats.hp,actor.mon.stats.defense,actor.mon.stats.spdef=400,400,400
  actor.mon.hp,actor.shownHP=400,400
 end
 battle.enemy.mon.hp,battle.enemy.shownHP=10,10
 f.stack.states={f.world,battle}
 turn(f)
 T.eq(calls,1,edition..': actual registered trainer hook ran')
 local history=Items.history(battle)
 T.eq(history.slots[1].spent,true,edition..': first native item was consumed')
 T.eq(history.slots[3].spent,false,edition..': Full Restore remains stocked')
 T.check(battle.enemy.mon.hp>10 and battle.enemy.mon.hp<100,edition..': actual item healed before the player move')
 -- The bag is a native snapshot; editing its class after first use must not
 -- change the item restored at the same unspent original slot.
 def.items[4]='ITEM_013'
 local cp,code,detail=f.checkpoints:capture(game)
 T.check(cp~=nil,edition..': captures trainer continuation '..tostring(code)..' '..tostring(detail))
 if cp then
  local bytes=Serializer.encode(cp)
  local expected=turn(f)
  T.eq(Items.history(expected).slots[3].item,'ITEM_019',edition..': live bag keeps the original Full Restore')
  T.eq(Items.history(expected).slots[3].spent,true,edition..': live continuation consumes Full Restore')
  local expectedHp=expected.enemy.mon.hp
  T.check(expectedHp>300,edition..': native Full Restore actually healed')
  local ok,reason=f.checkpoints:restore(game,cp)
  T.check(ok,edition..': public cold restore '..tostring(reason))
  if ok then
   local fresh=f.stack:top();local retained=rawget(fresh,'_gen3TrainerItems')
   T.check(retained~=nil,edition..': cold restore retains native stock history')
   T.eq(Items.history(fresh).slots[3].item,'ITEM_019',edition..': restored unspent item is not re-read from changed class')
   T.eq(Items.history(fresh).slots[1].spent,true,edition..': consumed first slot stays consumed')
   T.eq(Items.history(fresh).slots[3].spent,false,edition..': captured Full Restore stays available')
   T.check(fresh~=battle and fresh.enemy~=battle.enemy,edition..': fresh native controller and battler')
   T.check(retained~=battle._gen3TrainerItems and retained.history~=history,edition..': stock graph belongs to the reconstructed controller')
   T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),bytes,edition..': complete native checkpoint recaptures identically')
   local selected=fresh.turnActions[fresh.enemy]
   T.eq(selected.gen3TrainerAction,true,edition..': actual trainer action tag survives')
   T.eq(selected.gen3TrainerPosition,1,edition..': queued controller position survives')
   T.eq(selected.gen3TrainerPayload.item,13,edition..': original numeric native item survives')
   local malformed={
    {'state type',function(_,state)state.value={scalar=false}end},
    {'history type',function(_,_,h)h.value={scalar=false}end},
    {'slot array type',function(_,_,_,slots)slots.value={scalar=0}end},
    {'negative count',function(g,_,h)field(g,h.value,'count').value={scalar=-1}end},
    {'excessive count',function(g,_,h)field(g,h.value,'count').value={scalar=5}end},
    {'fractional count',function(g,_,h)field(g,h.value,'count').value={scalar=2.5}end},
    {'extra slot',function(g,_,h)field(g,h.value,'count').value={scalar=2}end},
    {'missing slot',function(g,_,_,slots)
     for index,entry in ipairs(g.nodes[slots.value.node].entries)do if entry.key==2 then table.remove(g.nodes[slots.value.node].entries,index);break end end
    end},
    {'duplicate original',function(g,_,_,slots)field(g,field(g,slots.value,2).value,'original').value={scalar=1}end},
    {'invalid original',function(g,_,_,slots)field(g,field(g,slots.value,3).value,'original').value={scalar=5}end},
    {'spent type',function(g,_,_,slots)field(g,field(g,slots.value,1).value,'spent').value={scalar=0}end},
    {'unknown item',function(g,_,_,slots)field(g,field(g,slots.value,2).value,'item').value={scalar='MISSING_TRAINER_ITEM'}end},
    {'named slot',function(g,_,_,slots)field(g,slots.value,1).key='first'end},
    {'fractional slot',function(g,_,_,slots)field(g,slots.value,1).key=1.5 end},
    {'imported cache anchor',function(_,state)state.value={anchor={'data','constants','checkpointStockTrap'}}end},
   }
   for _,case in ipairs(malformed)do
    local bad=copy(cp);case[2](stockGraph(bad))
    local beforeSave,beforeBattle=game.save,f.stack:top()
    local restored,why=f.checkpoints:restore(game,bad)
    T.eq(restored,false,edition..'/'..case[1]..': malformed native stock rejected')
    T.eq(why,'invalid_battle_state',edition..'/'..case[1]..': native preflight reason')
    T.eq(game.save,beforeSave,edition..'/'..case[1]..': save remains untouched')
    T.eq(f.stack:top(),beforeBattle,edition..'/'..case[1]..': native controller remains untouched')
    if restored then assert(f.checkpoints:restore(game,cp))end
   end
   local resumed=turn(f)
   T.eq(resumed.enemy.mon.hp,expectedHp,edition..': restored actual turn has identical HP')
   T.eq(Items.history(resumed).slots[3].spent,true,edition..': restored actual turn consumes the same stock slot')
   T.eq(Serializer.encode(cp),bytes,edition..': checkpoint payload stays detached')
  end
 end
 f.close()
 end
end
T.finish('native GBA trainer item turns across public cold checkpoints')
