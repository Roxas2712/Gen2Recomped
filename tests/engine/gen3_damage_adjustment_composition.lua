-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=dofile('tests/charge_required/fixture.lua')
local function fixture(edition,mode,explosion)
 local f=Fixture.new('.','gen2',edition,3,'unified',false,false,'portable_enemy_action',function(data)
  data.moves.ACTION={id='ACTION',index=explosion and 153 or 206,name='ACTION',gen3Effect=explosion and 7 or 101,
   effect=explosion and 'EXPLODE_EFFECT'or 'FALSE_SWIPE_EFFECT',type='NORMAL',power=40,accuracy=100,pp=40,target=0,flags=51}
 end,function(files)
  files['mods/portable_enemy_action/main.lua']=[[return function(mod)
   mod.exports.api=mod;mod.exports.calls=0
   local name=]]..string.format('%q',explosion and 'EXPLODE_EFFECT'or 'FALSE_SWIPE_EFFECT')..[[
   local base=assert(mod.content.move_effects:get(name))
   local choose=base.chooseDamage
   base.chooseDamage=function(ctx)
    mod.exports.calls=mod.exports.calls+1
    ]]..(mode=='override'and'return 7,{crit=false,typeMult=10}'or'return choose(ctx)')..[[
   end
   assert(mod.content.move_effects:override(name,base))
  end]]
 end)
 local c=f.fresh('TACKLE');local b=c.battle;b:syncSides()
 for _,actor in ipairs({c.user,c.target})do
  actor.mon.hp,actor.mon.stats.hp=400,400;actor.curTypes={'NORMAL'};actor.abilityOverride=false
  actor.curMoves={{id='ACTION',pp=40}};actor.mon.moves=actor.curMoves
 end
 return f,c
end
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'delegate','override'})do
  local f,c=fixture(edition,mode,false);local b=c.battle
  local called=0;local metadata
  b.rng=function(lo)return lo or 0 end
  f.e.api.hooks:wrap('battle.damage',function(nextDamage,ctx)
   called=called+1
   local damage,info=nextDamage(ctx);metadata=info
   return 9 -- a delegated amount-only hook retains the real calculation metadata
  end)
  b:executeAction(c.user,c.target,c.user.curMoves[1])
  T.eq(c.target.mon.hp,400-(mode=='override'and 7 or 9),'public complete override and delegation retain their own amount')
  T.eq(f.e.calls,1,'captured public effect record executes once')
  T.eq(called,mode=='override'and 0 or 1,'complete authored replacement bypasses native calculation')
  T.eq(b._gbaDamageCalculation,nil,'calculation ownership is released at action end')
  if metadata then
   T.eq(metadata.damageAdjustment,nil,'adjustment never mutates the hook-owned result table')
  end
  f.close()
 end
 for _,value in ipairs({{7,7},{-3.5,0},{'12.9',12},{false,0}})do
  local f,c=fixture(edition,'delegate',false);local b=c.battle
  local draws,events={},{}
  b.rng=function(lo,hi)draws[#draws+1]={lo,hi};return lo or 0 end
  f.e.api.hooks:wrap('battle.damage',function()return value[1]end)
  f.e.api.events:on('battle.damage_dealt',function(e)events[#events+1]=e end)
  b:executeAction(c.user,c.target,c.user.curMoves[1])
  T.eq(c.target.mon.hp,400-value[2],'complete native hook owns and normalizes its amount without delegation')
  T.eq(#events,1,'even an explicit zero result reaches the native HP command')
  T.eq(events[1].kind,'physical','missing native hook metadata infers the category from the actual move type')
  T.eq(events[1].crit,false,'complete replacement has no invented critical')
  T.eq(draws[1][1],1,'actual action still runs accuracy')
  local rs=edition=='ruby'or edition=='sapphire'
  T.eq(#draws,rs and 2 or 1,'complete hook never causes a hidden critical/calculation draw')
  if rs then T.same(draws[2],{0,15},'R/S still reaches its later adjustment command')end
  T.eq(b._gbaDamageCalculation,nil,'complete hook retires the native calculation owner')
  f.close()
 end
 -- A complete authored Explosion calculation retains its original pre-hit
 -- ownership; the native special-script prefix must not run around it.
 local f,c=fixture(edition,'override',true);local b=c.battle
 c.target.protecting=true
 b:executeAction(c.user,c.target,c.user.curMoves[1])
 T.eq(c.user.mon.hp,400,'custom Explosion does not inherit the native self-HP prefix')
 T.eq(f.e.calls,0,'protection prevents the custom calculation')
 f.close()
 -- Explosion's native prefix does not enter hit_once's failed-info branch.
 -- A shared hook can attach that field without changing this special body.
 local f,c=fixture(edition,'delegate',false);local b=c.battle
 local move=f.data.moves.ACTION
 move.index,move.gen3Effect,move.effect=153,7,'EXPLODE_EFFECT'
 move.power=200
 b.rng=function(lo)return lo or 0 end
 f.e.api.hooks:wrap('battle.damage',function()
  return 7,{crit=false,typeMult=10,failed=true,typeFlags={super=false,notVery=false,immune=false}}
 end)
 b:executeAction(c.user,c.target,c.user.curMoves[1])
 T.eq(c.target.mon.hp,393,'native Explosion retains its special calculation-result owner')
 T.eq(c.user.mon.hp,0,'native special body still reaches self faint')
 f.close()
end
for _,edition in ipairs({'red','gold'})do
 for _,flag in ipairs({false,true})do
  local f=Fixture.new('.','gen2',edition,3,'unified',false,false,'portable_enemy_action',nil,function(files)
   files['mods/portable_enemy_action/main.lua']='return function(mod)mod.exports.api=mod end'
  end)
  local c=f.fresh('TACKLE');c.battle:syncSides()
  f.e.api.hooks:wrap('battle.damage',function()return 7,{crit=false,typeMult=10,failed=flag}end)
  c.battle:executeAction(c.user,c.target,c.user.curMoves[1])
  T.eq(c.target.mon.hp,393,'older generations retain ownership of extra hook metadata')
  f.close()
 end
end
for _,edition in ipairs({'red','gold'})do
 require('src.core.GameVersion').set(edition)
 local records=require('src.battle.MoveEffects').RECORDS
 for _,name in ipairs({'FALSE_SWIPE_EFFECT','EXPLODE_EFFECT','JUMP_KICK_EFFECT'})do
  T.eq(require('src.battle.Gen3Builtins').record(name,records[name]),records[name],'older generations retain the original record identity')
 end
end
T.finish('native adjustment public delegation, complete ownership, metadata isolation and older generations')
