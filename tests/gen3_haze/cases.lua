-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Actual Haze actions, including public builtin delegation and overrides.
local C={}
function C.run(root,backend,edition,mode,policies)
 local rows={}
 for _,policy in ipairs(policies or {'native','delegate','override'})do
  local f=dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,edition,3,'unified',false,false,'portable_enemy_action',function(data,_,_,rom,names)
   if backend=='gen1'then
    rom[114]={effect=25,power=0,type=15,accuracy=100,pp=20,target=64,priority=0,flags=0,secondaryChance=0}
    data.gen3Moves._rom[114]=rom[114];names[114]='HAZE';data.gen3Pokemon._moveNames[114]='HAZE'
   else
    data.moves.MOVE_114={id='MOVE_114',index=114,name='HAZE',effect='HAZE_EFFECT',gen3Effect=25,type='ICE',power=0,accuracy=100,pp=20,target=64}
   end
  end,function(files)
   local code='return function(mod) mod.exports.calls=0; mod.exports.api=mod; '
   if policy~='native'then
    code=code..'local base=assert(mod.content.move_effects:get("HAZE_EFFECT"));local run=base.run;'
      ..'base.run=function(ctx) mod.exports.calls=mod.exports.calls+1;'
      ..(policy=='delegate'and'return run(ctx)'or'return {"CUSTOM HAZE"},true')
      ..' end;assert(mod.content.move_effects:override("HAZE_EFFECT",base));'
   end
   files['mods/portable_enemy_action/main.lua']=code..'end'
  end)
  local copy=require('src.mods.Merge').deepCopy
  local State,Adapter,Engine,oldSink
  if backend=='gen1'then
   State,Adapter=require('src.core.game3.battle.state'),require('src.core.game3.battle.adapter')
   Engine=require('src.core.game3.battle.engine');oldSink,Adapter.textSink=Adapter.textSink,function(id)return id end
  end
  for _,status in ipairs({'SLP','FRZ','PSN','PAR','BRN'})do
   local b=f.fresh('TACKLE').battle
   if mode~='single'then
    local players,foes={b.player.mon,copy(b.player.mon)},{b.enemy.mon,copy(b.enemy.mon)}
    if backend=='gen1'then b=State.new({wild=false,double=true,playerParty=players,foeParty=foes})
    else
     b.kind,b.trainer,b.enemyParty='trainer',{name='HAZE FIXTURE',items={}},foes;b:syncSides()
     f.game.save.party,b.playerParty,b.playerPartyIndices=players,players,{1,2};b.double=true;b:sendOutSecondPair()
    end
   end
   if mode=='double-right-empty-left'or mode=='double-left-empty-right'then
    local pos=mode=='double-right-empty-left'and 1 or 3
    if backend=='gen1'then b.battlers[pos]=nil;b.absent=b.absent or{};b.absent[pos]=true
    else b:placeBattler(pos,nil);b:syncSides()end
   end
   if backend=='gen2' then b:syncSides()end
   local caster=mode=='double-right'and 3 or mode=='double-left'and 1 or 0
   local target=caster~=0 and 0 or mode=='double-right-empty-left'and 3 or 1
   local function at(pos)
    if backend=='gen1'then return State.isPresent(b,pos)and State.battler(b,pos)or nil end
    return b:battlerAt(pos)
   end
   local function side(actor)
    return backend=='gen1'and(actor.side=='player'and b.playerSide or b.enemySide)or b.sides[actor.isPlayer and 1 or 2]
   end
   local keys=backend=='gen1'and{'attack','defense','speed','spAtk','spDef','accuracy','evasion'}or{'attack','defense','speed','spatk','spdef','accuracy','evasion'}
   local pointers={}
   for pos=0,3 do
    local actor=at(pos)
    if actor then
     pointers[pos]=actor.stages
     for i,key in ipairs(keys)do actor.stages[key]=({1,-2,3,-4,5,-6,1})[i]end
     actor.focusEnergy=true;actor.xAccuracy=true
     if backend=='gen1'then
      actor.expFocusEnergy=true
      local own=side(actor);own.expReflectTurns,own.expLightScreenTurns,own.expMistTurns,own.expSafeguardTurns=3,2,5,4
     else
      actor.reflect,actor.lightScreen=true,true;side(actor).gen3MistTurns=5
     end
     if pos~=caster then
      actor.mon.status,actor.status=status,status;actor.toxicCounter=3;actor.sleepTurns=3;actor.substituteHP=30
      if backend=='gen1'then
       actor.confusionTurns,actor.expSeeded,actor.expSeedSource=3,true,at(caster)
       actor.expNightmare,actor.expInfatuated=true,true
       actor.expDisabledMove,actor.expDisableTurns=33,4
      else
       actor.confusedTurns,actor.leechSeeded=3,true;actor.nightmare,actor.infatuated=true,true
       actor.disabledMove,actor.disabledTurns=f.ids.TACKLE,4
      end
     end
    end
   end
   if backend=='gen2' then require('src.battle.Gen3Mist').sync(b)end
   local function snapshot()
    local states={}
    for pos=0,3 do
     local actor=at(pos)
     if actor then
      local values={};for i,key in ipairs(keys)do values[i]=actor.stages[key]or 0 end
      local own=side(actor)
      states[#states+1]={position=pos,stages=values,stageTableSame=actor.stages==pointers[pos],status=actor.mon.status or false,
       confusion=(backend=='gen1'and actor.confusionTurns or actor.confusedTurns)or 0,
       seeded=not not(backend=='gen1'and actor.expSeeded or actor.leechSeeded),toxic=actor.toxicCounter or 0,
       focus=not not actor.focusEnergy,xAccuracy=not not actor.xAccuracy,substituteHP=actor.substituteHP or 0,
       nightmare=not not(backend=='gen1'and actor.expNightmare or actor.nightmare),infatuated=not not(backend=='gen1'and actor.expInfatuated or actor.infatuated),
       disabled=not not(backend=='gen1'and actor.expDisabledMove or actor.disabledMove),disabledTurns=(backend=='gen1'and actor.expDisableTurns or actor.disabledTurns)or 0,
       reflect=backend=='gen1'and(own.expReflectTurns or 0)>0 or backend=='gen2'and not not actor.reflect,
       lightScreen=backend=='gen1'and(own.expLightScreenTurns or 0)>0 or backend=='gen2'and not not actor.lightScreen,
       mist=(own[backend=='gen1'and'expMistTurns'or'gen3MistTurns'])or 0,
       skipMove=not not actor.skipMove,penaltyLifted=not not actor.hazeStatReset}
     end
    end
    return states
   end
   local before=snapshot();local user,foe=assert(at(caster)),assert(at(target))
   b.rng=function(lo)return lo or 0 end
   local previousCalls=f.e.calls
   if backend=='gen1'then
    user.mon.moves,user.mon.pp,user.mon.maxPp={114},{20},{20}
    Engine.resolveMove(user,foe,114,1,Adapter.new(b),b,{}, {})
   else
    local inst={id='MOVE_114',pp=20};user.mon.moves,user.curMoves={inst},{inst}
    b:executeAction(user,foe,inst)
   end
   local after=snapshot()
   for i,state in ipairs(after)do
    local expected=copy(before[i]);if policy~='override'then for j in ipairs(expected.stages)do expected.stages[j]=0 end end
    f.T.same(state,expected,policy..'/'..status..'/'..state.position..': only active stage values change')
   end
   local calls=f.e.calls-previousCalls
   f.T.eq(calls,policy=='native'and 0 or 1,'actual public effect wrapper invoked once')
   local pp=backend=='gen1'and user.mon.pp[1]or user.mon.moves[1].pp
   f.T.eq(pp,19,'actual Haze action owns one PP use')
   rows[#rows+1]={policy=policy,status=status,states=after,calls=calls,pp=pp}
  end
  if Adapter then Adapter.textSink=oldSink end
  f.close()
 end
 return rows,require('tests.modkit')
end
return C
