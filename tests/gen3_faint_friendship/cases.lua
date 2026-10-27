-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native actions/residuals; authored legal HP, levels and volatile scenarios.
local C={}
local scenarios={}
for _,h in ipairs({0,1,99,199,200,255})do
 for _,gap in ipairs({-1,0,1,29,30})do scenarios[#scenarios+1]={kind='hit',h=h,gap=gap}end
end
for _,kind in ipairs({'Explosion','Metronome','Bond','poison','seed','ooze','weather','perish','field'})do
 for _,gap in ipairs({-1,30})do scenarios[#scenarios+1]={kind=kind,h=200,gap=gap}end
end
for _,kind in ipairs({'aliases','default','egg','hook levels','absent player'})do
 scenarios[#scenarios+1]={kind=kind,h=199,gap=kind=='hook levels'and 0 or 30}
end
function C.run(root,backend,edition,mode,disableOwner)
 local rows={}
 for _,cfg in ipairs(scenarios)do
  local f=dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,edition,3,'unified',false,false,
   'portable_enemy_action',function(data,_,_,rom,names)
    if backend=='gen1'then
     for number,effect in pairs({[69]=87,[153]=7})do
      rom[number]={effect=effect,power=number==153 and 200 or 1,type=0,accuracy=100,pp=40,target=number==153 and 32 or 0,flags=51,secondaryChance=0,priority=0}
      data.gen3Moves._rom[number]=rom[number];data.gen3Pokemon._moveNames[number],names[number]='ACTION','ACTION'
     end
     rom[118]={effect=83,power=0,type=0,accuracy=0,pp=40,target=0,flags=0,secondaryChance=0,priority=0}
     data.gen3Moves._rom[118]=rom[118];data.gen3Pokemon._moveNames[118],names[118]='METRONOME','METRONOME'
    else
     for id,number in pairs({HIT=69,EXPLOSION=153})do
      data.moves[id]={id=id,index=number,name=id,gen3Effect=number==153 and 7 or 87,effect=number==153 and'EXPLODE_EFFECT'or'SPECIAL_DAMAGE_EFFECT',power=number==153 and 200 or 1,type='NORMAL',accuracy=100,pp=40,target=number==153 and 32 or 0,flags=51,secondaryChance=0}
     end
     data.constants.generation=3
     data.moves.METRONOME={id='METRONOME',index=118,name='METRONOME',gen3Effect=83,effect='METRONOME_EFFECT',power=0,type='NORMAL',accuracy=0,pp=40,target=0,flags=0}
     data.constants.moveOrder={'EXPLOSION'} -- deliberately authored caller pool
    end
   end,function(files)files['mods/portable_enemy_action/main.lua']='return function(mod)mod.exports.api=mod end'end)
  local c=f.fresh('TACKLE');local b=c.battle;local ref=backend=='gen1'
  if not ref then b:syncSides()end
  if not ref and disableOwner then require('src.battle.Gen3FaintFriendship').apply=function()end end
  b.double=mode~='single'
  local copy=require('src.mods.Merge').deepCopy
  if b.double then
   for id=2,3 do
    local mon=copy((id==2 and c.user or c.target).mon)
    if ref then b.battlers[id]=require('src.core.game3.battle.state').makeBattler(mon,id==2 and'player'or'enemy',{id=id,partyIndex=2})
    else b:placeBattler(id,require('src.battle.BattleState').makeBattler(f.data,mon,id==2))end
   end
  end
  local function actor(id)return ref and b.battlers[id]or not ref and b:battlerAt(id)end
  local function remove(id)if ref then b.battlers[id]=nil;b.absent=b.absent or{};b.absent[id]=true else b:placeBattler(id,nil);b:syncSides()end end
  if mode=='right-empty-left'then remove(1)end
  if cfg.kind=='absent player'and b.double then remove(0)end
  local player,foe=actor(b.double and 2 or 0),actor(b.double and 3 or 1)
  for id=0,3 do
   local a=actor(id)
   if a then
    a.mon.nickname='SLOT'..id;a.mon.hp=400;a.mon.level=id%2==0 and 10 or 90
    a.mon.friendship,a.mon.happiness=cfg.h,cfg.h
    if ref then
     a.type1,a.type2,a.ability=0,0,0;a.mon.maxHp=400
     a.mon.attack,a.mon.defense,a.mon.spAtk,a.mon.spDef,a.mon.speed=50,50,50,50,200-id*20
     a.mon.moves,a.mon.pp,a.mon.maxPp={69},{40},{40}
    else
     a.curTypes,a.abilityOverride={'NORMAL'},false;a.mon.stats.hp=400
     for _,key in ipairs({'attack','defense','special','spatk','spdef'})do a.mon.stats[key],a.curStats[key]=50,50 end
     a.mon.stats.speed,a.curStats.speed=200-id*20,200-id*20
     a.curMoves={{id='HIT',pp=40}};a.mon.moves=a.curMoves
    end
   end
  end
  player.mon.level,foe.mon.level=30,30+cfg.gap
  local reserve=copy(player.mon);reserve.hp=400
  if ref then
   b.playerParty={player.mon,reserve};b.foeParty={foe.mon,copy(reserve)}
  else b.game.save.party={player.mon,reserve};b.enemyParty={foe.mon,copy(reserve)}end
  local kind=cfg.kind
  if kind=='aliases'then player.mon.friendship,player.mon.happiness=200,1
  elseif kind=='default'then player.mon.friendship,player.mon.happiness=nil,nil
  elseif kind=='egg'then player.mon.egg=true end
  local events,draws={},{}
  b.rng=function(lo,hi)draws[#draws+1]={lo,hi};return lo end
  local function happiness(a)return a.mon.friendship or a.mon.happiness or false end
  f.e.api.events:on('happiness.changed',function(e)
   events[#events+1]={op='friendship',from=e.from,to=e.to,delta=e.delta,event=e.event,reason=e.reason}
  end)
  f.e.api.events:on('battle.fainted',function(e)
   local id=e.battler.id;local a=actor(id)
   events[#events+1]={op='faint',id=id,happiness=happiness(a),status=a.mon.status or false}
  end)
  if kind=='hook levels'then
   f.e.api.events:on('battle.damage_dealt',function()foe.mon.level=80 end)
  end
  local residual=kind=='poison'or kind=='seed'or kind=='ooze'or kind=='weather'or kind=='perish'or kind=='field'or kind=='absent player'
  if residual then
   player.mon.hp=1
   if kind=='weather'then if ref then b.weather='SAND'else b.field.weather,b.field.weatherTurns='SANDSTORM',5 end
   elseif kind=='perish'then player[ref and'expPerishTurns'or'perishTurns']=0
   elseif kind=='seed'or kind=='ooze'then
    local victim,source=kind=='ooze'and foe or player,kind=='ooze'and player or foe
    victim[ref and'expSeeded'or'leechSeeded']=true
    victim[ref and'expSeedSource'or'leechSeedSource']=source
    if kind=='ooze'then if ref then victim.ability=64 else victim.abilityOverride='LIQUID_OOZE'end end
   elseif kind=='field'then
    f.e.api.hooks:wrap('battle.field_residual',function()return{{side='player',battlerId=b.double and 2 or 0,amount=1}}end)
   else player.mon.status='PSN'end
   if ref then
    require('src.core.game3.battle.engine')
    require('src.core.game3.battle.residuals').runTurn(require('src.core.game3.battle.adapter').new(b))
   else b:endOfTurn()end
  else
   local user,target=foe,player;player.mon.hp=1
   local number=69
   if kind=='Explosion'or kind=='Metronome'then user,target=player,foe;player.mon.hp=400;number=153
   elseif kind=='Bond'then user,target=player,foe;player.mon.hp,foe.mon.hp=400,1;foe[ref and'expDestinyBond'or'destinyBond']=true end
   if ref then
    if kind=='Metronome'then
     b.moveMax=153;b.moveExcluded={};for id=1,152 do b.moveExcluded[id]=true end
     number=118
    end
    user.mon.moves={number}
    require('src.core.game3.battle.engine').resolveMove(user,target,number,1,require('src.core.game3.battle.adapter').new(b),b,{}, {noRetarget=true})
   else
    user.curMoves={{id=kind=='Metronome'and'METRONOME'or number==153 and'EXPLOSION'or'HIT',pp=40}};user.mon.moves=user.curMoves
    b:executeAction(user,target,user.curMoves[1])
   end
  end
  rows[#rows+1]={profile=kind..'/'..tostring(cfg.h)..'/'..tostring(cfg.gap),high=false,
   happiness=happiness(player),alias=player.mon.happiness or false,hp=player.mon.hp,status=player.mon.status or false,events=events,rng=draws}
  f.close()
 end
 return rows
end
return C
