-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local C={}
function C.run(root,backend,edition,mode,hookPolicy)
mode=mode or'single';hookPolicy=hookPolicy or'delegate'
local imported=backend=='gen2' and dofile(root..'/tests/gen3_fixed_damage/imported.lua').read()or nil
local defs={
 {82,'DRAGON_RAGE',41,'SPECIAL_DAMAGE_EFFECT',1},
 {49,'SONICBOOM',130,'SPECIAL_DAMAGE_EFFECT',1},
 {69,'SEISMIC_TOSS',87,'SPECIAL_DAMAGE_EFFECT',1},
 {101,'NIGHT_SHADE',87,'SPECIAL_DAMAGE_EFFECT',1},
 {149,'PSYWAVE',88,'SPECIAL_DAMAGE_EFFECT',1},
}
local profiles={'normal','immunity','substitute','endure','endure substitute','band nonlethal','band lethal',
 'band immune','band substitute','low HP user','armor','miss','resisted','double resist','super effective','identified','special type','wonder guard','wonder super','wonder mixed','levitate','zero power'}
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
       rom[n]={effect=effect,power=power,type=0,accuracy=accuracy,pp=40,target=0,priority=0,flags=51,secondaryChance=0}
       data.gen3Moves._rom[n]=rom[n];data.gen3Pokemon._moveNames[n]=name;names[n]=name
      else
       local id=('MOVE_%03d'):format(n)
       data.moves[id]=require('src.mods.Merge').deepCopy(assert(imported[id]));data.moves[id].accuracy=accuracy
      end
     end
     if backend=='gen2'then
      data.constants.generation=3;data.type_chart.types=data.type_chart.types or{}
      for name,index in pairs({NORMAL=0,GHOST=7,ROCK=5,STEEL=8,BUG=6,FIGHTING=1,GROUND=4,ELECTRIC=13})do
       data.type_chart.types[name]={id=name,index=index,category=index>=9 and'special'or'physical'}
      end
      for _,row in ipairs({{'NORMAL','ROCK',5},{'NORMAL','STEEL',5},{'FIGHTING','ROCK',20},{'FIGHTING','BUG',5}})do
       data.type_chart.matchups[#data.type_chart.matchups+1]={attacker=row[1],defender=row[2],multiplier=row[3]}
      end
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
    if profile=='band lethal'then target.mon.hp=1 end
   end
   if profile=='immunity'or profile=='band immune'then
    if backend=='gen1' then target.type1,target.type2=7,7 else target.curTypes={'GHOST'}end
   end
   if profile=='armor'then
    if backend=='gen1'then target.ability=4 else target.abilityOverride='BATTLE_ARMOR'end
   end
   if profile=='low HP user'then user.mon.hp=25 end
   local function targetTypes(first,second)
    if backend=='gen1' then target.type1,target.type2=first,second or first
    else
     local names={[0]='NORMAL',[1]='FIGHTING',[4]='GROUND',[5]='ROCK',[6]='BUG',[7]='GHOST',[8]='STEEL',[13]='ELECTRIC'}
     target.curTypes={names[first],names[second or first]}
    end
   end
   local function moveType(number,name)
    if backend=='gen1'then f.data.gen3Moves._rom[def[1]].type=number
    else f.data.moves[('MOVE_%03d'):format(def[1])].type=name end
   end
   if profile=='resisted'then targetTypes(5)
   elseif profile=='double resist'then targetTypes(5,8)
   elseif profile=='super effective'or profile=='wonder super'then moveType(1,'FIGHTING');targetTypes(5)
   elseif profile=='wonder mixed'then moveType(1,'FIGHTING');targetTypes(5,6)
   elseif profile=='identified'then targetTypes(7);target[backend=='gen1'and'expIdentified'or'identified']=true
   elseif profile=='special type'then moveType(13,'ELECTRIC')
   elseif profile=='levitate'then moveType(4,'GROUND');if backend=='gen1'then target.ability=26 else target.abilityOverride='LEVITATE'end end
   if profile=='zero power'then
    if backend=='gen1' then f.data.gen3Moves._rom[def[1]].power=0
    else f.data.moves[('MOVE_%03d'):format(def[1])].power=0 end
   end
   if profile:find('wonder',1,true)then if backend=='gen1'then target.ability=25 else target.abilityOverride='WONDER_GUARD'end end
   local rng,calcs,events={},{},{}
   local psyDraws=0
   b.rng=function(lo,hi)
    local v=high and(hi or lo or 0)or(lo or 0)
    if def[1]==149 and lo==0 and hi==15 and high then
     psyDraws=psyDraws+1;v=psyDraws<=2 and 16-psyDraws or 10
    end
    rng[#rng+1]={lo=value(lo),hi=value(hi),value=v};return v
   end
   f.e.api.hooks:wrap('battle.damage',function(nextDamage,ctx)
    local before=#rng;local damage,info=nextDamage(ctx)
    calcs[#calcs+1]={damage=damage,drawsBefore=before,drawsAfter=#rng,crit=info and(info.critical or info.crit)or false,
     typeMult=info and(info.effectiveness and math.floor(info.effectiveness*10+0.5)or info.typeMult)or false,
     deferAdjustment=value(ctx.opts and ctx.opts.deferAdjustment),psywaveRoll=value(ctx.opts and ctx.opts.psywaveRoll)}
    if hookPolicy=='amount-only'then return 9 end
    return damage,info
   end)
   f.e.api.events:on('battle.damage_dealt',function(e)
    events[#events+1]={damage=e.damage,draws=#rng,substitute=e.substitute==true,kind=e.kind,crit=e.crit==true}
   end)
   local before={hp=target.mon.hp,substitute=target.substituteHP or 0}
   local historyBefore=target.expLastLandedMove
   local ok,why=pcall(function()
    if backend=='gen1' then
     require('src.core.game3.battle.engine').resolveMove(user,target,def[1],1,
      require('src.core.game3.battle.adapter').new(b),b,{}, {})
    else b:performMove(user,target,user.curMoves[1])end
   end)
   rows[#rows+1]={case=def[2]..'/'..profile..'/'..tostring(high),move=def[2],number=def[1],profile=profile,high=high,ok=ok,error=not ok and tostring(why)or false,
    before=before,after={hp=target.mon.hp,substitute=target.substituteHP or 0},rng=rng,calculations=calcs,events=events,
    history={landed=value(target.expLastLandedMove),attacker=value(target.expLastHitById),kind=value(target.expLastHitByType)}}
   assert(ok,tostring(why));f.close()
  end
 end
end
return rows
end
return C
