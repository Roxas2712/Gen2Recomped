-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion')
local DayCare=require('src.pokemon.DayCare')
local Pokemon=require('src.pokemon.Pokemon')
local Roamer=require('src.world.Gen3Roamers')
local Cap=require('src.mods.Capabilities')
for _,version in ipairs({'ruby','sapphire','emerald','firered','leafgreen'})do
 for _,format in ipairs({'native','unified'})do
  Version.set(version)
  local data=T.fixtures.fresh()
  data.constants.generation=3
  data.pokemon.FIXMON_A.genderRatio=127
  data.pokemon.FIXMON_A.eggGroups={1,1}
  data.constants.gen3Roamers={places={{map='ROUTE_A',nextMaps={'ROUTE_B'}},
    {map='ROUTE_B',nextMaps={'ROUTE_A'}}},jumpOneIn=16,meetOneIn=4}
  local run=T.sdk.loadMods({'mods/lifecycle_probe'},{data=data,fs=T.sdk.memfs({
    ['mods/lifecycle_probe/manifest.json']='{"id":"lifecycle_probe","name":"Lifecycle probe","version":"1.0.0","api":2,"callback_format":"'..format..'","entry":"main.lua"}',
    ['mods/lifecycle_probe/main.lua']=[[
      local mod=...
      local score
      mod.exports.setScore=function(value)score=value end
      mod.hooks:wrap("breeding.compatibility",function(next,context)
        mod.exports.parent=context.mon1 and context.mon1.species
        local base=next(context)
        return score==nil and base or score
      end)
      mod.events:on("breeding.egg_created",function(e)
        mod.exports.created=(mod.exports.created or 0)+1
        mod.exports.egg=e.egg.species;mod.exports.odds=e.compatibility
        mod.exports.mother=e.mother.species
      end)
      mod.events:on("roamer.moved",function(e)
        mod.exports.moves=(mod.exports.moves or 0)+1
        mod.exports.from=e.from;mod.exports.to=e.to;mod.exports.index=e.index;mod.exports.reason=e.reason
      end)
      mod.events:on("roamer.encountered",function(e)
        mod.exports.meets=(mod.exports.meets or 0)+1
        mod.exports.met=e.mapId;mod.exports.species=e.species
      end)
      mod.events:on("egg.hatched",function(e)
        mod.exports.hatches=(mod.exports.hatches or 0)+1
        mod.exports.hatched=e.mon.species;mod.exports.wasEgg=e.egg.isEgg
        mod.exports.hatchSlot=e.slot
      end)
    ]],
  })})
  T.eq(#run.errors,0,version..' '..format..' public lifecycle mod loads')
  local state=run.loader.exports.lifecycle_probe
  local save=require('src.core.SaveData').newGame()
  local a=Pokemon.new(data,'FIXMON_A',10)
  local b=Pokemon.new(data,'FIXMON_A',10)
  a.personality,b.personality=255,0;a.otId,b.otId=1,2
  DayCare.deposit(save,1,a);DayCare.deposit(save,2,b)
  T.eq(DayCare.gen3Score(data,save),70,'forwarded native compatibility remains 70 percent')
  T.eq(state.parent,'FIXMON_A','parent identity is available at the declared callback boundary')
  state.setScore(101);T.eq(DayCare.gen3Score(data,save),100,'authored chance clamps to native percent range')
  state.setScore(0/0);T.eq(DayCare.gen3Score(data,save),70,'nonfinite hook result falls back to actual native pair')
  state.setScore(100)
  local pen=DayCare.store(save);pen.steps=255;pen[2].steps=254
  local old=math.random;math.random=function(lo,hi)return lo or 0 end
  local made=DayCare.step(data,save)
  math.random=old
  T.eq(made,true,'authored score reaches actual native egg creation')
  T.eq(state.created,1,'native egg committed before exactly one event')
  T.eq(state.egg,pen.egg.species,'event observes committed egg identity')
  T.eq(state.odds,100,'egg event preserves exact rolled percentage')
  T.eq(state.mother,b.species,'event names actual parent')
  save.gen3Roamer={species='FIXMON_A',level=40,active=true,map='ROUTE_A'}
  local rolls=0
  local rng=function(lo,hi)rolls=rolls+1;return hi==15 and 1 or lo end
  T.eq(Roamer.step(data,save,'PLAYER_ROUTE',rng),'ROUTE_B','native connection moves the existing roamer')
  T.eq(rolls,2,'movement observer adds no RNG consumption')
  T.eq(state.moves,1,'one committed movement event')
  T.eq(state.from,'ROUTE_A','event retains original map')
  T.eq(state.to,'ROUTE_B','event names committed map')
  T.eq(state.index,1,'source contract uses a one-based roamer slot')
  T.eq(state.reason,'connection','connection reason uses reference vocabulary')
  T.eq(Roamer.check(data,save,'OTHER',rng),nil,'off-map encounter is refused')
  T.eq(state.meets,nil,'refusal emits no encounter')
  T.eq(Roamer.check(data,save,'ROUTE_B',rng),save.gen3Roamer,'actual native encounter preserves individual')
  T.eq(state.meets,1,'successful encounter emits exactly once')
  T.eq(state.met,'ROUTE_B','encounter reports actual map')
  T.eq(rolls,3,'encounter observer adds no RNG consumption')
  T.eq(Roamer.check(data,save,'ROUTE_B',function()return 1 end),nil,'native failed encounter roll stays refused')
  T.eq(state.meets,1,'failed native roll emits no new event')
  save.gen3Roamer.active=false
  T.eq(Roamer.step(data,save,'OTHER',rng),nil,'retired roamer stays inactive')
  T.eq(state.moves,1,'retired roamer cannot emit movement')
  local World=require('src.world.OverworldController')
  local upvalue,previous
  for n=1,100 do
    local key,value=debug.getupvalue(World.hatchEgg,n)
    if not key then break end
    if key=='Game' then upvalue,previous=n,value;break end
  end
  assert(upvalue)
  local egg=pen.egg;save.party={egg}
  local game={data=data,save=save,stack={states={}}}
  function game.stack:push(screen)table.insert(self.states,screen)end
  debug.setupvalue(World.hatchEgg,upvalue,game)
  T.eq(World.hatchEgg({},egg),true,'actual native Gen3 hatch is admitted')
  T.eq(state.hatches,nil,'hatch observer waits for native text completion')
  game.stack.states[1].onDone()
  T.eq(state.hatches,1,'native hatch completion emits exactly once')
  T.eq(state.hatched,egg.species,'hatch callback observes actual species')
  T.eq(state.wasEgg,true,'hatch callback retains the original egg record')
  T.eq(state.hatchSlot,1,'hatch callback retains actual party slot')
  debug.setupvalue(World.hatchEgg,upvalue,previous)
  T.check(Cap.supports('hooks','breeding.compatibility',version),'native producer is advertised')
  T.check(Cap.supports('events','breeding.egg_created',version),'native creation is advertised')
  T.eq(Cap.supports('events','pokerus.infected',version),false,'missing infection producer is not fabricated')
  run.release()
 end
end
T.finish('native GBA lifecycle producers through both mod callback formats')
