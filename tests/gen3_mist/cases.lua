-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Compare side Mist through real move, trainer-controller and residual paths.
local C={}
function C.run(root,backend,edition,mode)
 local specs={
  {54,'MIST','MIST_EFFECT',46,0,15,16,0},
  {45,'GROWL','ATTACK_DOWN1_EFFECT',18,0,0,0,0},
  {114,'HAZE','HAZE_EFFECT',25,0,15,64,0},
  {145,'BUBBLE','SPEED_DOWN_SIDE_EFFECT',70,20,11,0,10},
  {315,'OVERHEAT','OVERHEAT_EFFECT',204,140,10,0,100},
 }
 local f=dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,edition,3,'unified',false,false,'portable_enemy_action',function(data,_,_,rom,names)
  if backend=='gen1'then data.gen3Items._byId[501]={name='GUARD SPEC',pocket='ITEMS',effect={0,0,0,128,0,0,0}}
  else
   data.constants.generation=3;data.constants.gen3ItemEffects={ITEM_501={bytes={0,0,0,128,0,0,0}}}
   data.items.ITEM_501={id='ITEM_501',index=501,name='GUARD SPEC'}
  end
  for _,s in ipairs(specs)do
   if backend=='gen1'then
    rom[s[1]]={effect=s[4],power=s[5],type=s[6],accuracy=100,pp=20,target=s[7],priority=0,flags=0,secondaryChance=s[8]}
    data.gen3Moves._rom[s[1]]=rom[s[1]];names[s[1]]=s[2];data.gen3Pokemon._moveNames[s[1]]=s[2]
   else
    local id=('MOVE_%03d'):format(s[1])
    data.moves[id]={id=id,index=s[1],name=s[2],effect=s[3],gen3Effect=s[4],power=s[5],type=({[0]='NORMAL',[10]='FIRE',[11]='WATER',[15]='ICE'})[s[6]],accuracy=100,accuracyRaw=255,pp=20,target=s[7],secondaryChance=s[8]}
   end
  end
 end,function(files)
  local path='mods/portable_enemy_action/main.lua';files[path]=assert(files[path]):gsub('battle%.enemy_action','battle.enemy_switch_or_item')
 end)
 local copy=require('src.mods.Merge').deepCopy
 local State,Adapter,Engine,Commands,Data,previous,oldSink
 if backend=='gen1' then
  State,Adapter=require('src.core.game3.battle.state'),require('src.core.game3.battle.adapter')
  Engine,Commands=require('src.core.game3.battle.engine'),require('src.core.game3.battle.commands')
  Data=require('src.core.game3.items_data');previous,Data._byId=Data._byId,f.data.gen3Items._byId
  oldSink,Adapter.textSink=Adapter.textSink,function(id)return id end
 end
 f.e.choose(function(next,battle)return next(battle)end)
 local rows={}
 local labels={'guard blocks primary','move blocks primary','move does not refresh','item does not refresh','expires after five rounds','switch preserves side','haze preserves side','chance secondary blocked','certain secondary bypasses','intimidate blocked','other side unprotected','self lowering bypasses','both flanks protected'}
 for _,label in ipairs(labels)do
  local b=f.fresh('TACKLE').battle
  local party={b.enemy.mon,copy(b.enemy.mon),copy(b.enemy.mon)}
  if backend=='gen1'then
   if mode~='single'then b=State.new({wild=false,double=true,playerParty={b.player.mon,copy(b.player.mon)},foeParty=party})end
   b.wild,b.trainerItems,b.foeParty=false,{501},party
   require('src.core.game3.battle.ai').battleStart(b,{rng=function(lo)return lo or 0 end})
  else
   b.kind,b.trainer,b.enemyParty='trainer',{name='MIST FIXTURE',items={'ITEM_501'}},party;b:syncSides()
   if mode~='single'then
    local players={b.player.mon,copy(b.player.mon)}
    f.game.save.party,b.playerParty,b.playerPartyIndices=players,players,{1,2};b.double=true;b:sendOutSecondPair()
   end
  end
  b.rng=function(lo)return lo or 0 end
  local id=mode=='double-right'and 3 or 1
  local function at(pos)return backend=='gen1'and State.battler(b,pos)or b:battlerAt(pos)end
  local function timer()
   local side=backend=='gen1'and b.enemySide or b.sides[2]
   return side[backend=='gen1'and'expMistTurns'or'gen3MistTurns']or 0
  end
  local function move(number,user,target)
   if backend=='gen1'then return Engine.resolveMove(user,target,number,nil,Adapter.new(b),b,{}, {called=true})end
   return b:performMove(user,target,{id=('MOVE_%03d'):format(number),pp=20},true,true)
  end
  local function tick()
   if backend=='gen1'then return Engine.collectResidualEvents(b,Adapter.new(b))end
   b:endOfTurn()
  end
  local function guard()
   f.e.choose(function(next,current)
    if label=='item does not refresh'then return{kind='item',item=501}end
    return next(current)
   end)
   local action=backend=='gen1'and(mode=='single'and Commands.enemyAction(b)or Commands.enemyAction(b,id))or b:enemyAction(at(id))
   f.T.eq(backend=='gen1'and action.kind or action.gen3TrainerPayload and action.gen3TrainerPayload.kind,'item',label..': actual trainer item action')
   if backend=='gen1'then Engine.performEnemyItem(b,Adapter.new(b),action)
   else b:executeAction(at(id),b.player,action)end
  end
  local function mist()move(54,at(id),at(id))end
  if label=='guard blocks primary'then guard()else mist()end
  if label=='move does not refresh'then tick();mist()
  elseif label=='item does not refresh'then tick();guard()
  elseif label=='expires after five rounds'then for _=1,5 do tick()end
  elseif label=='switch preserves side'then
   if backend=='gen1'then Engine.performSwitch(b,Adapter.new(b),id,3)else b:switchTrainerInto(id,3)end
  elseif label=='haze preserves side'then move(114,b.player,at(id))
  elseif label=='chance secondary blocked'or label=='certain secondary bypasses'then
   if label=='certain secondary bypasses'then
    if backend=='gen1' then f.data.gen3Moves._rom[145].secondaryChance=100
    else f.data.moves.MOVE_145.secondaryChance=100 end
   end
   move(145,b.player,at(id))
   if backend=='gen1'then f.data.gen3Moves._rom[145].secondaryChance=10 else f.data.moves.MOVE_145.secondaryChance=10 end
  elseif label=='intimidate blocked'then
   if backend=='gen1'then
    b.player.ability='INTIMIDATE';b.player.expIntimidatePending=true
    require('src.core.game3.battle.abilities').runIntimidate(Adapter.new(b))
   else b.player.abilityOverride='INTIMIDATE';b:abilitySwitchIn(b.player)end
  elseif label=='other side unprotected'then move(45,at(id),b.player)
  elseif label=='self lowering bypasses'then move(315,at(id),b.player)
  end
  if label~='chance secondary blocked'and label~='certain secondary bypasses'and label~='intimidate blocked'and label~='other side unprotected'and label~='self lowering bypasses'then move(45,b.player,at(id))end
  local other=mode~='single'and at(id==1 and 3 or 1)or nil
  if label=='both flanks protected'and other then move(45,b.player,other)end
  local target=at(id);local stages=target.stages
  local row={label=label,timer=timer(),attack=stages.attack or 0,speed=stages.speed or 0,spatk=stages[backend=='gen1'and'spAtk'or'spatk']or 0,playerAttack=b.player.stages.attack or 0,otherAttack=other and(other.stages.attack or 0)or false}
  f.T.eq(row.timer,label=='expires after five rounds'and 0 or(label=='move does not refresh'or label=='item does not refresh')and 4 or 5,label..': native side duration')
  f.T.eq(row.attack,label=='expires after five rounds'and -1 or 0,label..': native primary protection')
  f.T.eq(row.speed,label=='certain secondary bypasses'and -1 or 0,label..': native secondary protection')
  f.T.eq(row.playerAttack,label=='other side unprotected'and -1 or 0,label..': other side independent')
  f.T.eq(row.spatk,label=='self lowering bypasses'and -2 or 0,label..': self change independent')
  if other then f.T.eq(row.otherAttack,0,label..': other flank protected')end
  rows[#rows+1]=row
 end
 if Data then Data._byId,Adapter.textSink=previous,oldSink end
 f.close();return rows,f.T
end
return C
