package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Pokemon=require('src.pokemon.Pokemon')
for _,edition in ipairs({'gold','silver','crystal'})do
  V.set(edition)
  local data=T.fixtures.fresh()
  data.constants.gen=2
  data.type_chart.types={PSYCHIC={name='PSYCHIC',category='special'}}
  local run=T.sdk.loadMods({'mods/source_probe'},{data=data,fs=T.sdk.memfs({
    ['mods/source_probe/manifest.json']=[[{"id":"source_probe","name":"Source vocabulary","version":"1.0.0","api":2,"entry":"main.lua","affects_link":true}]],
    ['mods/source_probe/main.lua']=[[
      local mod=...
      assert(mod.content.type_chart:get('PSYCHIC_TYPE'))
      mod.content.type_chart:register('FAIRY',{name='FAIRY',category='special'})
      mod.content.type_chart:register('PSYCHIC_TYPE>FAIRY',{multiplier=5})
      local original=mod.content.pokemon:get('FIXMON_A')
      assert(original.levelMoves==original.learnset)
      mod.content.pokemon:patch('FIXMON_A',{types={'PSYCHIC_TYPE','FAIRY'},
        levelMoves={{level=1,move='FIX_SCRATCH'},{level=5,move='FIX_EMBERISH'}}})
    ]],
  })})
  T.eq(#run.errors,0,edition..': source-style content loads')
  T.eq(data.pokemon.FIXMON_A.types[1],'PSYCHIC','native Psychic ID is authoritative')
  T.eq(data.type_chart.matchups[#data.type_chart.matchups].attacker,'PSYCHIC','matchup uses same native type')
  local mon=Pokemon.new(data,'FIXMON_A',10)
  T.eq(mon.moves[1].id,'FIX_SCRATCH','native creation reads modern level-one moves')
  T.eq(mon.moves[2].id,'FIX_EMBERISH','native creation reads modern level-up moves')
  T.eq(data.pokemon.FIXMON_A.levelMoves,nil,'no competing stored learnset')
  run.release()
end
local H=require('src.compat.gen2.HallOfFame')
T.check(not H.hasEntered({hallOfFame={count=0,entered=false}}),'empty old record does not unlock Megas')
T.check(H.hasEntered({hallOfFame={count=1}}),'old count unlocks postgame')
T.check(H.hasEntered({hallOfFame={{party={}}}}),'native induction unlocks postgame')
T.check(H.hasEntered({hallOfFameCount=1}),'native numeric count unlocks postgame')
local Phone=require('src.compat.gen2.Phone')
V.set('crystal');local contacts={{name='JOEY',class='YOUNGSTER',member='JOEY1'}}
Phone.useRegistry({map_scripts={phone=contacts}})
T.eq(Phone.CONTACTS,contacts,'phone shares the actual imported catalogue')
V.set('red');T.eq(Phone.CONTACTS,nil,'phone cannot leak another game catalogue')
Phone.useRegistry(nil)
V.set('crystal')
local Enc=require('src.compat.gen2.Encounter')
local tables={grass={ROUTE={slots={DAY={{species='A',level=3},{species='B',level=4}}},buckets={128,256}}},
  water={ROUTE={slots={{species='C',level=7}},buckets={256}}}}
local draws=0
local grass=Enc.grassSlot(tables,'ROUTE','DAY',function(n)draws=draws+1;return n-1 end)
T.eq(grass.species,'B','legacy grass query uses native slot thresholds')
T.eq(draws,1,'slot query consumes exactly its native random draw')
T.eq(Enc.waterSlot(tables,'ROUTE',function()return 0 end).species,'C','water query uses native selector')
local data=T.fixtures.fresh()
data.pokemon.FIXMON_A.evolutions={{method='ITEM',item='TEST_STONE',species='FIXMON_B'}}
local mon=Pokemon.new(data,'FIXMON_A',10)
local Evo=require('src.compat.gen2.Evolution')
T.eq(Evo.checkMon(data,mon,{item='TEST_STONE'}).species,'FIXMON_B','legacy stone query uses the native evolution registry')
T.eq(mon.species,'FIXMON_A','evolution query never applies the result')
-- Run a source-style encounter patch through the actual API-2 event bus.
data=T.fixtures.fresh()
data.constants.gen=2
data.encounters={ROUTE={grass={rate=23,slots={{species='FIXMON_A',level=3}}},
  water={rate=42,slots={{species='FIXMON_A',level=5}}}}}
data.maps.ROUTE={id='ROUTE',label='NativeRoute'}
data.field={gen2TreeMons={maps={NativeRoute=1},sets={}},fishGroups={}}
require('src.core.Gen2EncounterViews').publish(data)
local run=T.sdk.loadMods({'mods/enc_patch'},{data=data,fs=T.sdk.memfs({
  ['mods/enc_patch/manifest.json']=[[{"id":"enc_patch","name":"Source encounters","version":"1.0.0","api":2,"entry":"main.lua","affects_link":true}]],
  ['mods/enc_patch/main.lua']=[[
    local mod=...
    mod.events:on('game.ready',function(e)
      local enc=e.game.data.gen2Encounters
      enc.grass.ROUTE.slots={MORN={{species='FIXMON_A',level=4}},
        DAY={{species='FIXMON_B',level=9}},NITE={{species='FIXMON_A',level=12}}}
      enc.grass.ROUTE.ascendantBuckets={MORN={300},DAY={300},NITE={300}}
      enc.grass.ROUTE.ascendantRollMax={MORN=300,DAY=300,NITE=300}
      enc.water.ROUTE.slots={{species='FIXMON_B',level=15}}
      enc.water.ROUTE.ascendantBuckets={600};enc.water.ROUTE.ascendantRollMax=600
      enc.treeSets[2]={common={{chance=100,species='FIXMON_B',level=7}},rare={}}
      enc.trees.ROUTE=2
      enc.fishGroups.TEST=enc.fishGroups.TEST or {}
      local group=enc.fishGroups.TEST;group.chance=256
      group.old={{chance=255,species='FIXMON_A',level=10,
        day={species='FIXMON_A',level=10},nite={species='FIXMON_B',level=20}}}
    end)
  ]],
})})
require('src.mods.Runtime').emit('game.ready',{game={data=data}})
T.eq(#run.errors,0,'API-2 source encounter event completes')
local NativeEnc=require('src.world.Encounter')
local day=NativeEnc.atTime(data.encounters.ROUTE.grass,'DAY')
local night=NativeEnc.atTime(data.encounters.ROUTE.grass,'NITE')
T.eq(NativeEnc.chooseTable(day,function(lo,hi)return hi end).species,'FIXMON_B','walking reads patched native daytime slots')
T.eq(NativeEnc.chooseTable(night,function(lo,hi)return hi end).level,12,'walking reads patched native nighttime slots')
T.eq(day.bucketSpan,300,'native selector retains source weighted denominator')
T.eq(day.rate,23,'source slot patch preserves native encounter rate')
T.eq(data.encounters.ROUTE.water.bucketSpan,600,'native surf selector reads patched weights')
T.eq(data.field.gen2TreeMons.maps.NativeRoute,2,'headbutt patch reaches the native map label selector')
T.eq(data.field.gen2TreeMons.sets[2].common[1].species,'FIXMON_B','headbutt patch reaches the native set')
local group=data.field.fishGroups.TEST
T.eq(group.rods.old[1].level,10,'source rod rows reach the native fishing group')
local pair=data.field.timeFishGroups[group.rods.old[1].timeGroup]
T.eq(pair.nite.species,'FIXMON_B','native time group preserves the night fish')
T.raises(function()data.gen2Encounters.grass.ROUTE.slots={}end,'read-only','source writes are scoped to the API-2 callback')
local Views=require('src.core.Gen2EncounterViews')
T.raises(function()Views.withLegacyWrites(data,function()error('probe failure')end)end,'probe failure','callback error is preserved')
T.raises(function()data.gen2Encounters.water.ROUTE.rate=1 end,'read-only','callback failure restores read-only admission')
run.release()
data=T.fixtures.fresh();data.constants.gen=2
data.moves.FIX_TACKLE.priority=1
run=T.sdk.loadMods({'mods/positional_effect'},{data=data,fs=T.sdk.memfs({
  ['mods/positional_effect/manifest.json']=[[{"id":"positional_effect","name":"Source custom effect","version":"1.0.0","api":2,"entry":"main.lua","affects_link":true}]],
  ['mods/positional_effect/main.lua']=[[
    local mod=...
    assert(mod.content.moves:get('FIX_TACKLE').effect=='EFFECT_PRIORITY_HIT')
    mod.content.moves:register('TEST_BOOST',{id='TEST_BOOST',name='TEST BOOST',type='NORMAL',power=0,
      accuracy=100,pp=10,effect='TEST_SOURCE_STATS'})
    mod.content.move_effects:register('TEST_SOURCE_STATS',{kind='primary',
      run=function(battle,user,target,def,id,sureHit)
        assert(user==battle.player and target==battle.enemy and id=='TEST_BOOST')
        battle:changeStageAgainstMist(user,user,'specialAttack',1)
        battle:emit({kind='message',text='SOURCE EFFECT APPLIED'})
      end})
  ]],
})})
T.eq(#run.errors,0,'source custom effect and priority vocabulary load')
local game={data=data,save=require('src.core.SaveData').newGame(),mods=run.loader,options={}}
game.save.party={Pokemon.new(data,'FIXMON_A',20)}
require('src.render.Font').load(data);require('src.battle.TypeChart').load(data)
local screen=require('src.battle.BattleState').newWild(game,'FIXMON_B',15)
screen.queue={};screen.phase='menu';screen.sendingOut=nil
local stored=game.save.party[1].stats.special
screen:performMove(screen.player,screen.enemy,{id='TEST_BOOST',pp=10})
T.eq(screen.player.stages.spatk,1,'positional custom effect changes the real native Sp.Atk stage')
T.eq(screen.enemy.stages.spatk,nil,'source target identity cannot redirect a self boost')
T.eq(game.save.party[1].stats.special,stored,'stage effect does not persist boosted base stats')
T.check(#screen.queue>0,'source effect messages are in the native action queue')
run.release()
data=T.fixtures.fresh();data.constants.gen=2;data.constants.speciesOrder={[3]='SPECIES_003'}
local def=require('src.mods.Merge').deepCopy(data.pokemon.FIXMON_A)
def.id,def.dex,def.index='SPECIES_003',3,3
data.pokemon.SPECIES_003=def
require('src.core.Gen2SpeciesNames').publish(data)
local Mon=require('src.compat.gen2.Mon')
local authored={{id='FIX_TACKLE',pp=3}}
local raised=Mon.new(data,'VENUSAUR',25,{dvs={attack=8,defense=9,speed=10,special=11},
  moves=authored,item='TEST_ITEM'})
T.eq(raised.species,'SPECIES_003','source constructor preserves canonical native species')
T.eq(raised.dvs.special,11,'source constructor accepts explicit inherited DVs')
T.eq(raised.item,'TEST_ITEM','source constructor retains its authored held item')
T.eq(raised.moves[1].pp,3,'source constructor preserves authored PP')
T.eq(raised.moves,authored,'source constructor retains its authored move-array identity')
T.eq(raised.moves[1],authored[1],'source constructor retains its authored move-slot identity')
local nativeGenes={attack=8,defense=9,speed=10,special=11}
local nativeRaised=Pokemon.new(data,'VENUSAUR',25,nil,nil,{dvs=nativeGenes,moves=authored})
T.check(nativeRaised.dvs~=nativeGenes,'native trainer genes retain their existing copy policy')
T.check(nativeRaised.moves~=authored and nativeRaised.moves[1]~=authored[1],
  'native constructor retains independently owned moves')
local save=require('src.core.SaveData').newGame();save.player.name='TEST';save.player.id=1234
Mon.stampOT(save,raised)
T.eq(raised.otId,1234,'source gift stamps the native OT identity')
Evo.useRegistry(data);Evo.markPokedex(save,'VENUSAUR')
T.check(save.pokedex.owned.SPECIES_003 and not save.pokedex.owned.VENUSAUR,'source gift marks the native Pokedex key')
Evo.useRegistry(nil)
local Fields=require('src.compat.gen2.SaveFields')
data.constants.badges=nil -- use this edition's native sixteen-badge catalogue
save.money=30000
T.check(Fields.bind(save,data),'source player fields bind to native save')
T.eq(save.player.money,30000,'source machine reads the actual native wallet')
save.player.money=save.player.money-10000
T.eq(save.money,20000,'source stone purchase spends the native wallet')
T.eq(rawget(save.player,'money'),nil,'source wallet never creates a second serialized balance')
save.flags.THUNDERBADGE=true
T.check(save.player.kantoBadges.THUNDER,'source gift gate sees native Kanto badge flags')
save.flags.THUNDERBADGE=nil
T.eq(save.player.kantoBadges.THUNDER,nil,'source badge query follows native flag removal')
T.finish('Legacy Gen2 content and native progress queries')
