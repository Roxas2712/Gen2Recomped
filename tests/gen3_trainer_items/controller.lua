-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local C={}
function C.run(root,backend,version,mode)
 local Fixture=dofile(root..'/tests/charge_required/fixture.lua')
 local f=Fixture.new(root,backend,version,3,'unified',false,false,'portable_enemy_action',function(data)
  local rows={{13,'POTION',{0,0,0,0,4,0,20}},{19,'FULL RESTORE',{0,0,0,63,4,0,255}},{505,'REVIVE',{0,0,0,0,68,0,254}}}
  if backend=='gen2' then data.items={};data.constants.generation=3;data.constants.gen3ItemEffects={}end
  for _,row in ipairs(rows)do
   if backend=='gen1'then data.gen3Items._byId[row[1]]={name=row[2],pocket='ITEMS',effect=row[3]}
   else local key=('ITEM_%03d'):format(row[1]);data.items[key]={id=key,index=row[1],name=row[2]};data.constants.gen3ItemEffects[key]={bytes=row[3]}end
  end
 end,function(files)
  local key='mods/portable_enemy_action/main.lua';files[key]=assert(files[key]):gsub('battle%.enemy_action','battle.enemy_switch_or_item')
 end)
 local copy=require('src.mods.Merge').deepCopy
 local State,Commands,Adapter,Engine,Items,Data,previous,oldSink
 if backend=='gen1'then
  State,Commands=require('src.core.game3.battle.state'),require('src.core.game3.battle.commands')
  Adapter,Engine=require('src.core.game3.battle.adapter'),require('src.core.game3.battle.engine')
  Items,Data=require('src.core.game3.battle.ai_items'),require('src.core.game3.items_data')
  previous,Data._byId=Data._byId,f.data.gen3Items._byId
  oldSink,Adapter.textSink=Adapter.textSink,function(id)return id end
 else Items=require('src.battle.Gen3TrainerItems')end
 local cases={
  {'ordinary',function(n,b)return n(b)end,'item'},
  {'actor zero',function(n,b)local a=n(b);a.battler=0;return a end,'item'},
  {'actor absent',function(n,b)local a=n(b);a.battler=nil;return a end,'item'},
  {'actor numeric string',function(n,b)local a=n(b);a.battler='1';return a end,'item'},
  {'custom kind',function(n,b)local a=n(b);a.kind='custom';return a end,'custom'},
  {'absent item',function(n,b)local a=n(b);a.item=nil;return a end,'item'},
  {'unstocked item',function(n,b)local a=n(b);a.item=19;return a end,'item'},
  {'target zero',function(n,b)local a=n(b);a.target=0;return a end,'item'},
  {'false before next',function()return false end,'move'},
  {'false after next',function(n,b)n(b);return false end,'move'},
  {'changed into move',function(n,b)local a=n(b);a.kind='move';a.move=33;a.slot=1;return a end,'move'},
  {'switch request',function()return{kind='switch',slot=3}end,'switch'},
  {'fractional switch request',function()return{kind='switch',slot='3.5'}end,'switch'},
  {'replacement before item',function(n,b)return n(b)end,'item'},
  {'fainted before heal',function(n,b)return n(b)end,'item'},
  {'fainted before revive',function(n,b)return n(b)end,'item'},
 }
 local rows={}
 for _,case in ipairs(cases)do
  local label,choice,wanted=unpack(case)
  local b=f.fresh('TACKLE').battle
  local party={b.enemy.mon,copy(b.enemy.mon),copy(b.enemy.mon)}
  local players={b.player.mon,copy(b.player.mon)}
  local two=mode:find('two-trainer',1,true)~=nil
  local item=label=='fainted before revive' and 505 or 13
  if backend=='gen1'then
   if mode~='single'then b=State.new({wild=false,double=true,playerParty=players,foeParty=party,foeHalf=two and 1 or nil})end
   b.wild,b.foeParty,b.trainerItems=false,party,{item}
  else
   b.kind,b.enemyParty,b.trainer='trainer',two and{party[1]}or party,{name='FIRST',items={('ITEM_%03d'):format(item)}}
   b:syncSides()
   if mode~='single'then
    f.game.save.party,b.playerParty,b.playerPartyIndices=players,players,{1,2};b.double=true;b:sendOutSecondPair()
    if two then
     f.data.trainers.TEST_CONTROLLER_SECOND={name='SECOND',items={'ITEM_019'},parties={{{prebuilt=copy(party[2])},{prebuilt=copy(party[3])}}}}
     f.T.eq(b:addOpponentTrainer('TEST_CONTROLLER_SECOND'),true,label..': actual second-trainer admission')
     party=b:foeSummaryParty()
    end
   end
  end
  local id=mode:find('right',1,true)and 3 or 1
  if mode:find('empty-left',1,true)then
   if backend=='gen1'then b.battlers[1]=nil;b.absent=b.absent or {};b.absent[1]=true
   else b:placeBattler(1,nil);b:syncSides()end
  end
  local function at()return backend=='gen1' and State.battler(b,id)or b:battlerAt(id)end
  local actor=at();actor.mon.hp,actor.mon.maxHp=10,400;actor.mon.stats=actor.mon.stats or {};actor.mon.stats.hp=400
  if backend=='gen2'then
   local move={id=f.ids.TACKLE,pp=10};actor.mon.moves,actor.curMoves={move},{move}
  end
  b.rng=function(lo)return lo or 0 end
  local calls=0
  f.e.choose(function(...)calls=calls+1;return choice(...)end)
  local action
  if backend=='gen1'then action=mode=='single'and Commands.enemyAction(b)or Commands.enemyAction(b,id)
  else action=b:enemyAction(actor)end
  local payload=action and action.gen3TrainerPayload
  local kind=payload and payload.kind or action and action.kind or 'move'
  if mode=='single' and label=='custom kind'then wanted='move'end
  if mode~='single'and(label=='actor zero'or label=='actor numeric string'or id==3 and label=='actor absent')then wanted='move'end
  f.T.eq(kind,wanted,label..': real controller action kind')
  if label=='replacement before item'then
   party[3].hp=50
   if backend=='gen1'then Engine.performSwitch(b,Adapter.new(b),id,3)
   else b:switchTrainerInto(id,two and 2 or 3)end
  elseif label=='fainted before heal'or label=='fainted before revive'then at().mon.hp=0 end
  if kind=='item'then
   if backend=='gen1'then Engine.performEnemyItem(b,Adapter.new(b),action)
   else b:executeAction(actor,b.player,action)end
  elseif kind=='switch'then
   if backend=='gen1'then Engine.performSwitch(b,Adapter.new(b),id,action.slot)
   else b:executeAction(actor,b.player,action)end
  end
  local current=at();local index
  for i,mon in ipairs(party)do if current.mon==mon then index=i end end
  local stock
  if backend=='gen1'then stock=Items.history(b).items[1]or 0
  else local slot=Items.history(b).slots[1];stock=slot and not slot.spent and Items.itemNumber(b,slot.item)or 0 end
  local hp=kind=='item' and(label=='absent item'and 10 or label=='unstocked item'and 400 or label=='replacement before item'and 70 or label=='fainted before heal'and 0 or label=='fainted before revive'and 200 or 30)
    or kind=='switch'and 400 or 10
  f.T.eq(current.mon.hp,hp,label..': native item/switch post-state')
  f.T.eq(index,(kind=='switch'or label=='replacement before item')and 3 or id==3 and 2 or 1,label..': correct occupied party slot')
  f.T.eq(stock,(label=='false before next'or kind=='switch')and item or 0,label..': selection stock persists')
  f.T.eq(calls,1,label..': one actual hook call')
  rows[#rows+1]={label=label,kind=kind,hp=current.mon.hp,partySlot=index,stock=stock,playerHp=b.player.mon.hp,
   leftHp=id==3 and b.enemy and b.enemy.mon.hp or false}
 end
 if Data then Data._byId,Adapter.textSink=previous,oldSink end
 f.close();return rows,f.T
end
return C
