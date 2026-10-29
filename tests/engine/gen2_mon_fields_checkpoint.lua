-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real native semantic codecs must retain source field views on reconstructed
-- Pokemon/current stats without persisting closures or accepting custom owners.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
local Fields=require('src.pokemon.Gen2MonFields')
local Stats=require('src.pokemon.Stats')
local Serializer=require('src.core.SaveSerializer')
local Version=require('src.core.GameVersion')
local initial=Version.get()
local seed=9139
love.math.random=function(lo,hi)
  seed=seed*48271%2147483647
  if not lo then return seed/2147483647 end
  if not hi then lo,hi=1,lo end
  return lo+seed%(hi-lo+1)
end
love.math.getRandomState=function()return tostring(seed)end
love.math.setRandomState=function(v)seed=assert(tonumber(v))end
love.math.newRandomGenerator=function()return{setState=function(_,v)assert(tonumber(v))end}end
for _,edition in ipairs{'gold','silver','crystal','prism','polishedcrystal'}do
  local f=Fixture.boot(edition);local game=f.game
  for _,def in pairs(game.data.pokemon)do
    if def.baseStats then def.baseStats.spatk,def.baseStats.spdef=61,52 end
  end
  Fields.publish(game.data)
  local mon=game.save.party[1]
  mon.stats=Stats.calc(game.data.pokemon[mon.species],mon.level,mon.dvs,mon.statExp)
  mon.hp=mon.stats.hp
  local checkpoint,code,detail=f.checkpoints:capture(game)
  T.check(checkpoint~=nil,edition..' actual world capture: '..tostring(code)..' '..tostring(detail))
  if checkpoint then
    local bytes=Serializer.encode(checkpoint)
    T.eq(getmetatable(checkpoint.save.party[1]),nil,'world snapshot contains raw Pokemon only')
    T.eq(getmetatable(checkpoint.save.party[1].stats),nil,'world snapshot contains raw stats only')
    T.eq(checkpoint.save.party[1].maxHp,nil,'world snapshot contains no derived maximum')
    local restored,why=f.checkpoints:restore(game,checkpoint)
    T.check(restored,'world reconstruction succeeds: '..tostring(why))
    if restored then
      mon=game.save.party[1]
      T.eq(mon.maxHp,mon.stats.hp,'actual world restore rebinds source maximum')
      T.eq(mon.stats.specialDefense,mon.stats.spdef,'actual world restore rebinds source split stats')
      T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),bytes,'world raw recapture remains byte identical')
    end
  end
  local battle=Native.newWild(game,'FIXMON_B',15)
  game.stack.states={f.world,battle}
  battle.phase,battle.queue,battle.current,battle.afterQueue,battle.introSlide='menu',{},nil,'menu',0
  -- Transform/current battle stats can own a separate block from party stats.
  battle.enemy.curStats=Stats.calc(game.data.pokemon.FIXMON_A,25,battle.enemy.mon.dvs,{})
  local expected=battle.enemy.curStats.spatk
  checkpoint,code,detail=f.checkpoints:capture(game)
  T.check(checkpoint~=nil,edition..' actual battle capture: '..tostring(code)..' '..tostring(detail))
  if checkpoint then
    local bytes=Serializer.encode(checkpoint)
    local restored,why=f.checkpoints:restore(game,checkpoint)
    T.check(restored,'battle reconstruction succeeds: '..tostring(why))
    if restored then
      local b=game.stack:top()
      T.eq(b.player.mon,game.save.party[1],'real reconstructed party Pokemon identity is retained')
      T.eq(b.player.curStats,game.save.party[1].stats,'native unchanged party stat alias is retained')
      T.eq(b.battle.enemy,b.enemy.mon,'real live source model retains reconstructed enemy identity')
      T.neq(b.enemy.curStats,b.enemy.mon.stats,'separate native current stat block remains separate')
      T.eq(b.enemy.curStats.specialAttack,expected,'separate reconstructed current stats restore source split names')
      T.eq(b.enemy.mon.maxHp,b.enemy.mon.stats.hp,'reconstructed enemy source maximum follows actual mon')
      T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),bytes,'battle recapture remains byte identical')
      b.enemy.curStats.specialAttack=97
      T.eq(b.enemy.curStats.spatk,97,'source write reaches restored current native combat stats')
      local custom={};for k,v in pairs(b.enemy.curStats)do custom[k]=v end
      setmetatable(custom,{__index=function()return 'opaque'end})
      Fields.stats(custom);b.enemy.curStats=custom
      local refused,reason=f.checkpoints:capture(game)
      T.eq(refused,nil,'custom wrapped current stats remain refused by native semantic codec')
      T.eq(reason,'unsupported_battle','custom state keeps named native refusal')
    end
  end
  require('src.mods.Loader').teardown();f.close()
end
Version.set(initial)
T.finish('native GSC field views across actual world and battle semantic reconstruction')
