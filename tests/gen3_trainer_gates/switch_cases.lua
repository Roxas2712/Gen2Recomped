-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Actual native selection/execution; canonical projections compare action slots.
package.path='./?.lua;./?/init.lua;'..package.path
local C={}
function C.run(root,backend,edition,mode,case)
local f=dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,edition,3,'unified',false,false,'portable_enemy_action',nil,function(files)
 local record=case=='brainerror'and"{kind='brain',brain=function()error('intentional native brain failure')end}"or(case=='fresh-other-owner'and"{kind='class',uses=0}"or"{kind='class',uses=1,switch=true}")
 files['mods/portable_enemy_action/main.lua']="return function(mod) assert(mod.content.ai_classes:register('OBS_CLASS',"..record..")); mod.exports.api=mod end"
 if case=='fresh-other-owner'then files['mods/portable_enemy_action/main.lua']=files['mods/portable_enemy_action/main.lua']:gsub("mod.exports.api=mod", "mod.hooks:wrap('battle.enemy_switch_or_item',function()return{kind='switch',slot=1}end); mod.exports.api=mod")end
end)
local copy=require('src.mods.Merge').deepCopy
local b=f.fresh('TACKLE').battle
local party={b.enemy.mon,copy(b.enemy.mon),copy(b.enemy.mon)}
local players={b.player.mon,copy(b.player.mon)}
local two=mode:find('two-trainer',1,true)~=nil
local State,Commands,Adapter,Engine,ModBattle,oldData,oldSink
if backend=='gen1' then
 State,Commands=require('src.core.game3.battle.state'),require('src.core.game3.battle.commands')
 Adapter,Engine=require('src.core.game3.battle.adapter'),require('src.core.game3.battle.engine')
 oldSink,Adapter.textSink=Adapter.textSink,function(id)return id end
 ModBattle=require('src.core.game3.battle.mod_registries');oldData=ModBattle.data();ModBattle.bind(f.data)
 if mode~='single'then b=State.new({wild=false,double=true,playerParty=players,foeParty=party,foeHalf=two and 1 or nil})end
 b.wild,b.aiClass,b.foeParty,b.trainerItems=false,'OBS_CLASS',party,{}
else
 b.kind,b.trainer,b.enemyParty='trainer',{name='FIRST',items={},aiClass='OBS_CLASS'},two and{party[1]}or party;b:syncSides()
 if mode~='single'then
  f.game.save.party,b.playerParty,b.playerPartyIndices=players,players,{1,2};b.double=true;b:sendOutSecondPair()
  if two then
   f.data.trainers.OBS_SECOND={name='SECOND',items={},parties={{{prebuilt=copy(party[2])},{prebuilt=copy(party[3])}}}}
   assert(b:addOpponentTrainer('OBS_SECOND'));party=b:foeSummaryParty()
  end
 end
end
local id=mode:find('right',1,true)and 3 or 1
if mode:find('empty-left',1,true)then
 if backend=='gen1'then b.battlers[1]=nil;b.absent=b.absent or{};b.absent[1]=true
 else b:placeBattler(1,nil);b:syncSides()end
end
for _,mon in ipairs(party)do mon.nickname='PROBE'end
local actor=backend=='gen1'and State.battler(b,id)or b:battlerAt(id)
if backend=='gen1'then actor.mon.moves,actor.mon.pp,actor.mon.maxPp={33},{10},{10}
else local moves={{id=f.ids.TACKLE,pp=10}};actor.mon.moves,actor.curMoves=moves,moves end
actor.stages.attack=4
b.rng=function(lo)return lo or 0 end
local ok,action=pcall(function()
 if backend=='gen1'then if mode=='single'then return Commands.enemyAction(b)end;return Commands.enemyAction(b,id)end
 return b:enemyAction(actor)
end)
local payload=ok and type(action)=='table'and(action.gen3TrainerPayload or action)or{}
local kind=payload.kind or(ok and type(action)=='table'and'move'or false)
local row={case=case,selected=ok,kind=kind,slot=kind=='switch'and payload.slot or false}
if case:match('^classswitch')and ok then
 if case=='classswitch-fainted'then party[payload.slot].hp=0
 elseif case=='classswitch-active'then payload.slot=id==3 and 2 or 1
 elseif case=='classswitch-string'then payload.slot=tostring(payload.slot)
 elseif case=='classswitch-fractional'then payload.slot=payload.slot+0.5
 elseif case=='classswitch-replaced'then
  local slot=payload.slot;local replacement=copy(party[slot]);replacement.nickname='UPDATED_BENCH';party[slot]=replacement
  if backend=='gen2'then
   if slot<=#b.enemyParty then b.enemyParty[slot]=replacement else b.enemyPartyB[slot-#b.enemyParty]=replacement end
  end
 end
 local executed,why=pcall(function()
  if backend=='gen1' then Engine.performSwitch(b,Adapter.new(b),id,payload.slot)
  else b:executeAction(actor,b.player,action)end
 end)
 row.executed=executed
 if not executed then row.executionError=tostring(why)end
 local current=backend=='gen1'and State.battler(b,id)or b:battlerAt(id)
 for index,mon in ipairs(party)do if mon==current.mon then row.occupied=index end end
 row.hp=current.mon.hp;row.attackStage=current.stages.attack or 0;row.replaced=current~=actor;row.nickname=current.mon.nickname or false
 if current~=actor then row.partyIndex=current.partyIndex or false end
 -- Observe the next real decision after the selected switch as well.
 local nextOk,nextAction=pcall(function()
  if backend=='gen1'then if mode=='single'then return Commands.enemyAction(b)end;return Commands.enemyAction(b,id)end
  return b:enemyAction(current)
 end)
 row.nextSelected=nextOk
 local nextPayload=type(nextAction)=='table'and(nextAction.gen3TrainerPayload or nextAction)or{}
 row.nextKind=nextOk and(nextPayload.kind or'move')or false
 row.nextSlot=row.nextKind=='switch'and nextPayload.slot or false
else
 row.move=ok and type(action)=='table'and(backend=='gen1'and action.move or f.data.moves[action.id]and f.data.moves[action.id].index)or false
 row.moveSlot=false
 if row.move then
  if backend=='gen1' then row.moveSlot=action.slot or false
  else
   local slot=require('src.battle.EnemyMoveChoice').slot(action)
   for i,move in ipairs(actor.curMoves)do if move==slot then row.moveSlot=i;break end end
  end
 end
end
if ModBattle then ModBattle.bind(oldData);Adapter.textSink=oldSink end
f.close();return row,f.T
end
return C
