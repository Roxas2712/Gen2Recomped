package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
local Simulation=require('src.features.Gen1BattleSimulation')
local Native=require('src.battle.gen2.Battle')
local previous=require('src.core.GameVersion').get()
for _,version in ipairs{'gold','silver','crystal'}do
 local bundle=Simulation.bundle{version=version,seed=2712,testing=true}
 local fixture=bundle:loadFixture('tests/fixtures/gen1_interfaces/gsc_core.lua')
 local party={fixture.makeMon('CYNDAQUIL',10)}
 local wild=fixture.makeMon('PIDGEY',10)
 local save={party=party}
 local snapshot=require('src.core.SaveSerializer').encode({party=party,wild=wild,save=save})
 local actual,owner=Simulation.new{version=version,seed=2712,data=fixture.data,party=party,wild=wild,save=save}
 T.check(actual.party~=party and actual.player~=party[1],'factory detaches actual battlers')
 T.eq(actual.save.party,actual.party,'factory preserves save/party aliases inside its detached graph')
 local turnEvents=actual:takeTurn{kind='move',move='TACKLE'}
 T.eq(require('src.core.SaveSerializer').encode({party=party,wild=wild,save=save}),snapshot,'real simulated turn never edits input party or save')
 T.check(#turnEvents>0,'real simulated turn emits consumable events')
 T.eq(owner.version,version,'factory returns its isolated engine namespace')
 bundle:require('tests.gen2_held_items_test')
 bundle:require('tests.gen2_battle_lockin_test')
 bundle:require('tests.gen2_battletype_escape_test')
 T.eq(bundle:require('src.core.GameVersion').get(),version,'simulation has its own edition')
 T.eq(require('src.core.GameVersion').get(),previous,'simulation cannot change the host edition')
 T.check(bundle:require('src.battle.gen2.Battle')~=Native,'pure engine cannot replace the live native model')
 T.check(type(bundle:require('src.battle.gen2.Battle').new)=='function','real source constructor available')
 T.check(type(bundle:require('src.battle.gen2.Battle').takeLinkTurn)=='function','real two-party turn execution available')
end
T.finish('Detached Gen1 GSC constructor, turns and events')
