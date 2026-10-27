-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local H=require('src.battle.Gen3HitHistory')
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,prior in ipairs({false,true})do
  local f=dofile('tests/charge_required/fixture.lua').new('.','gen2',edition,3,'unified',false,false,
   'portable_enemy_action',function(data)
    data.moves.SCRIPTED_HP={id='SCRIPTED_HP',index=150,power=0,type='NORMAL',pp=10,effect='SPLASH_EFFECT',gen3Effect=85}
   end,function(files)
    files['mods/portable_enemy_action/main.lua']=[[return function(mod)
     mod.exports.api=mod
     assert(mod.content.move_effects:override('SPLASH_EFFECT',{kind='full',perform=function(ctx)
      ctx.damage(ctx.target,5)
     end}))
    end]]
   end)
  local c=f.fresh('TACKLE');local b=c.battle;b:syncSides()
  if prior then b:performMove(c.user,c.target,c.move)end
  local landed,kind,attacker=c.target.expLastLandedMove,c.target.expLastHitByType,c.target.expLastHitById
  local before=c.target.mon.hp;b:performMove(c.user,c.target,{id='SCRIPTED_HP',pp=10})
  T.eq(c.target.mon.hp,before-5,'public authored generic HP command executes')
  T.eq(c.target.expLastLandedMove,landed,'generic authored HP loss preserves native landed move')
  T.eq(c.target.expLastHitByType,kind,'generic authored HP loss preserves native effective type')
  T.eq(c.target.expLastHitById,attacker,'generic authored HP loss preserves native HP attacker')
  f.close()
 end
end
for _,edition in ipairs({'firered','ruby','emerald'})do
 for _,copyRow in ipairs({false,true})do
  local f=dofile('tests/charge_required/fixture.lua').new('.','gen2',edition,3,'unified',false,false,
   'portable_enemy_action',function(data)
    data.moves.MOVE_033.gen3Type=0
    data.type_chart.types=data.type_chart.types or{}
    data.type_chart.types.FIRE={id='FIRE',index=10,category='special'}
   end,function(files)
    files['mods/portable_enemy_action/main.lua']=[[return function(mod)
     mod.exports.api=mod
     local base=assert(mod.content.move_effects:get('NO_ADDITIONAL_EFFECT'))
     base.beforeAccuracy=function(ctx)
      ]]..(copyRow and'local row={};for k,v in pairs(ctx.move)do row[k]=v end;ctx.move=row;'or'')..[[
      ctx.move.type='FIRE'
     end
     assert(mod.content.move_effects:override('NO_ADDITIONAL_EFFECT',base))
    end]]
   end)
  local c=f.fresh('TACKLE');c.battle:syncSides();local before=c.target.mon.hp
  c.battle:performMove(c.user,c.target,c.move)
  T.check(c.target.mon.hp<before,'authored effective-type modifier reaches the actual hit')
  T.eq(c.target.expLastHitByType,10,'authored type replacement overrides an unchanged imported numeric tag')
  T.eq(f.data.moves.MOVE_033.gen3Type,0,'history does not rewrite the imported numeric tag')
  T.eq(f.data.moves.MOVE_033.type,copyRow and 'NORMAL' or 'FIRE','authored record retains ownership of row copying')
  f.close()
 end
end
for _,edition in ipairs({'red','crystal'})do
 require('src.core.GameVersion').set(edition)
 local f=dofile('tests/charge_required/fixture.lua').new('.','gen2',edition,3,'unified',true)
 local c=f.fresh('TACKLE');c.battle:syncSides();c.battle:performMove(c.user,c.target,c.move)
 T.eq(c.target.expLastLandedMove,nil,'older rules do not publish native GBA landed history')
 T.eq(c.target.expLastHitByType,nil,'older rules do not publish native GBA type history')
 T.eq(c.target.expLastHitById,nil,'older rules do not publish native GBA attacker history');f.close()
end
for _,field in ipairs({'expLastLandedMove','expLastHitByType','expLastHitById'})do
 T.neq(H.signature({[field]=1},'host'),H.signature({},'host'),'each received-history field changes the link signature')
end
for _,actor in ipairs({{}, {expLastLandedMove=0,expLastHitByType=0,expLastHitById=0},
 {expLastLandedMove=65535,expLastHitByType=255,expLastHitById=255}})do
 T.eq(H.valid(actor),true,'native nil/zero and unsigned sentinel ranges are representable')
end
T.eq(H.signature({expLastLandedMove=33,expLastHitByType=0,expLastHitById=0},'host'),
 H.signature({expLastLandedMove=33,expLastHitByType=0,expLastHitById=1},'guest'),'host/guest normalize zero HP-attacker')
T.neq(H.signature({},'host'),H.signature({expLastLandedMove=0,expLastHitByType=0,expLastHitById=0},'host'),'zero histories differ from absent history')
T.finish('native hit history authored HP ownership, older rules and numeric zero')
