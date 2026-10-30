-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Contract=require('tests.api3_contract.wild_battle')
local World=require('src.world.WorldAPI')
local Wild=require('src.mods.Api3WildBattle')
for _,version in ipairs({'red','gold','crystal','firered','emerald'}) do
  local f=Contract.fixture('tests/api3_contract','gen2',version)
  local world=World.new(f.game,'api2_probe')
  for _,level in ipairs({-1,0,1.5,101,math.huge,0/0,'invalid'}) do
    T.eq(world:startWildBattle('MEW',level),nil,'API2 refuses invalid level before construction')
  end
  T.eq(world:startWildBattle('MISSING',5),nil,'API2 refuses unknown native ID')
  T.eq(f.constructed,0,'refusal never allocates battle or marks seen')
  T.check(world:startWildBattle('MEW','5'),version..' API2 preserves numeric-string level')
  T.eq(f.battle.species,'MEW','native species is passed through')
  T.eq(f.battle.level,5,'native constructor receives integer')
  T.eq(world:startWildBattle('MEW',6),nil,'API2 cannot stack another battle')
  T.eq(f.exports.request('MEW',6),nil,'API3 cannot stack over API2 entry')
  f:complete('win');f:complete('win')
  T.eq(f.after,1,'native cleanup runs exactly once')
  f.pushFailure=true
  T.eq(world:startWildBattle('MEW',5),nil,'failed push is refused')
  T.eq(f.after,1,'failed admission does not execute completion')
  Wild.cancelAll();f.restore()
end
do
  local f=Contract.fixture('tests/api3_contract','gen2','crystal')
  local world=World.new(f.game,'api2_probe')
  T.check(world:startWildBattle('MEW',5),'battle starts before session replacement')
  f.game.save={};f:complete('lose')
  T.eq(f.after,0,'stale completion cannot clean up against another save')
  Wild.cancelAll();f.restore()
end
-- The unchanged API2 entry must reach this method through the real lazy
-- loader facade, and retained exports must lose admission after rollback.
do
  local f=Contract.fixture('tests/api3_contract','gen2','crystal')
  local Runtime=require('src.mods.Runtime')
  local Loader=require('src.mods.Loader')
  local mew=f.game.data.pokemon.MEW
  f.game.data=T.fixtures.fresh();f.game.data.pokemon.MEW=mew
  local loader=Loader.new({dev=true,fs=T.sdk.memfs({
    ['mods/api2_native/manifest.json']=[[{"id":"api2_native","name":"Native API2","version":"1.0.0","api":2,"entry":"main.lua"}]],
    ['mods/api2_native/main.lua']=[[
      local mod=...
      assert(mod.contentFormat=='native')
      mod.exports.request=function(id,level)return mod.world:startWildBattle(id,level)end
    ]],
  })})
  loader._game=function()return f.game end
  loader:load(f.game.data)
  T.eq(#loader.errors,0,'unmodified native API2 entry loads with dev guard')
  local request=loader.exports.api2_native.request
  Runtime.currentMod='api2_native'
  T.check(request('MEW',5),'native API2 entry reaches engine battle admission')
  T.eq(Runtime.currentMod,'api2_native','native boundary restores calling mod owner')
  Runtime.currentMod=nil
  loader:_rollback('api2_native')
  f:complete('win')
  T.eq(f.after,1,'native cleanup survives originating mod rollback')
  T.eq(request('MEW',5),nil,'retained API2 export cannot start after rollback')
  Wild.cancelAll();f.restore()
end
T.finish('API2 native battle entry')
