-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');local G=require('src.core.Game3')
local Bag=require('src.ui.game3.bag_menu');local Dex=require('src.ui.game3.pokedex')
local Growth=require('src.ui.game3.stat_growth');local Party=require('src.ui.game3.party_menu')
local Observation=require('src.compat.gen1.NativeModalObservation')
local original=package.loaded['src.core.Game']
local function fresh(edition)
 local f=require('tools.battle-source-runtime.fixture').new(edition);package.loaded['src.core.Game']=f.game
 f.fresh('TACKLE');return f
end
local function collect()for _=1,5 do collectgarbage('collect')end end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=fresh(edition);local game=f.game;local before=game.save.party[1].hp
 local types={
  {require('src.ui.Gen3BagMenu'),Bag,function()return require('src.ui.Gen3BagMenu').new(game)end},
  {require('src.ui.Gen3Pokedex'),Dex,function()return require('src.ui.Gen3Pokedex').new(game)end},
  {require('src.ui.Gen3PartyMenu'),Party,function()return require('src.ui.Gen3PartyMenu').new(game,{})end},
  {require('src.battle.BattleState').StatBox,Growth,function()return require('src.battle.BattleState').StatBox.new(game,game.save.party[1])end},
 }
 for _,entry in ipairs(types)do
  local class,api,construct=unpack(entry)
  T.eq(api.isOpen(),false)
  local unstamped=setmetatable({game=game},class);table.insert(game.stack.states,unstamped)
  T.eq(api.isOpen(),false,'class identity alone cannot adopt an unbound screen');table.remove(game.stack.states)
  local screen=construct();T.eq(api.isOpen(),false,'construction does not mean open')
  game.stack:push(screen);T.eq(api.isOpen(),true)
  local cover={};game.stack:push(cover);T.eq(api.isOpen(),true,'covered modal is still native/open')
  local save,data,loader=game.save,game.data,game.mods
  game.save={};T.eq(api.isOpen(),false);game.save=save
  game.data={};T.eq(api.isOpen(),false);game.data=data
  game.mods={};T.eq(api.isOpen(),false);game.mods=loader
  Version.set(edition=='firered'and'leafgreen'or'firered');T.eq(api.isOpen(),false);Version.set(edition)
  T.eq(api.isOpen(),true);T.eq(game.stack:top(),cover,'observation never removes unrelated UI')
  game.stack:pop();game.stack:pop();T.eq(api.isOpen(),false)
 end
 -- Missing nested StatBox cannot accidentally match the battle class itself.
 local Battle=require('src.battle.BattleState');local stat=Battle.StatBox
 local battle=f.fresh('TACKLE').battle;Observation.capture(battle,game);game.stack:push(battle)
 Battle.StatBox=nil;T.eq(Growth.isOpen(),false);Battle.StatBox=stat;game.stack:pop()
 T.eq(game.save.party[1].hp,before,'queries never consume HP')
 f.close();G.release()
end
-- FR/LG registration uses its own real native class and constructor.
do
 local f=fresh('firered');local game=f.game
 local class=require('src.ui.Gen3PokedexFRLG')
 game.data.constants.gen3FRLGPokedex={images={kanto_field='synthetic-unused-field'}}
 -- base/newEntry reads native pokemon data; no scripted registration is run.
 local state=class.newEntry(game,'CHARMANDER',true);game.stack:push(state)
 T.eq(Dex.isOpen(),true);game.stack:pop();T.eq(Dex.isOpen(),false);f.close();G.release()
end
-- A weak observation must not retain a removed state, native world, save or
-- dataset through the LuaJIT weak-key/value-to-stack cycle.
local weak=setmetatable({},{__mode='v'})
do
 local f=fresh('firered');local game=f.game
 local state=require('src.ui.Gen3BagMenu').new(game);game.stack:push(state);T.eq(Bag.isOpen(),true)
 weak[1],weak[2],weak[3],weak[4]=state,game,game.save,game.data
 game.stack:pop();f.close();G.release();package.loaded['src.core.Game']=original
end
-- The fixture intentionally installs global font/type registries. Replace
-- those independent native owners before attributing retained data to the
-- weak modal registry under test.
require('src.render.Font').load(T.fixtures.fresh());require('src.battle.TypeChart').load(T.fixtures.fresh())
collect();for i=1,4 do T.eq(weak[i],nil,'retired modal observation is collectable')end
for _,edition in ipairs{'gold','silver','crystal','red'}do
 Version.set(edition);T.eq(Bag.isOpen(),false);T.eq(Dex.isOpen(),false);T.eq(Party.isOpen(),false);T.eq(Growth.isOpen(),false)
end
Version.set('firered');package.loaded['src.core.Game']=original
T.finish('constructor-bound native bag, dex, party and stat-window observations without retained owners')
