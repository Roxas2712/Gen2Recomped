package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Wrap=require('src.battle.Gen3PartialTrap')
local moves={{20,'BIND'},{35,'WRAP'},{83,'FIRE_SPIN'},{128,'CLAMP'},{250,'WHIRLPOOL'},{328,'SAND_TOMB'}}
for _,version in ipairs({'ruby','sapphire','firered','leafgreen','emerald'})do
  local f=require('tests.enemy_actions.partial_trap').fixture(version)
  local function fresh(id,word)
    local x=f.fresh(id,{enemy=true});local b=x.battle
    b.rng=function(lo,hi)if lo==0 and hi==3 then return word or 0 end;return lo or 0 end
    b.player.mon.ability=nil;b.enemy.mon.ability=nil
    return x,b,x.user,x.target
  end
  for _,row in ipairs(moves)do for word=0,3 do
    local x,b,u,t=fresh(row[2],word)
    t.mustRecharge=true
    x.use();local hp=t.mon.hp
    T.check(hp<400,version..' '..row[2]..' actually damages')
    T.eq(x.pp(),9,'initial hit consumes one PP')
    T.eq(t.gbaWrapTurns,word+3,'native 3..6 stored counter')
    T.eq(t.gbaWrapSource,1,'target records actual physical source slot')
    T.eq(u.trappingTurns,nil,'attacker is not locked into another free move')
    T.eq(t.boundTurns,nil,'victim never receives the Gen1 cannot-move mirror')
    T.check(t.mustRecharge,'Bind no longer clears Hyper Beam recharge')
    t.mustRecharge=nil
    T.eq(b:fightLockedAction(t),nil,'bound victim can select a move')
    b.phase='menu';b:chooseMenu('fight');T.eq(b.phase,'moveSelect','actual command opens move list')
    local move={id=f.ids.TACKLE,pp=10};t.curMoves={move};t.mon.moves=t.curMoves
    local before=u.mon.hp;b:performMove(t,u,move)
    T.eq(move.pp,9,'bound victim spends ordinary move PP')
    T.check(u.mon.hp<before,'bound victim actually attacks')
    for turn=1,word+3 do
      b:endOfTurn()
      T.eq(t.mon.hp,hp-math.min(turn,word+2)*25,'wrap chip is maxHP/16, release does not damage')
      T.eq(t.gbaWrapTurns,turn<word+3 and(word+3-turn)or nil,'native duration expires at zero')
    end
    T.eq(t.gbaWrapMove,nil,'expiration clears move identity')
    T.eq(t.gbaWrapSource,nil,'expiration clears source identity')
  end end
  for _,kind in ipairs({'protected','substitute','broken_substitute','immune','fainted'})do
    local x,b,u,t=fresh('BIND')
    if kind=='protected'then t.protecting=true
    elseif kind=='substitute'then t.substituteHP=999
    elseif kind=='broken_substitute'then t.substituteHP=1
    elseif kind=='immune'then t.curTypes={'GHOST'}
    else t.mon.hp=1 end
    x.use();T.eq(t.gbaWrapTurns,nil,kind..' target is not bound')
  end
  do
    local x,b,u,t=fresh('BIND',3);x.use();local turns=t.gbaWrapTurns
    local draws=0;b.rng=function(lo,hi)if lo==0 and hi==3 then draws=draws+1 end;return lo or 0 end
    x.use();T.eq(t.gbaWrapTurns,turns,'repeated hit never refreshes a current binding')
    T.eq(draws,0,'already-bound target draws no second duration')
    local actual=b.player.mon;b.phase='menu';b:resolveSwitch({})
    T.check(b.player.mon==actual and b.phase=='messages','ordinary switch is refused before replacement')
    T.eq(t.gbaWrapTurns,turns,'refused switch does not clear binding')
    local host=Wrap.signature(t,'host');t.gbaWrapSource=0
    T.eq(Wrap.signature(t,'guest'),host,'link source positions are perspective-canonical')
    t.gbaWrapSource=1
    b:abilitySwitchOut(u);T.eq(t.gbaWrapTurns,nil,'actual source switch frees victim')
  end
  do
    local x,b,u,t=fresh('BIND');x.use();u.mon.hp=0;b:onFaint(u)
    T.eq(t.gbaWrapTurns,nil,'source faint frees victim before residual damage or replacement')
    local hp=t.mon.hp;b:endOfTurn();T.eq(t.mon.hp,hp,'a fainted source deals no further binding chip')
  end
  do
    local x,b,u,t=fresh('BIND');x.use();b.phase='menu';b:tryRun()
    T.eq(b.result,nil,'ordinary RUN cannot escape binding')
    t.abilityOverride='RUN_AWAY';b:tryRun();T.eq(b.result,'run','Run Away bypasses binding')
    x,b,u,t=fresh('BIND');x.use();t.mon.item='SMOKE_BALL';b:tryRun()
    T.eq(b.result,'run','native Smoke Ball bypasses binding')
  end
  do
    local x,b,u,t=fresh('BIND');x.use()
    local spin={id='RAPID_SPIN',pp=10};t.curMoves={spin};t.mon.moves=t.curMoves
    b:performMove(t,u,spin);T.eq(t.gbaWrapTurns,nil,'successful Rapid Spin frees binding')
    x,b,u,t=fresh('BIND');x.use();u.curTypes={'GHOST'}
    spin={id='RAPID_SPIN',pp=10};t.curMoves={spin};t.mon.moves=t.curMoves
    b:performMove(t,u,spin);T.check(Wrap.active(t),'immune Rapid Spin does not free binding')
    local first,second=u,t
    local other=require('src.battle.BattleState').makeBattler(f.data,require('src.mods.Merge').deepCopy(t.mon),true,nil,b)
    other.position=2;other.gbaWrapTurns=5;other.gbaWrapMove='WRAP';other.gbaWrapSource=3
    local actors=b.activeBattlers
    b.activeBattlers=function()local i=0;local list={first,second,other};return function()i=i+1;if list[i]then return i-1,list[i]end end end
    Wrap.switchOut(b,u)
    T.eq(second.gbaWrapTurns,nil,'double source cleanup clears its own target')
    T.eq(other.gbaWrapTurns,5,'double source cleanup preserves another battler\'s binding')
    b.activeBattlers=actors
  end
  f.close()
end
do
  V.set('red')
  local base=require('src.battle.MoveEffects').RECORDS.TRAPPING_EFFECT
  T.eq(Wrap.builtin('TRAPPING_EFFECT',base),base,'Gen1 builtin keeps its original record')
  V.set('crystal');T.eq(Wrap.builtin('TRAPPING_EFFECT',base),base,'Gen2 pipeline stays unchanged')
end
T.finish('five-edition native binding attacks, residuals, escape and source lifecycle')
