package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Save=require('src.core.SaveData')
local Pokemon=require('src.pokemon.Pokemon')
local Battle=require('src.battle.BattleState')
local G3=require('src.battle.Gen3Battle')
local data=T.fixtures.fresh();data.constants.gen=3
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 V.set(edition)
 local save=Save.newGame({version=edition,noHooks=true})
 save.party={Pokemon.new(data,'FIXMON_A',30)}
 local game={save=save,data=data,overworld={map={def={mapType='INDOOR'}}}}
 local battle=Battle.newWild(game,'FIXMON_C',23)
 T.eq(battle.gen3Terrain,G3.terrainFor(game),edition..' resolves semantic terrain before any draw')
 T.eq(battle.gen3Scene,G3.sceneFor(game)or false,edition..' resolves scene before any draw')
 local terrain=battle.gen3Terrain
 game.overworld.map.def.mapType='OCEAN'
 T.eq(battle.gen3Terrain,terrain,'the battle retains the terrain it started on')
end
T.finish('Gen 3 battle terrain initialization')
