-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Actual native actions and hook boundaries on shared authored move records.
package.path='./?.lua;./?/init.lua;'..package.path
local C={}
function C.run(root,backend,edition,mode,hookPolicy)
mode=mode or 'single';hookPolicy=hookPolicy or 'delegate'
local defs={
 {33,'TACKLE',0,'NO_ADDITIONAL_EFFECT',35},
 {24,'DOUBLE_KICK',44,'ATTACK_TWICE_EFFECT',10},
 {206,'FALSE_SWIPE',101,'FALSE_SWIPE_EFFECT',40},
 {82,'DRAGON_RAGE',41,'SPECIAL_DAMAGE_EFFECT',1},
 {49,'SONICBOOM',130,'SPECIAL_DAMAGE_EFFECT',1},
 {69,'SEISMIC_TOSS',87,'SPECIAL_DAMAGE_EFFECT',1},
 {149,'PSYWAVE',88,'SPECIAL_DAMAGE_EFFECT',1},
 {162,'SUPER_FANG',40,'SUPER_FANG_EFFECT',1},
 {283,'ENDEAVOR',189,'ENDEAVOR_EFFECT',1},
 {210,'FURY_CUTTER',119,'FURY_CUTTER_EFFECT',10},
 {153,'EXPLOSION',7,'EXPLODE_EFFECT',200},
 {251,'BEAT_UP',154,'BEAT_UP_EFFECT',10},
 {26,'JUMP_KICK',45,'JUMP_KICK_EFFECT',70},
}
local profiles={'normal','immunity','substitute','endure','endure substitute','band nonlethal','band lethal',
 'band immune','band substitute','low HP user','armor','miss','band sticky','band sticky later lethal','protect','band protect','levitate','wonder guard','damp','confused','confused band','confused endure','confused substitute','tiny resist'}
local rows={}
local function value(v)if v==nil then return false end;return v end
for _,def in ipairs(defs)do
 for _,profile in ipairs(profiles)do
  for _,high in ipairs({false,true})do
   local f=dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,edition,3,'unified',false,false,
    'portable_enemy_action',function(data,_,_,rom,names)
     for _,row in ipairs(defs)do
      local n,name,effect,host,power=unpack(row)
      local accuracy=profile=='miss'and 1 or 100
      if backend=='gen1'then
       rom[n]={effect=effect,power=power,type=profile=='levitate'and 4 or 0,accuracy=accuracy,pp=40,target=0,priority=0,flags=51,secondaryChance=0}
       data.gen3Moves._rom[n]=rom[n];data.gen3Pokemon._moveNames[n]=name;names[n]=name
      else
       local id=('MOVE_%03d'):format(n)
       data.moves[id]={id=id,index=n,name=name,effect=host,gen3Effect=effect,type=profile=='levitate'and'GROUND'or'NORMAL',gen3Type=profile=='levitate'and 4 or 0,
        power=power,accuracy=accuracy,pp=40,target=0,priority=0,flags=51,secondaryChance=0}
      end
     end
     if backend=='gen1' then
      data.gen3Pokemon._stats[4]={hp=50,atk=50,def=50,spe=50,spa=50,spd=50}
     else
      data.pokemon.CHARMANDER.baseStats={hp=50,attack=50,defense=50,speed=50,special=50,spatk=50,spdef=50}
     end
     if backend=='gen2' then
      data.constants.generation=3;data.type_chart.types=data.type_chart.types or{}
      for name,index in pairs({NORMAL=0,GHOST=7,GROUND=4,ROCK=5,STEEL=8})do
       data.type_chart.types[name]={id=name,index=index,category='physical'}
      end
      data.type_chart.matchups[#data.type_chart.matchups+1]={attacker='NORMAL',defender='ROCK',multiplier=5}
      data.type_chart.matchups[#data.type_chart.matchups+1]={attacker='NORMAL',defender='STEEL',multiplier=5}
      data.type_chart.matchups[#data.type_chart.matchups+1]={attacker='NORMAL',defender='GHOST',multiplier=0}
      data.items.ITEM_196={id='ITEM_196',index=196,name='FOCUS BAND',holdEffect='FOCUS_BAND',gen3HoldEffect=39,holdEffectParam=10}
     end
    end,function(files)files['mods/portable_enemy_action/main.lua']='return function(mod)mod.exports.api=mod end'end)
   local c=f.fresh('TACKLE');local b,user,target=c.battle,c.user,c.target
   if backend=='gen2'then b:syncSides()end
   if mode~='single'then
    b.double=true
    local copy=require('src.mods.Merge').deepCopy
    for pos=2,3 do
     local template=pos==2 and user or target
     if backend=='gen1' then
      b.battlers[pos]=require('src.core.game3.battle.state').makeBattler(copy(template.mon),pos==2 and'player'or'enemy',{id=pos,partyIndex=2})
     else b:placeBattler(pos,require('src.battle.BattleState').makeBattler(f.data,copy(template.mon),pos==2))end
    end
    if backend=='gen1'then user,target=b.battlers[2],b.battlers[3]
    else b:syncSides();user,target=b:battlerAt(2),b:battlerAt(3)end
    if mode=='right-empty-left'then
     if backend=='gen1'then b.battlers[1]=nil;b.absent=b.absent or{};b.absent[1]=true
     else b:placeBattler(1,nil);b:syncSides()end
    end
   end
   for _,actor in ipairs({user,target})do
    actor.mon.hp,actor.mon.maxHp=400,400
    if backend=='gen1' then
     actor.type1,actor.type2,actor.ability=0,0,0
     actor.mon.attack,actor.mon.defense,actor.mon.speed,actor.mon.spAtk,actor.mon.spDef=50,50,50,50,50
     actor.mon.moves,actor.mon.pp,actor.mon.maxPp={def[1]},{40},{40}
    else
     actor.curTypes,actor.abilityOverride={'NORMAL'},false;actor.mon.stats.hp=400
     for _,stat in ipairs({'attack','defense','speed','special','spatk','spdef'})do actor.curStats[stat]=50;actor.mon.stats[stat]=50 end
     actor.mon.moves={{id=('MOVE_%03d'):format(def[1]),pp=40}};actor.curMoves=actor.mon.moves
    end
   end
   if profile:find('substitute',1,true)then target.substituteHP=100 end
   if profile:find('endure',1,true)then
    target.mon.hp=1;target[backend=='gen1'and'expEnduring'or'enduring']=true
   end
   if profile:find('band',1,true)then
    target.mon.item=backend=='gen1'and 196 or'ITEM_196'
    if backend=='gen1' then target.item=196 end
    if profile=='band lethal'or profile=='band sticky'or profile=='band protect'then target.mon.hp=1 end
   end
   if profile=='band sticky later lethal'then target.mon.hp=13 end
   if profile=='immunity'or profile=='band immune'then
    if backend=='gen1' then target.type1,target.type2=7,7 else target.curTypes={'GHOST'}end
   end
   if profile=='armor'then
    if backend=='gen1'then target.ability=4 else target.abilityOverride='BATTLE_ARMOR'end
   end
   if profile=='low HP user'then user.mon.hp=25 end
   if profile=='protect'or profile=='band protect'then target[backend=='gen1'and'expProtected'or'protecting']=true end
   if profile=='levitate'then if backend=='gen1'then target.ability=26 else target.abilityOverride='LEVITATE'end end
   if profile=='wonder guard'then if backend=='gen1'then target.ability=25 else target.abilityOverride='WONDER_GUARD'end end
   if profile=='damp'then if backend=='gen1'then target.ability=6 else target.abilityOverride='DAMP'end end
   if profile:find('confused',1,true)then
    user[backend=='gen1'and'confusionTurns'or'confusedTurns']=3
    if profile=='confused band'then user.mon.item=backend=='gen1'and 196 or'ITEM_196';if backend=='gen1' then user.item=196 end;user.mon.hp=1 end
    if profile=='confused endure'or profile=='confused substitute'then user.mon.hp=1;user[backend=='gen1'and'expEnduring'or'enduring']=true end
    if profile=='confused substitute'then user.substituteHP=100 end
   end
   if profile=='tiny resist'then
    if backend=='gen1' then user.mon.attack=1;target.mon.defense=2000;target.type1,target.type2=5,8
    else user.curStats.attack=1;user.mon.stats.attack=1;target.curStats.defense=2000;target.mon.stats.defense=2000;target.curTypes={'ROCK','STEEL'}end
   end
   local rng,calcs,events={},{},{}
   local bandDraws=0
   local psyDraws=0
   local function makeRng(flip)return function(lo,hi)
    local v=(high~=flip)and(hi or lo or 0)or(lo or 0)
    if def[1]==149 and lo==0 and hi==15 and high then
     psyDraws=psyDraws+1;v=psyDraws<=2 and 16-psyDraws or 10
    end
    if profile:find('band sticky',1,true)and lo==0 and hi==99 then bandDraws=bandDraws+1;v=bandDraws==1 and 0 or 99 end
    rng[#rng+1]={lo=value(lo),hi=value(hi),value=v};return v
   end end
   b.rng=makeRng(false)
   f.e.api.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if hookPolicy=='override'then return 7 end
    if hookPolicy=='rng-swap'then b.rng=makeRng(true)end
    local before=#rng;local damage,info=nextDamage(ctx)
    calcs[#calcs+1]={damage=damage,drawsBefore=before,drawsAfter=#rng,crit=info and(info.critical or info.crit)or false,
     typeMult=info and(info.effectiveness and math.floor(info.effectiveness*10+0.5)or info.typeMult)or false,userHP=user.mon.hp,
     deferAdjustment=value(ctx.opts and ctx.opts.deferAdjustment)}
    if hookPolicy=='amount-only'then return 9 end
    return damage,info
   end)
   f.e.api.events:on('battle.damage_dealt',function(e)
    events[#events+1]={damage=e.damage,draws=#rng,substitute=e.substitute==true,kind=e.kind,crit=e.crit==true}
   end)
   local before={hp=target.mon.hp,substitute=target.substituteHP or 0}
   local ok,why=pcall(function()
    if backend=='gen1' then
     require('src.core.game3.battle.engine').resolveMove(user,target,def[1],1,
      require('src.core.game3.battle.adapter').new(b),b,{}, {})
    else b:executeAction(user,target,user.curMoves[1])end
   end)
   rows[#rows+1]={move=def[2],number=def[1],profile=profile,high=high,ok=ok,error=not ok and tostring(why)or false,
    before=before,after={hp=target.mon.hp,substitute=target.substituteHP or 0,userHP=user.mon.hp,userSubstitute=user.substituteHP or 0,pp=backend=='gen1'and user.mon.pp[1]or user.curMoves[1].pp},rng=rng,calculations=calcs,events=events}
   assert(ok,tostring(why));f.close()
  end
 end
end
return rows
end
return C
