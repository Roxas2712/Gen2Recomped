-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local H=require('src.battle.Gen3FixedDamage')
local Base=require('src.battle.MoveEffects').RECORDS.SPECIAL_DAMAGE_EFFECT
local original=Base.chooseDamage
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'delegate','override','custom-amount','fallback'})do
  for _,number in ipairs({49,69,82,101,149})do
   local imported=dofile('tests/gen3_fixed_damage/imported.lua').read()
   local f=dofile('tests/charge_required/fixture.lua').new('.','gen2',edition,3,'unified',false,false,
    'portable_enemy_action',function(data)
     for id,row in pairs(imported)do data.moves[id]=row end
     if mode=='custom-amount'then data.moves[('MOVE_%03d'):format(number)].fixedDamage=7 end
    end,function(files)
     files['mods/portable_enemy_action/main.lua']=[[return function(mod)
      mod.exports.api=mod;mod.exports.calls=0
      local base=assert(mod.content.move_effects:get('SPECIAL_DAMAGE_EFFECT'))
      local choose=base.chooseDamage
      base.chooseDamage=function(ctx)
       mod.exports.calls=mod.exports.calls+1
       ]]..(mode=='override'and'return 7,{crit=false,typeMult=10}'or'return choose(ctx)')..[[
      end
      assert(mod.content.move_effects:override('SPECIAL_DAMAGE_EFFECT',base))
     end]]
    end)
   local c=f.fresh('TACKLE');local b=c.battle;b:syncSides()
   local saved=f.data.move_effects;if mode=='fallback'then f.data.move_effects=nil end
   local rng={};b.rng=function(lo,hi)rng[#rng+1]={lo,hi};return lo or 0 end
   local calculations=0;f.e.api.hooks:wrap('battle.damage',function(nextDamage,ctx)calculations=calculations+1;return nextDamage(ctx)end)
   local before=c.target.mon.hp;b:performMove(c.user,c.target,{id=('MOVE_%03d'):format(number),pp=40})
   local custom=mode=='override'or mode=='custom-amount'
   local expected=custom and 7 or({[49]=20,[69]=30,[82]=40,[101]=30,[149]=15})[number]
   T.eq(c.target.mon.hp,before-expected,'public effect delegation/override owns its fixed amount')
   T.eq(calculations,custom and 0 or 1,'authored fixed amounts retain their original calculation ownership')
   T.eq(f.e.calls,mode=='fallback'and 0 or 1,'complete registry dispatch retains the authored handler')
   if custom then
    -- The authored amount owns calculation, while the selected R/S script
    -- still reaches its zero-effect chance opcode after the HP command.
    local expectedRng={{1,100}}
    if edition=='ruby'or edition=='sapphire'then expectedRng[#expectedRng+1]={0,99}end
    T.same(rng,expectedRng,'authored fixed amount preserves accuracy and the native zero-effect opcode without a hidden Psywave draw')
   end
   if mode~='custom-amount'then T.eq(imported[('MOVE_%03d'):format(number)].fixedDamage,nil,'native dispatch never rewrites imported move rows')end
   f.data.move_effects=saved;f.close()
  end
 end
 T.eq(Base.chooseDamage,original,'per-load native adapters preserve the shared classic handler')
end
-- Direct calculation uses the same native effect-byte dispatch, without a
-- private script marker or R/S's script-only Psywave preparation opcode.
for _,edition in ipairs({'firered','ruby','emerald'})do
 local imported=dofile('tests/gen3_fixed_damage/imported.lua').read()
 local f=dofile('tests/charge_required/fixture.lua').new('.','gen2',edition,3,'unified',true,false,
  'portable_enemy_action',function(data)for id,row in pairs(imported)do data.moves[id]=row end end)
 local c=f.fresh('TACKLE');c.battle:syncSides();local draws={}
 local function rng(lo,hi)draws[#draws+1]={lo,hi};return lo end
 for _,number in ipairs({49,69,82,101,149})do
  draws={};local amount,info=c.battle:computeDamage(c.user,c.target,f.data.moves[('MOVE_%03d'):format(number)],{rng=rng})
  T.eq(amount,({[49]=20,[69]=30,[82]=40,[101]=30,[149]=15})[number],'direct native calculation needs no private script flag')
  T.eq(info.crit,false,'direct fixed calculation never rolls a critical')
  if number==149 then T.same(draws,{{0,10}},'direct Psywave calculation uses its own 0..10 draw')
  else T.eq(#draws,0,'direct fixed calculation draws no ordinary random factor')end
 end
 f.close()
end
for _,edition in ipairs({'red','crystal'})do
 require('src.core.GameVersion').set(edition)
 T.eq(H.builtin('SPECIAL_DAMAGE_EFFECT',Base),Base,'older generation builtin is unchanged')
 T.eq(require('src.battle.Gen3Builtins').record('SPECIAL_DAMAGE_EFFECT',Base),Base,'older builtin dispatcher is unchanged')
end
T.finish('native fixed damage public effect delegation, overrides, fallback and generation guards')
