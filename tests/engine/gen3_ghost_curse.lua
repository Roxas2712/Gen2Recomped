-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 local f=require('tests.enemy_actions.fixture').new('.','gen2',edition,3,'unified',function(data,_,ids)
  ids.CURSE='CURSE'
  data.moves.CURSE={id='CURSE',index=174,name='CURSE',effect='CURSE_EFFECT',gen3Effect=109,
   type='MYSTERY',power=0,accuracy=0,pp=10,target=16,flags=0}
  data.pokemon.CHARMANDER.types={'GHOST'}
  data.pokemon.CHARMANDER.abilities={}
 end)
 local function fresh()
  local x=f.fresh('CURSE',{enemy=true})
  x.user.mon.maxHp=nil;x.target.mon.maxHp=nil
  return x,x.battle,x.user,x.target
 end
 do
  local x,b,u,t=fresh()
  T.eq(u.mon.type1,nil,'real native constructor has no legacy mon.type1')
  T.eq(u.types,nil,'real native constructor owns curTypes instead')
  x.use()
  T.eq(u.mon.hp,200,edition..' Ghost pays half its real maximum HP')
  T.eq(t.cursed,true,'Ghost Curse marks the actual opponent')
  T.eq(u.stages.attack,nil,'Ghost Curse never raises attack')
  T.eq(u.stages.defense,nil,'Ghost Curse never raises defense')
  T.eq(x.pp(),9,'Ghost Curse spends ordinary PP')
  x.use();T.eq(u.mon.hp,200,'already cursed target costs no further HP')
  T.eq(x.pp(),8,'failed repeat still spends PP')
  -- Original upkeep continues without the source, including through a doll.
  u.mon.hp=0;t.substituteHP=150
  for n=1,3 do b:endOfTurn();T.eq(t.mon.hp,400-100*n,'native turn loses one quarter maximum HP')end
  T.eq(t.substituteHP,150,'Curse does not hit the substitute')
  b:endOfTurn();T.eq(t.mon.hp,0,'Curse can actually faint its victim')
 end
 do
  local x,b,u,t=fresh();u.curTypes={'NORMAL'};u.mon.type1='GHOST'
  x.use();T.eq(t.cursed,nil,'live Conversion/Transform types override stale legacy types')
  T.eq(u.mon.hp,400,'non-Ghost Curse pays no HP')
  T.eq(u.stages.attack,1);T.eq(u.stages.defense,1);T.eq(u.stages.speed,-1)
 end
 do
  local x,b,u,t=fresh();u.mon.hp=1
  x.use();T.eq(u.mon.hp,0,'Ghost can sacrifice its last HP')
  T.eq(t.cursed,true,'sacrificial Curse still reaches the target')
 end
 do
  local x,b,u,t=fresh();x.use();t.mon.stats.hp=3;t.mon.hp=3
  b:endOfTurn();T.eq(t.mon.hp,2,'quarter HP has a minimum of one')
 end
 do
  local x,b,u,t=fresh();t.substituteHP=50
  x.use();T.eq(t.cursed,nil,'original GBA doll prevents initial Curse')
  T.eq(u.mon.hp,400,'blocked Curse never pays HP');T.eq(t.substituteHP,50)
 end
 do
  local x,b,u,t=fresh();local Targets=require('src.battle.Targeting')
  local move=f.data.moves.CURSE
  T.eq(Targets.resolve(b,u,move,u)[1],t,'Ghost self-target byte resolves to an actual foe')
  T.eq(u.thrashTarget,nil,'Curse never creates a rampage target')
  u.curTypes={'NORMAL'}
  T.eq(Targets.resolve(b,u,move,t)[1],u,'non-Ghost self-target byte still selects itself')
 end
 f.close()
end
T.finish('five-edition native Ghost Curse, live types, cost and ordinary residual turns')
