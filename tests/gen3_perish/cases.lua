-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Actual public native/delegate/override effects through their native controller.
package.path='./?.lua;./?/init.lua;'..package.path
local C={}
function C.run(root,backend,edition,mode,policy)
policy=policy or'native'
assert(backend=='gen2'or policy=='native','reference public builtin ownership is host-specific')
local rows={}
local T=require('tests.modkit')
for _,case in ipairs({'ordinary','soundproof player','soundproof foe','already active','substitute'})do
 local f=dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,edition,3,'unified',false,false,'portable_enemy_action',function(data,_,_,rom,names)
  -- pret/pokeemerald src/data/battle_moves.h: Perish Song targets USER.
  if backend=='gen1'then
   rom[195]={effect=114,power=0,type=0,accuracy=0,pp=5,target=16,priority=0,flags=0,secondaryChance=0}
   data.gen3Moves._rom[195]=rom[195];names[195]='PERISH_SONG';data.gen3Pokemon._moveNames[195]='PERISH_SONG'
  else
   data.moves.MOVE_195={id='MOVE_195',index=195,name='PERISH SONG',effect='PERISH_SONG_EFFECT',gen3Effect=114,type='NORMAL',power=0,accuracy=0,pp=5,target=16,priority=0,flags=0}
  end
 end,function(files)
 local entry='return function(mod) mod.exports.api=mod;mod.exports.calls=0;'
 if policy~='native'then
  entry=entry..'local base=assert(mod.content.move_effects:get("PERISH_SONG_EFFECT"));local run=base.run;'
    ..'base.run=function(ctx) mod.exports.calls=mod.exports.calls+1;'
    ..(policy=='delegate'and'return run(ctx)'or'return {"CUSTOM PERISH SONG"},true')
    ..' end;assert(mod.content.move_effects:override("PERISH_SONG_EFFECT",base));'
 end
 files['mods/portable_enemy_action/main.lua']=entry..'end'
 end)
 local copy=require('src.mods.Merge').deepCopy
 local b=f.fresh('TACKLE').battle
 local players={b.player.mon,copy(b.player.mon),copy(b.player.mon)}
 local foes={b.enemy.mon,copy(b.enemy.mon),copy(b.enemy.mon)}
 local State,Engine,Adapter,oldSink,ad
 if backend=='gen1'then
  State,Engine=require('src.core.game3.battle.state'),require('src.core.game3.battle.engine')
  Adapter=require('src.core.game3.battle.adapter');oldSink,Adapter.textSink=Adapter.textSink,function(id)return id end
  b=State.new({wild=false,double=mode~='single',playerParty=players,foeParty=foes});ad=Adapter.new(b)
 else
  b.kind,b.trainer,b.enemyParty='trainer',{name='PERISH OBSERVATION',items={}},foes
  f.game.save.party,b.playerParty,b.playerPartyIndices=players,players,{1,2,3};b:syncSides()
  if mode~='single'then b.double=true;b:sendOutSecondPair()end
 end
 if mode=='empty-left'or mode=='empty-right'then
  local pos=mode=='empty-left'and 1 or 3
  if backend=='gen1'then b.battlers[pos]=nil;b.absent=b.absent or{};b.absent[pos]=true
  else b:placeBattler(pos,nil);b:syncSides()end
 end
 local function at(pos)
 if backend=='gen1'then return State.battler(b,pos)end
 return b:battlerAt(pos)
end
 local originals={}
 for pos=0,3 do
  local actor=at(pos)
  if actor then
   originals[pos]=actor;actor.mon.hp,actor.mon.maxHp=400,400;actor.mon.stats=actor.mon.stats or{};actor.mon.stats.hp=400
   if backend=='gen1' then actor.ability=0;actor.mon.speed=100+pos
   else actor.abilityOverride=false;actor.curStats.speed=100+pos end
  end
 end
 local user=at(0)
 local targetPosition=at(1)and 1 or 3
 local target=at(targetPosition)
 if case=='soundproof player'then
  if backend=='gen1'then user.ability=43 else user.abilityOverride='SOUNDPROOF'end
 elseif case=='soundproof foe'then
  if backend=='gen1'then target.ability=43 else target.abilityOverride='SOUNDPROOF'end
 elseif case=='already active'then
  if backend=='gen1'then target.perishSong,target.expPerishTurns=true,2 else target.perishTurns=2 end
 elseif case=='substitute'then target.substituteHP=30 end
 if backend=='gen1'then user.mon.moves,user.mon.pp,user.mon.maxPp={195},{5},{5}
 else user.mon.moves={{id='MOVE_195',pp=5}};user.curMoves=user.mon.moves end
 b.rng=function(lo)return lo or 0 end
 local function snapshot()
  local frame={}
  for pos=0,3 do
   local actor=originals[pos]
   if actor then
    local n=backend=='gen1'and actor.expPerishTurns or actor.perishTurns
    frame[#frame+1]={position=pos,present=at(pos)==actor,hp=actor.mon.hp,counter=n==nil and false or n}
   end
  end
  return frame
 end
 local initial=snapshot()
 local entry={case=case,frames={}}
 local ok,why=pcall(function()
  if backend=='gen1'then Engine.resolveMove(user,target,195,1,ad,b,{}, {})
  else b:executeAction(user,target,user.curMoves[1])end
 end)
 entry.used=ok;if not ok then entry.error=tostring(why)end
 entry.pp=backend=='gen1'and user.mon.pp[1]or user.curMoves[1].pp
 entry.frames[#entry.frames+1]=snapshot()
 if ok then
  for tick=1,3 do
   local success,reason=pcall(function()
    if backend=='gen1'then require('src.core.game3.battle.residuals').runTurn(ad)
    else b:endOfTurn()end
   end)
   entry.frames[#entry.frames+1]=snapshot()
   if not success then entry.residualError=tostring(reason);entry.failedTick=tick;break end
  end
 end
 T.eq(entry.used,true,'actual Perish effect action completes: '..policy..'/'..case)
 T.eq(entry.residualError,nil,'native residual owner completes: '..policy..'/'..case)
 T.eq(entry.pp,4,'one actual PP use per action')
 T.eq(f.e.calls,policy=='native'and 0 or 1,'public effect wrapper owns exactly one call')
 local expected=copy(initial)
 if policy~='override'then
  for _,row in ipairs(expected)do
   local immune=case=='soundproof player'and row.position==0
     or case=='soundproof foe'and row.position==targetPosition
   if not immune and row.counter==nil then row.counter=3 end
  end
 end
 T.same(entry.frames[1],expected,'effect ownership, Soundproof and no refresh: '..policy..'/'..case)
 rows[#rows+1]=entry
 if Adapter then Adapter.textSink=oldSink end
 f.close()
end
return rows
end
return C
