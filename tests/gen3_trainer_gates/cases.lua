-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Observe the registered lower seam from actual native enemy controllers.
local C={}
function C.run(root,backend,edition,mode)
 local f=dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,edition,3,'unified',false,false,'portable_enemy_action',function(data)
  if backend=='gen1'then data.gen3Items._byId[13]={name='POTION',pocket='ITEMS',effect={0,0,0,0,4,0,20}}
  else
   data.constants.generation=3;data.items.ITEM_013={id='ITEM_013',index=13,name='POTION'};data.constants.gen3ItemEffects={ITEM_013={heal=true,amount=20,bytes={0,0,0,0,4,0,20}}}
   data.moves.MOVE_033.gen3Effect,data.moves.MOVE_019.gen3Effect=0,155
  end
 end,function(files)
  files['mods/portable_enemy_action/main.lua']=[[
return function(mod)
 local choice
 mod.exports.api=mod;mod.exports.brainCalls=0;mod.exports.brainContext=false
 mod.exports.choose=function(fn)choice=fn end
 mod.exports.install=function()
  mod.hooks:wrap('battle.enemy_switch_or_item',function(next,...)return choice(next,...)end)
 end
 mod.exports.install()
 for id,record in pairs({
  GATE_ITEM={kind='class',uses=1,item='POTION'},
  GATE_DECLINE={kind='class',uses=1,item='POTION',chance=0},
  GATE_EMPTY={kind='class',uses=0,item='POTION'},
  GATE_SWITCH={kind='class',uses=1,switch=true},
  GATE_STATUS={kind='class',uses=1,item='POTION',onStatus=true},
 })do assert(mod.content.ai_classes:register(id,record))end
 local picks={GATE_BRAIN=2,GATE_BAD_BRAIN=9,GATE_NIL_BRAIN=false,GATE_TABLE_BRAIN={slot=2},GATE_ERROR_BRAIN="error"}
 for id,pick in pairs(picks)do
  local result=pick
  assert(mod.content.ai_classes:register(id,{kind='brain',brain=function(ctx)
   mod.exports.brainCalls=mod.exports.brainCalls+1
   mod.exports.brainContext=type(ctx)=='table'and ctx.battle~=nil and ctx.user~=nil
     and ctx.target~=nil and type(ctx.moves)=='table'and #ctx.moves==2
   mod.exports.brainMoves=type(ctx)=='table'and ctx.moves or false
   if result=="error"then error("intentional registered brain failure")end
   if result~=false then return result end
  end}))
 end
end
]]
 end)
 local copy=require('src.mods.Merge').deepCopy
 local State,Commands,Adapter,Engine,Items,Data,previous,oldSink,ModBattle,previousBound
 if backend=='gen1'then
  State,Commands=require('src.core.game3.battle.state'),require('src.core.game3.battle.commands')
  Adapter,Engine=require('src.core.game3.battle.adapter'),require('src.core.game3.battle.engine')
  Items,Data=require('src.core.game3.battle.ai_items'),require('src.core.game3.items_data')
  previous,Data._byId=Data._byId,f.data.gen3Items._byId
  oldSink,Adapter.textSink=Adapter.textSink,function(id)return id end
  ModBattle=require('src.core.game3.battle.mod_registries');previousBound=ModBattle.data();ModBattle.bind(f.data)
  f.T.check(ModBattle.aiRecord('GATE_ITEM')~=nil,'native controller reads the registered class dataset')
 else Items=require('src.battle.Gen3TrainerItems')end
 local labels={'ordinary','wild','pokedude','oldman','locked','recharge','class item','class decline','class exhausted','class switch','class status decline','class id alone','brain after seam','brain after item','brain invalid','brain nil','brain table','brain blocked','brain error','brain error blocked first','brain error pp depleted','brain error after next','error before next','error after next','owner removed','owner removed after next'}
 local classIds={['class item']='GATE_ITEM',['class decline']='GATE_DECLINE',['class exhausted']='GATE_EMPTY',['class switch']='GATE_SWITCH',['class status decline']='GATE_STATUS',['brain after seam']='GATE_BRAIN',['brain after item']='GATE_BRAIN',['brain invalid']='GATE_BAD_BRAIN',['brain nil']='GATE_NIL_BRAIN',['brain table']='GATE_TABLE_BRAIN',['brain blocked']='GATE_BRAIN',['brain error']='GATE_ERROR_BRAIN',['brain error blocked first']='GATE_ERROR_BRAIN',['brain error pp depleted']='GATE_ERROR_BRAIN',['brain error after next']='GATE_ERROR_BRAIN'}
 local rows={}
 for _,label in ipairs(labels)do
  f.result.loader.hooks:removeOwner('portable_enemy_action');f.e.install()
  local b=f.fresh('TACKLE').battle
  local party={b.enemy.mon,copy(b.enemy.mon),copy(b.enemy.mon)}
  if label~='class switch'then party[3].hp=0;if mode=='single'then party[2].hp=0 end end
  local players={b.player.mon,copy(b.player.mon)};local two=mode:find('two-trainer',1,true)~=nil
  local class=classIds[label]
  if backend=='gen1'then
   if mode~='single'then b=State.new({wild=false,double=true,playerParty=players,foeParty=party,foeHalf=two and 1 or nil})end
   b.wild,b.foeParty,b.trainerItems,b.aiClass=false,party,{13},class
  else
   b.kind,b.enemyParty,b.trainer='trainer',two and{party[1]}or party,{name='GATE TRAINER',items={'ITEM_013'},aiClass=class};b.aiUses=label=='class exhausted'and 0 or 1;b:syncSides()
   if mode~='single'then
    f.game.save.party,b.playerParty,b.playerPartyIndices=players,players,{1,2};b.double=true;b:sendOutSecondPair()
    if two then
     f.data.trainers.GATE_SECOND={name='SECOND',items={},parties={{{prebuilt=copy(party[2])},{prebuilt=copy(party[3])}}}}
     f.T.check(b:addOpponentTrainer('GATE_SECOND'),'native second trainer admitted');party=b:foeSummaryParty()
    end
   end
  end
  local id=mode:find('right',1,true)and 3 or 1
  if mode:find('empty-left',1,true)then
   if backend=='gen1' then b.battlers[1]=nil;b.absent=b.absent or{};b.absent[1]=true
   else b:placeBattler(1,nil);b:syncSides()end
  end
  local actor=backend=='gen1'and State.battler(b,id)or b:battlerAt(id)
  local full=label:match('^brain ')and label~='brain after item'and label~='brain error after next'
  actor.mon.hp,actor.mon.maxHp=full and 400 or 10,400
  actor.mon.stats=actor.mon.stats or{};actor.mon.stats.hp=400
  if backend=='gen1'then actor.mon.moves,actor.mon.pp,actor.mon.maxPp={33,19},{10,10},{10,10}
  else local moves={{id=f.ids.TACKLE,pp=10},{id=f.ids.FLY,pp=10}};actor.mon.moves,actor.curMoves=moves,moves end
  if label=='brain blocked'then if backend=='gen1'then actor.expDisabledMove=19 else actor.disabledMove=f.ids.FLY end end
  if label=='brain error blocked first'then if backend=='gen1'then actor.expDisabledMove=33 else actor.disabledMove=f.ids.TACKLE end end
  if label=='brain error pp depleted'then if backend=='gen1'then actor.mon.pp[1]=0 else actor.curMoves[1].pp=0 end end
  if label=='class id alone'and backend=='gen2'then b.trainer.id='GATE_ITEM'end
  if label=='wild'then if backend=='gen1' then b.wild=true else b.kind,b.trainer='wild',nil end
  elseif label=='pokedude'then if backend=='gen1' then b.pokedude=true else b.pokedudeDemo={}end
  elseif label=='oldman'then if backend=='gen1' then b.oldManTutorial=true else b.demo=true end
  elseif label=='locked'then if backend=='gen1'then actor.expLockedMove,actor.expLockedSlot=33,1 else actor.charging=actor.curMoves[1]end
  elseif label=='recharge'then if backend=='gen1'then actor.expMustRecharge=true else actor.mustRecharge=true end end
  b.rng=function(lo)return lo or 0 end
  f.e.brainCalls,f.e.brainContext,f.e.brainMoves=0,false,false
  local calls,continuations=0,0
  f.e.choose(function(next,current)
   calls=calls+1
   if label=='error before next'then error('intentional gate error before next')end
   if label=='brain after seam'then return false end
   continuations=continuations+1;local result=next(current)
   if label=='brain error after next'then return false end
   if label=='error after next'then error('intentional gate error after next')end
   if label=='owner removed after next'then f.result.loader.hooks:removeOwner('portable_enemy_action')end
   return result
  end)
  local Runtime=require('src.mods.Runtime')
  if label=='owner removed'then f.result.loader.hooks:removeOwner('portable_enemy_action')end
  local action=backend=='gen1'and(mode=='single'and Commands.enemyAction(b)or Commands.enemyAction(b,id))or b:enemyAction(actor)
  local payload=type(action)=='table'and(action.gen3TrainerPayload or action)or{}
  local kind=payload.kind or(type(action)=='table'and(action.special=='aiItem'and'item'or action.special=='aiSwitch'and'switch'))or(type(action)=='table'and'move'or'invalid')
  local move=kind=='move'and(backend=='gen1'and tonumber(payload.move)or action.id and f.data.moves[action.id]and f.data.moves[action.id].index)or false
  local slot=kind=='switch'and(payload.slot or action.index)or false
  local stock
  if backend=='gen1'then stock=Items.history(b).items[1]or 0
  else local entry=Items.history(b).slots[1];stock=entry and not entry.spent and Items.itemNumber(b,entry.item)or 0 end
  local left=false
  if class and label:find('class',1,true)then
   left=b.modAiUses and b.modAiUses[actor.mon]
   if left==nil or left==false then left=label=='class exhausted'and 0 or 1 end
  end
  if label=='recharge'then
   local hp,pp=actor.mon.hp,backend=='gen1'and actor.mon.pp[1]or actor.curMoves[1].pp
   if backend=='gen1'then Engine.resolveMove(actor,b.player,action.move,action.slot,Adapter.new(b),b,{}, {})
   else b:executeAction(actor,b.player,action)end
   f.T.eq(actor.mon.hp,hp,'recharge consumes no healing item')
   f.T.eq(backend=='gen1'and actor.mon.pp[1]or actor.curMoves[1].pp,pp,'recharge spends no attack PP')
   kind,move='recharge',false
  end
  local row={label=label,kind=kind,move=move or false,slot=slot,calls=calls,nextCalls=continuations,stock=stock,classLeft=left,brainCalls=f.e.brainCalls,brainContext=f.e.brainContext,seamLive=Runtime.wantsHook('battle.enemy_switch_or_item')}
  row.brainMoves=f.e.brainMoves
  rows[#rows+1]=row
 end
 if Data then Data._byId,Adapter.textSink=previous,oldSink end
 if ModBattle then ModBattle.bind(previousBound)end
 f.close();return rows,f.T
end
return C
