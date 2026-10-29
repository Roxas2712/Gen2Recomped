-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion');local previous=V.get()
local N=require('src.world.Gen2Nests')
local Landmarks=require('src.world.Gen2Landmarks')
local TownMap=require('src.ui.TownMap')
local Save=require('src.core.SaveData')
for _,edition in ipairs{'gold','silver','crystal'}do
 V.set(edition)
 local d=T.fixtures.fresh();d.constants.gen=2
 local kanto=edition=='crystal' and 47 or 46
 local ship=edition=='crystal' and 95 or 94
 d.field.townMap={johto='fixture-johto.png',kanto='fixture-kanto.png',landmarks={}}
 for _,i in ipairs{1,2,3,4,5,6,8,kanto,ship}do
  d.field.townMap.landmarks[i]={name='LOCATION '..i,x=10+i,y=20}
 end
 d.maps={A={id='A',landmark=1},DUP={id='DUP',landmark=1},NIGHT={id='NIGHT',landmark=2},
  WATER={id='WATER',landmark=3},FISH={id='FISH',landmark=4},TREE={id='TREE',landmark=5},
  SWARM={id='SWARM',landmark=6},ROAM={id='ROAM',landmark=8},
  PALLET_TOWN={id='PALLET_TOWN',landmark=kanto},SHIP={id='SHIP',landmark=ship}}
 local function slots(id)return{slots={{species=id,level=5}}}end
 d.encounters={A={grass=slots('FIXMON_A')},DUP={water=slots('FIXMON_A')},
  NIGHT={grass={slots={{species='FIXMON_B',level=5}},byTime={nite=slots('FIXMON_A')}}},
  WATER={water=slots('FIXMON_A')},FISH={fishing=slots('FIXMON_A')},
  TREE={headbutt=slots('FIXMON_A')},SWARM={swarmGrass=slots('FIXMON_A')},
  PALLET_TOWN={grass=slots('FIXMON_A')},SHIP={water=slots('FIXMON_A')}}
 local save=Save.newGame();save.player.map='A'
 save.g2RoamReleased=true
 save.g2Roam={RAIKOU={speciesId='FIXMON_B',mapId='ROAM',hp=0,landmark=99},
  ENTEI={speciesId='FIXMON_A',mapId='ROAM',active=false}}
 T.same(N.find(d,'FIXMON_A'),{1,2,3,kanto},'all native grass times and water only '..edition)
 T.same(N.find(d,'FIXMON_A','johto',save),{1,2,3},'region filter excludes Kanto and inactive beasts')
 T.same(N.find(d,'FIXMON_A','kanto',save),{kanto})
 T.same(N.find(d,'FIXMON_B',nil,save),{2,8},'unmet hp-zero beast uses its current native map')
 T.eq(save.g2Roam.RAIKOU.hp,0);T.eq(save.g2Roam.RAIKOU.landmark,99,'query never overwrites stale saved metadata')
 save.g2Roam.RAIKOU.mapId='WATER'
 T.same(N.find(d,'FIXMON_B',nil,save),{2,3},'moving a beast retires the old marker immediately')
 save.g2RoamReleased=false
 T.same(N.find(d,'FIXMON_B',nil,save),{2},'unreleased beasts are absent without save migration')
 T.eq(save.g2RoamReleased,false)
 save.g2RoamReleased=true;save.g2Roam.RAIKOU.active=false
 T.same(N.find(d,'FIXMON_B',nil,save),{2},'retired beasts are absent')
 save.g2Roam.RAIKOU.active=true;save.g2Roam.RAIKOU.mapId='PALLET_TOWN'
 T.same(N.find(d,'FIXMON_B',nil,save),{2},'the cartridge roamer search is Johto only')
 save.g2Roam.RAIKOU.mapId='ROAM'
 T.eq(N.regionOf(kanto-1,d),'johto','Crystal Silver Cave remains Johto')
 T.eq(N.regionOf(kanto,d),'kanto');T.eq(N.regionOf(kanto),'kanto','optional-data query follows active edition')
 T.eq(N.regionOf(ship,d),nil,'Fast Ship is outside the regional nest search')
 T.eq(N.landmarkId(d,kanto),'LANDMARK_PALLET_TOWN')
 T.eq(N.landmark(d,kanto),d.field.townMap.landmarks[kanto],'getter borrows the actual native record')
 d.field.townMap.landmarks[kanto].name='PATCHED'
 T.eq(N.landmark(d,kanto).name,'PATCHED','authored native changes remain live')
 local g={data=d,save=save,input={wasPressed=function()return false end}}
 local expected={1,2,3,kanto}
 local actual=TownMap.new(g,{nestSpecies='FIXMON_A'})
 T.eq(actual.mode,'gen2');local found={};for _,loc in ipairs(actual.nests)do found[#found+1]=loc.landmark end
 T.same(found,expected,'actual native AREA screen uses the same filtered search')
 actual=TownMap.new(g,{nestSpecies='FIXMON_B'});found={}
 for _,loc in ipairs(actual.nests)do found[#found+1]=loc.landmark end
 T.same(found,{2,8},'actual native AREA includes the current active roamer')
 -- A replaced encounter table must not leave results cached by dataset key.
 d.encounters={WATER={water=slots('FIXMON_A')}}
 T.same(N.find(d,'FIXMON_A'),{3})
 d.maps.WATER.landmark=0;T.same(N.find(d,'FIXMON_A'),{})
 -- Mod-authored index spaces take precedence over retail fallback constants.
 d.field.townMap.landmarks[80]={name='CUSTOM PALLET',x=4,y=5,index=80,landmarkId='LANDMARK_PALLET_TOWN'}
 d.field.townMap.landmarks[90]={name='CUSTOM SHIP',x=6,y=7,index=90,landmarkId='LANDMARK_FAST_SHIP'}
 T.eq(N.regionOf(79,d),'johto');T.eq(N.regionOf(80,d),'kanto');T.eq(N.regionOf(90,d),nil)
 T.eq(N.landmarkId(d,80),'LANDMARK_PALLET_TOWN')
end
V.set('crystal')
for _,value in ipairs{-1,0,256,1.5,'UNKNOWN'}do T.eq(N.regionOf(value),nil)end
T.eq(N.landmark({},nil),nil);T.eq(N.landmarkId({},nil),nil)
T.eq(N.landmarkId({},1),nil,'unavailable landmark data has no fabricated record identity')
T.same(N.find(nil,'FIXMON_A'),{});T.same(N.find({},nil),{})
-- Source names and native callers observe one module and one set of owners.
local d=T.fixtures.fresh();d.constants.gen=2
local beast=require('src.mods.Merge').deepCopy(d.pokemon.FIXMON_A)
beast.id,beast.name,beast.index,beast.dex='SPECIES_243','RAIKOU',243,243
d.pokemon.SPECIES_243=beast;d.constants.speciesOrder={[243]='SPECIES_243'}
require('src.core.Gen2SpeciesNames').publish(d)
d.field.townMap={landmarks={[1]={name='ALIAS LOCATION',x=8,y=16}}}
local map={id='NATIVE_ROUTE',sourceId='SOURCE_ROUTE',landmark=1}
d.maps={NATIVE_ROUTE=map,SOURCE_ROUTE=map}
d.encounters={NATIVE_ROUTE={grass={slots={{species='RAIKOU',level=40}}}}}
T.same(N.find(d,'SPECIES_243'),{1},'source species aliases address actual native encounter identities')
T.same(N.find(d,'RAIKOU'),{1})
local roaming={g2RoamReleased=true,g2Roam={RAIKOU={mapId='SOURCE_ROUTE',speciesId='SPECIES_243',hp=0}}}
d.encounters={}
T.same(N.find(d,'RAIKOU',nil,roaming),{1},'verified source/native map alias resolves the actual roamer header')
local loaded=T.sdk.loadMods({'mods/nest_reader'},{data=d,fs=T.sdk.memfs({
 ['mods/nest_reader/manifest.json']='{"id":"nest_reader","name":"Nest reader","version":"1.0.0","api":2,"entry":"main.lua"}',
 ['mods/nest_reader/main.lua']=[[
  local mod=...;mod.exports.Nests=require('src.core.gen2.Nests')
 ]],
})})
T.eq(#loaded.errors,0);T.eq(loaded.loader.exports.nest_reader.Nests,N)
T.eq(Landmarks.record(d,256),nil)
loaded.release();V.set(previous)
T.finish('native/source GSC nests, live regional landmarks and actual native AREA ownership')
