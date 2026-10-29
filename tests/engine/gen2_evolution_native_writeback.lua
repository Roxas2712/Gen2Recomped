package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');Version.set('crystal')
require('src.core.ModCompat').install()
local Anim=require('src.ui.gen2.EvolutionAnim')
local Game=require('src.core.Game')
local Stack=require('src.core.StateStack')
local Runtime=require('src.mods.Runtime')
local emit=Runtime.emit;local events={}
Runtime.emit=function(name,event)if name=='pokemon.evolved'then events[#events+1]=event end end
for _,case in ipairs{{force=false},{force=true},{force=true,customSave=true}}do
 local force=case.force
 local previousEvents=#events
 local data=T.fixtures.fresh();data.constants.gen=2
 data.pokemon.FIXMON_B.learnset={};data.pokemon.FIXMON_B.levelMoves={}
 T.link.prepare(data)
 local g=setmetatable(T.link.fakeGame(data,'FIXMON_A',{level=10}),{__index=Game})
 local mon=g.save.party[1];mon.hp=mon.stats.hp-3
 g.save.pokedex={seen={},owned={}}
 local targetSave=case.customSave and{party=g.save.party,pokedex={seen={},owned={}}}or g.save
 local beforeHp,stats=mon.hp,mon.stats
 local stack=setmetatable({},{__index=Stack});stack:init();g.stack=stack
 local base={};stack:push(base)
 local state,answer,answers
 answers=0
 g.input={wasPressed=function(_,key)return key=='b'and state and state.phase=='flash'end}
 state=Anim.new(g,{mon=mon,index=1,save=targetSave,entry=force and{species='FIXMON_B'}or{into='FIXMON_B'},force=force,
  onDone=function(result)answer=result;answers=answers+1 end})
 stack:push(state)
 T.eq(state.newSpecies,'FIXMON_B','native and source target spellings select the same picture')
 T.eq(mon.species,'FIXMON_A','construction never commits a species change')
 for frame=1,1200 do
  state:update(1/60)
  if state.phase=='done'then break end
 end
 T.eq(state.phase,'done','native constructor completes the GSC movie')
 T.eq(answers,1,'native constructor notifies once')
 T.eq(stack:top(),base,'movie removes only its own screen')
 T.eq(g.save.party[1],mon,'movie retains the live native party record')
 if force then
  T.eq(mon.species,'FIXMON_B','forced evolution ignores B during flash')
  T.eq(mon.stats.hp-mon.hp,3,'native stat owner preserves damage')
  T.neq(mon.stats,stats,'native owner recalculates evolved stats')
  T.check(targetSave.pokedex.seen.FIXMON_B and targetSave.pokedex.owned.FIXMON_B,'native owner registers seen and caught in the selected save')
  if case.customSave then T.eq(g.save.pokedex.owned.FIXMON_B,nil,'explicit source save does not mark an unrelated live save')end
  T.eq(answer.evolved,mon,'legacy result exposes the same actual native record')
  T.eq(#events,previousEvents+1,'native evolution emits exactly one notification')
  T.eq(events[#events].mon,mon,'native event carries the actual party record')
 else
  T.eq(mon.species,'FIXMON_A','B cancellation leaves species intact')
  T.eq(mon.stats,stats,'B cancellation leaves native stats intact')
  T.eq(mon.hp,beforeHp,'B cancellation leaves damage intact')
  T.check(answer.canceled,'legacy result reports cancellation')
  T.eq(#events,0,'B cancellation emits no evolved notification')
 end
 state:update(1/60);T.eq(answers,1,'finished movie does not repeat writeback or callback')
end
Runtime.emit=emit
T.finish()
