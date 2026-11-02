-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native PokemonUseItemEffects masks: byte0 ATK/Focus Energy, byte1 DEF/SPE,
-- byte2 ACC/SPATK, byte3 side MIST. All five original cartridges share them.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Items=require('src.inventory.ItemEffects')
local S=require('src.core.SaveSerializer')
local rows={
 {'X_ATTACK',1,0,0,0,'attack'}, {'X_DEFEND',0,16,0,0,'defense'},
 {'X_SPEED',0,1,0,0,'speed'}, {'X_ACCURACY',0,0,16,0,'accuracy'},
 {'X_SPECIAL',0,0,1,0,'spatk'}, {'DIRE_HIT',32,0,0,0,'focusEnergy'},
 {'GUARD_SPEC',0,0,0,128,'mist'},
}
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 local f=require('tests.enemy_actions.fixture').new('.','gen2',edition,3,'unified',function(data)
  data.constants.gen3ItemEffects={}
  for n,row in ipairs(rows)do
   data.items[row[1]]={name=row[1],index=72+n}
   data.constants.gen3ItemEffects[row[1]]={battle=row[5]==0,mist=row[5]~=0,
    bytes={row[2],row[3],row[4],row[5],0,96,1,1},friendship={1,1}}
  end
 end)
 for _,row in ipairs(rows)do
  local x=f.fresh('TACKLE');local b,u=x.battle,x.user
  u.mon.happiness=70
  local beforeHP=u.mon.hp
  local kind=Items.use(b.data,b.game.save,row[1],nil,b)
  T.eq(kind,'consumed',edition..' '..row[1]..' admitted')
  T.eq(u.mon.hp,beforeHP,'tonic does not heal')
  T.eq(u.mon.happiness,71,'successful native low-band friendship')
  T.eq(u.xAccuracy,nil,'X Accuracy never enables Gen1 never-miss bit')
  T.eq(u.stages.special,nil,'GBA never writes the shared Special stat')
  if row[6]=='focusEnergy'then T.eq(u.focusEnergy,true)
  elseif row[6]=='mist'then T.eq(b.sides[1].gen3MistTurns,5);T.eq(b.sides[2].gen3MistTurns,nil)
  else
   for _,stat in ipairs{'attack','defense','speed','accuracy','spatk','spdef'}do
    T.eq(u.stages[stat]or 0,stat==row[6]and 1 or 0,'only the original selected stat changes')
   end
   u.stages[row[6]]=6
  end
  local snapshot=S.encode(b.game.save)
  kind=Items.use(b.data,b.game.save,row[1],nil,b)
  T.eq(kind,'failed','active effect / +6 refuses item consumption')
  T.eq(S.encode(b.game.save),snapshot,'failed tonic cannot change friendship/save')
 end
 do
  local x=f.fresh('TACKLE');local b,u=x.battle,x.user
  u.mon.happiness=220
  T.eq(Items.use(b.data,b.game.save,'X_SPECIAL',nil,b),'consumed')
  T.eq(u.mon.happiness,220,'missing high friendship bit is no gain, not the middle band')
  u.mon.happiness=70;u.mon.ball='LUXURY_BALL';u.mon.metLocation=7
  b.game.overworld={map={def={regionMapSection=7}}}
  T.eq(Items.use(b.data,b.game.save,'X_ATTACK',nil,b),'consumed')
  T.eq(u.mon.happiness,73,'original luxury and birthplace additions')
  local ally={mon={hp=20,happiness=70},name='ALLY',isPlayer=true,stages={},position=2}
  b.menuBattler=function()return ally end
  T.eq(Items.use(b.data,b.game.save,'X_ACCURACY',nil,b),'consumed')
  T.eq(ally.stages.accuracy,1,'double menu controller owns recipient')
  T.eq(u.stages.accuracy,nil,'partner item never boosts the left slot')
  local before=S.encode(b.game.save)
  T.eq(Items.use(b.data,b.game.save,'X_ATTACK',nil,nil),'failed','field refuses battle-only item')
  T.eq(S.encode(b.game.save),before)
 end
 f.close()
end
V.set('red')
local mon={hp=20,happiness=70};local actor={mon=mon,name='OLD',isPlayer=true,stages={}}
local save={party={mon},player={name='OLD'},inventory={}}
T.eq(Items.use({items={X_ACCURACY={name='X ACCURACY'}}},save,'X_ACCURACY',nil,{player=actor}),'consumed')
T.eq(actor.xAccuracy,true,'Gen1 original X Accuracy remains unchanged')
T.finish('original GBA player battle tonics')
