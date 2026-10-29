-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion')
local Pokemon=require('src.pokemon.Pokemon')
local Stats=require('src.pokemon.Stats')
local Summary=require('src.ui.SummaryMenu')
local Save=require('src.core.SaveData')
local initial=Version.get()
for _,edition in ipairs{'gold','silver','crystal','prism','polishedcrystal'}do
  Version.set(edition)
  local data=T.fixtures.fresh();data.constants.gen=2
  for _,def in pairs(data.pokemon)do def.baseStats.spatk,def.baseStats.spdef=60,50 end
  local run=T.sdk.loadMods({'mods/refresh_probe'},{data=data,fs=T.sdk.memfs({
    ['mods/refresh_probe/manifest.json']='{"id":"refresh_probe","name":"Refresh probe","version":"1.0.0","api":2,"entry":"main.lua"}',
    ['mods/refresh_probe/main.lua']=[[
      local mod=...
      local Mon=require('src.battle.gen2.Mon')
      mod.exports.refresh=function(mon,data)return Mon.refreshStats(mon,data)end
      mod.exports.identity=function(mon,data)return Mon.syncIdentity(mon,data)end
    ]],
  })})
  T.eq(#run.errors,0,'actual SDK source stat consumer loads')
  local api=run.loader.exports.refresh_probe
  local mon=Pokemon.new(data,'FIXMON_A',25)
  for _,hp in ipairs{0,-1,5,999}do
    mon.hp=hp;mon.stats={hp=999,attack=1,defense=1,speed=1,spatk=1,spdef=1}
    local prior=mon.stats
    mon.dvs={attack=1,defense=1,speed=1,special=1,hp=0}
    T.eq(api.refresh(mon,data),mon,'source refresher retains actual native Pokemon identity')
    T.neq(mon.stats,prior,'source refresh recalculates an already existing native stat block')
    T.eq(mon.stats.hp,Stats.calcGen2(data.pokemon.FIXMON_A.baseStats,mon.dvs,25).hp,'refresh derives HP from current genes')
    T.eq(mon.maxHp,mon.stats.hp,'source maximum follows native recalculation')
    T.eq(mon.hp,math.min(hp,mon.stats.hp),'refresh preserves wounds, fainted zero and source negative HP semantics')
    T.eq(rawget(mon,'maxHp'),nil,'refresh adds no duplicate maximum field')
  end
  mon.hp=nil;api.refresh(mon,data);T.eq(mon.hp,mon.maxHp,'missing HP initializes to recalculated maximum')
  mon.name='STALE';mon.types={'CUSTOM'}
  local before=mon.stats
  T.eq(api.identity(mon,data),mon,'source identity signature passes data/Pokemon in native order')
  T.eq(mon.name,data.pokemon.FIXMON_A.name,'explicit legacy name refreshes from actual data owner')
  T.eq(mon.types,data.pokemon.FIXMON_A.types,'explicit legacy type copy refreshes from actual data owner')
  T.eq(mon.stats,before,'identity-only synchronization does not recalculate stats')
  local oldStats=mon.stats;mon.hp=1;mon.dvs.attack=15
  require('src.render.Font').load(data)
  local save=Save.newGame();save.party={mon}
  local game={data=data,save=save,stack={top=function()end,pop=function()end},input={wasPressed=function()return false end}}
  local screen=Summary.new(game,mon)
  T.eq(screen.mon,mon,'actual native summary retains original Pokemon')
  T.neq(mon.stats,oldStats,'actual native summary owns full source recalculation')
  T.eq(mon.hp,1,'opening native summary cannot heal a wounded Pokemon')
  T.eq(mon.stats.specialAttack,mon.stats.spatk,'actual summary exposes recalculated source split stats')
  local unknown={species='MISSING',stats={hp=2},hp=1}
  T.eq(api.refresh(unknown,data),unknown,'unknown source species remains untouched')
  T.eq(unknown.stats.hp,2,'missing definition cannot replace caller stats')
  run.release()
end
Version.set(initial)
T.finish('actual source SDK refresh/identity and native summary stat recalculation')
