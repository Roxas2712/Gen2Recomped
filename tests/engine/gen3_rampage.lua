-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local R=require('src.battle.Gen3Rampage')
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'} do
 local f=require('tests.enemy_actions.fixture').new('.','gen2',edition,3,'unified',function(data,_,ids)
  data.pokemon.CHARMANDER.abilities={}
  data.items.QA_PERSIM={name='PERSIM BERRY',holdEffect='CURE_CONFUSION'}
  for _,row in ipairs{{'THRASH',37},{'PETAL_DANCE',80},{'OUTRAGE',200}} do
   local id,n=row[1],row[2];ids[id]=id
   data.moves[id]={id=id,index=n,name=id,effect='THRASH_PETAL_DANCE_EFFECT',gen3Effect=27,
    type='NORMAL',power=1,accuracy=100,pp=15,target=4,flags=51,protectAffected=true}
  end
 end)
 local function fresh(id,roll,enemy)
  local x=f.fresh(id,{enemy=enemy});local b=x.battle
  b.player.curStats.speed=100;b.enemy.curStats.speed=50
  b.rng=function(lo,hi)
   if lo==0 and hi==1 then return roll end
   return hi or lo
  end
  return x,b,x.user,x.target
 end
 for _,id in ipairs{'THRASH','PETAL_DANCE','OUTRAGE'} do
  for roll=0,1 do for _,enemy in ipairs{false,true} do
   local x,b,u,t=fresh(id,roll,enemy);local duration=roll+2
   for turn=1,duration do
    x.use()
    T.eq(x.pp(),9,edition..' '..id..' debits only the first selected PP')
    T.check(b.moveAnimRow and b.moveAnimRow.anim==id,'every forced turn retains its move animation')
    T.eq(u.confusedTurns,nil,'fatigue never interrupts either battler action')
    T.eq(u.thrashTurns,duration-turn+1,'successful hits do not replace end-turn countdown')
    b:endOfTurn()
    if turn<duration then
     T.eq(u.thrashTurns,duration-turn,'one native end-turn decrement')
     T.check(b:menuLockedAction(u)~=nil,'continuation keeps the ordinary menu locked')
    else
     T.eq(b:menuLockedAction(u),nil,'original two/three-turn sequence unlocks')
     T.eq(u.confusedTurns,5,'fatigue is applied at the final end-turn phase')
     T.eq(u.thrashTarget,nil,'completed lock cannot retain another rampage target')
    end
   end
  end end
 end
 do
  local x,b,u,t=fresh('OUTRAGE',1,false);t.abilityOverride='PRESSURE'
  x.use();T.eq(x.pp(),8,'Pressure costs two PP for initial selection')
  b:endOfTurn();x.move.pp=0;x.use()
  T.eq(x.pp(),0,'an exhausted selected slot still completes its native lock')
  T.check(t.mon.hp<400,'zero-PP continuation still damages')
 end
 do
  local x,b,u,t=fresh('OUTRAGE',1,false)
  x.use();b:endOfTurn();t.protecting=true;x.use()
  T.eq(u.thrashTurns,nil,'Protect cancels a running native rampage')
  T.eq(x.pp(),8,'Protect-canceled continuation reaches the native PP command')
  b:endOfTurn();T.eq(u.confusedTurns,nil,'Protect cancellation does not cause fatigue')
 end
 do
  local x,b,u,t=fresh('OUTRAGE',1,false);t.abilityOverride='PRESSURE'
  x.use();b:endOfTurn();t.protecting=true;x.use()
  T.eq(x.pp(),6,'Pressure applies again after Protect cancels MULTIPLETURNS')
 end
 do
  local x,b,u,t=fresh('OUTRAGE',1,false)
  x.use();b:endOfTurn();x.move.pp=0;t.protecting=true;x.use()
  T.eq(x.pp(),0,'Protect does not reject an admitted zero-PP forced turn')
  T.eq(u.thrashTurns,nil)
 end
 do
  local x,b,u,t=fresh('OUTRAGE',1,false)
  x.use();b:endOfTurn();local saved=t.mon.hp
  local check=b.accuracyRoll;b.accuracyRoll=function()return false,'accuracy'end
  x.use();T.eq(t.mon.hp,saved,'ordinary accuracy miss does no damage')
  T.eq(u.thrashTurns,2,'miss never decrements the counter in the damage callback')
  b:endOfTurn();T.eq(u.thrashTurns,1,'missed continuation still consumes its original round')
  b.accuracyRoll=check
 end
 do
  local x,b,u,t=fresh('OUTRAGE',0,false);u.abilityOverride='OWN_TEMPO'
  x.use();b:endOfTurn();x.use();b:endOfTurn()
  T.eq(u.thrashTurns,nil);T.eq(u.confusedTurns,nil,'Own Tempo refuses fatigue confusion')
 end
 do
  local x,b,u,t=fresh('OUTRAGE',0,false);u.mon.item='QA_PERSIM'
  x.use();b:endOfTurn();x.use()
  T.eq(u.mon.item,'QA_PERSIM','native berry is retained until fatigue actually lands')
  b:endOfTurn()
  T.eq(u.mon.item,nil,'normal after-action item phase consumes fatigue cure')
  T.eq(u.confusedTurns,nil,'native berry cures fatigue in that phase')
 end
 do
  local x,b,u,t=fresh('OUTRAGE',0,false);u.confusedTurns=4
  x.use();b:endOfTurn();x.use();b:endOfTurn()
  T.eq(u.confusedTurns,4,'fatigue never rerolls an existing confusion')
 end
 for _,status in ipairs{'SLP','FRZ'} do
  local x,b,u,t=fresh('OUTRAGE',1,false);x.use();b:endOfTurn()
  require('src.battle.StatusRegistry').inflict(b,u,status,{selfInflicted=true})
  T.eq(u.mon.status,status);T.eq(u.thrashTurns,nil,'new sleep/freeze cancels the lock')
  b:endOfTurn();T.eq(u.confusedTurns,nil,'status cancellation has no fatigue')
 end
 do
  local x,b,u,t=fresh('THRASH',1,false);x.use();b:endOfTurn()
  t.curTypes={'GHOST'};local hp=t.mon.hp;x.use()
  T.eq(t.mon.hp,hp,'original type immunity prevents the continuation damage')
  T.eq(u.thrashTurns,2,'immunity retains the lock until its native end-turn phase')
  b:endOfTurn();T.eq(u.thrashTurns,nil,'WasUnableToUseMove cancels the immune continuation')
  T.eq(u.confusedTurns,nil,'type-immunity cancellation does not cause fatigue')
 end
 do
  local x,b,u,t=fresh('OUTRAGE',1,false);x.use();b:endOfTurn()
  u.confusedTurns=4;b.rng=function(lo)return lo or 0 end
  local hp=u.mon.hp;b:executeAction(u,t,u.thrashMove)
  T.check(u.mon.hp<hp,'actual confusion self-damage executes')
  T.eq(u.thrashTurns,2,'self-damage retains rampage until its native end-turn phase')
  b:endOfTurn();T.eq(u.thrashTurns,nil)
  T.eq(u.confusedTurns,3,'interruption does not reroll the existing confusion')
 end
 do
  local x,b,u,t=fresh('OUTRAGE',1,false);x.use();b:endOfTurn()
  u.mon.status='PAR';b.rng=function(lo)return lo or 0 end
  b:executeAction(u,t,u.thrashMove)
  local expected=2;if edition=='ruby'or edition=='sapphire'then expected=nil end
  T.eq(u.thrashTurns,expected,
   'RS paralysis cancels immediately; FRLG/E retain the lock until end turn')
  b:endOfTurn();T.eq(u.thrashTurns,nil);T.eq(u.confusedTurns,nil,'full paralysis never causes fatigue')
 end
 do
  local x,b,u,t=fresh('OUTRAGE',0,false);x.use();b:endOfTurn()
  u.flinched=true;b:executeAction(u,t,u.thrashMove)
  T.eq(u.thrashTurns,nil,'actual flinch canceller releases native rampage')
  b:endOfTurn();T.eq(u.confusedTurns,nil,'flinch does not cause fatigue')
 end
 do
  local x,b,u,t=fresh('OUTRAGE',0,false);x.use();b:endOfTurn()
  b.result='win';b:endOfTurn();T.eq(u.thrashTurns,1,'decided battle skips fatigue residuals')
 end
 f.close()
end
for _,version in ipairs{'red','crystal'} do
 require('src.core.GameVersion').set(version)
 local base=require('src.battle.MoveEffects').RECORDS.THRASH_PETAL_DANCE_EFFECT
 T.eq(R.builtin('THRASH_PETAL_DANCE_EFFECT',base),base,'older generation record remains unchanged')
 local actor={thrashTurns=2};R.tick({},actor);T.eq(actor.thrashTurns,2)
end
T.finish('Five-edition native rampage duration, PP, animation, fatigue and cancellation')
