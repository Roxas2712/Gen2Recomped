-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real all-other-battlers Explosion actions; no adapter state is fabricated.
local S={}
function S.run(root,backend,edition,mode,policy,called)
 local rows={}
 for _,profile in ipairs({'normal','Damp after first','protect first','protect all','Damp ally','Damp user','Damp foe',
   'immune first','substitute first','band all','Levitate last','fainted Damp'})do
  for _,high in ipairs({false,true})do
   local f=dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,edition,3,'unified',false,false,
    'portable_enemy_action',function(data,_,_,rom,names)
     if backend=='gen1'then
      rom[153]={effect=7,power=200,type=0,accuracy=100,pp=40,target=32,flags=51,secondaryChance=0,priority=0}
      data.gen3Moves._rom[153]=rom[153];data.gen3Pokemon._moveNames[153]='EXPLOSION';names[153]='EXPLOSION'
     else
      data.moves.MOVE_153={id='MOVE_153',index=153,name='EXPLOSION',gen3Effect=7,effect='EXPLODE_EFFECT',
       power=200,type='NORMAL',accuracy=100,pp=40,target=32,flags=51,secondaryChance=0,priority=0}
      data.moves.METRONOME={id='METRONOME',index=118,name='METRONOME',gen3Effect=83,effect='METRONOME_EFFECT',
       power=0,type='NORMAL',accuracy=0,pp=40,target=0,flags=0,priority=0}
      data.constants.generation=3
      data.constants.moveOrder={'MOVE_153'} -- authored public pool, not a native selector parity claim
      data.items.ITEM_196={id='ITEM_196',index=196,name='FOCUS BAND',gen3HoldEffect=39,holdEffect='FOCUS_BAND',holdEffectParam=10}
      data.type_chart.types=data.type_chart.types or {}
      data.type_chart.types.GHOST={id='GHOST',index=7,category='physical'}
      data.type_chart.types.GROUND={id='GROUND',index=4,category='physical'}
      data.type_chart.matchups[#data.type_chart.matchups+1]={attacker='NORMAL',defender='GHOST',multiplier=0}
     end
    end,function(files)files['mods/portable_enemy_action/main.lua']='return function(mod)mod.exports.api=mod end'end)
   local c=f.fresh('TACKLE');local b=c.battle
   if backend=='gen2'then b:syncSides()end
   local double=mode~='single';b.double=double
   if double then
    local copy=require('src.mods.Merge').deepCopy
    for pos=2,3 do
     local template=pos==2 and c.user or c.target
     if backend=='gen1'then
      b.battlers[pos]=require('src.core.game3.battle.state').makeBattler(copy(template.mon),pos==2 and'player'or'enemy',{id=pos,partyIndex=2})
     else b:placeBattler(pos,require('src.battle.BattleState').makeBattler(f.data,copy(template.mon),pos==2))end
    end
   end
   if backend=='gen2'then b:syncSides()end
   local function actor(pos)if backend=='gen1' then return b.battlers[pos]end;return b:battlerAt(pos)end
   if mode=='right-empty-left'then
    if backend=='gen1'then b.battlers[1]=nil;b.absent=b.absent or{};b.absent[1]=true
    else b:placeBattler(1,nil);b:syncSides()end
   end
   local user=actor(double and 2 or 0);local target=actor(double and 3 or 1)
   local targets={}
   for pos=0,3 do
    local who=actor(pos)
    if who then
     who.mon.hp,who.mon.maxHp=400,400
     if backend=='gen1'then
      who.type1,who.type2,who.ability=0,0,0
      who.mon.attack,who.mon.defense,who.mon.speed,who.mon.spAtk,who.mon.spDef=50,50,50,50,50
      who.mon.moves,who.mon.pp,who.mon.maxPp={153},{40},{40}
     else
      who.curTypes,who.abilityOverride={'NORMAL'},false;who.mon.stats.hp=400
      for _,key in ipairs({'attack','defense','speed','special','spatk','spdef'})do who.curStats[key]=50;who.mon.stats[key]=50 end
      who.curMoves={{id='MOVE_153',pp=40}};who.mon.moves=who.curMoves
     end
     if who~=user then targets[#targets+1]=who end
    end
   end
   local first,last=targets[1],targets[#targets]
   local function ability(who,id,name)if who then
    if backend=='gen1'then who.ability=id else who.abilityOverride=name end
   end end
   local function protect(who)who[backend=='gen1'and'expProtected'or'protecting']=true end
   if profile=='protect first'then protect(first)
   elseif profile=='protect all'then for _,who in ipairs(targets)do protect(who)end
   elseif profile=='Damp ally'then ability(double and actor(0)or target,6,'DAMP')
   elseif profile=='Damp user'then ability(user,6,'DAMP')
   elseif profile=='Damp foe'then ability(target,6,'DAMP')
   elseif profile=='immune first'then
    if backend=='gen1'then first.type1,first.type2=7,7 else first.curTypes={'GHOST'}end
   elseif profile=='substitute first'then first.substituteHP=100
   elseif profile=='band all'then for _,who in ipairs(targets)do
    who.mon.hp=1;who.mon.item=backend=='gen1'and 196 or'ITEM_196';if backend=='gen1'then who.item=196 end
   end
   elseif profile=='Levitate last'then
    ability(last,26,'LEVITATE')
    if backend=='gen1'then f.data.gen3Moves._rom[153].type=4 else f.data.moves.MOVE_153.type='GROUND'end
   elseif profile=='fainted Damp'then
    local other=double and actor(0)or nil
    if other then other.mon.hp=0;ability(other,6,'DAMP')end
   end
   local rng,calculations,events={},{},{}
   local function makeRng(flip)return function(lo,hi)local value=(high~=flip)and hi or lo;rng[#rng+1]={lo=lo,hi=hi,value=value};return value end end
   b.rng=makeRng(false)
   f.e.api.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if policy=='override'then return 7 end
    if policy=='rng-swap'then b.rng=makeRng(true)end
    local before=#rng;local amount,info=nextDamage(ctx)
    calculations[#calculations+1]={damage=amount,userHP=user.mon.hp,drawsBefore=before,drawsAfter=#rng}
    if policy=='amount-only'then return 9 end
    return amount,info
   end)
   f.e.api.events:on('battle.damage_dealt',function(e)
    local pos
    for p=0,3 do if actor(p)==e.target then pos=p end end
    events[#events+1]={position=pos,damage=e.damage,draws=#rng,substitute=e.substitute==true,kind=e.kind}
    if profile=='Damp after first'and #events==1 then ability(e.target,6,'DAMP')end
   end)
   if backend=='gen1'then
    require('src.core.game3.battle.engine').resolveMove(user,target,153,1,require('src.core.game3.battle.adapter').new(b),b,{}, {})
   else
    if called then user.curMoves[1]={id='METRONOME',pp=40};user.mon.moves=user.curMoves end
    b:executeAction(user,target,user.curMoves[1])
   end
   local after={}
   for p=0,3 do local who=actor(p);after[p+1]=who and{hp=who.mon.hp,substitute=who.substituteHP or 0}or false end
   rows[#rows+1]={number=153,move='EXPLOSION',profile='spread '..profile,high=high,mode=mode,
    after=after,pp=backend=='gen1'and user.mon.pp[1]or user.curMoves[1].pp,rng=rng,calculations=calculations,events=events}
   f.close()
  end
 end
 return rows
end
return S
