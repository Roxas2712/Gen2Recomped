-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,mode in ipairs({'single','double-left','double-right'})do
  local rows=dofile('tests/gen3_mist/cases.lua').run('.','gen2',edition,mode)
  T.eq(#rows,13,'all native Mist cases included')
 end
end
local Fixture=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
for _,edition in ipairs({'red','crystal'})do
 local f=Fixture.boot(edition,3,'unified')
 local battle=Native.newTrainer(f.game,'OPP_FIX_YOUNGSTER',1)
 battle:syncSides()
 battle:effectRecord('MIST_EFFECT').run({battle=battle,user=battle.enemy,target=battle.player})
 T.eq(battle.enemy.mist,true,'older generation keeps its actor Mist')
 T.eq(battle.sides[2].gen3MistTurns,nil,'older generation has no GBA side timer')
 for _=1,6 do battle:endOfTurn()end
 T.eq(battle.enemy.mist,true,'older generation actor Mist is not expired by GBA rules')
 f.close()
end
T.finish('native GBA Mist side effects with older-generation controls')
