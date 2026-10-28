-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local T=require('tests.harness');love=require('tests.love_stub')
love.math.getRandomState=function()return 'owned-double-checkpoint'end
love.math.setRandomState=function()end
local F=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
local Serializer=require('src.core.SaveSerializer')
local function copy(value)return assert(Serializer.decode(Serializer.encode(value)))end
local function field(graph,reference,key)
 for _,entry in ipairs(graph.nodes[assert(reference.node)].entries)do if entry.key==key then return entry end end
 error('missing checkpoint graph field '..tostring(key))
end
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,two in ipairs({false,true})do
  local f=F.boot(edition);local game=f.game
  game.save.party[2]=copy(game.save.party[1])
  local trainer=game.data.trainers.OPP_FIX_YOUNGSTER;trainer.doubleBattle=true
  if two then game.data.trainers.OPP_CHECKPOINT_SECOND={id='OPP_CHECKPOINT_SECOND',name='SECOND',pic='tests/fixture_data/assets/fix_sprite.png',parties={{copy(trainer.parties[1][1])}}}end
  local battle=Native.newTrainer(game,'OPP_FIX_YOUNGSTER',1)
  if two then T.check(battle:addOpponentTrainer('OPP_CHECKPOINT_SECOND'),'actual second trainer admitted')end
  battle.phase,battle.queue,battle.introSlide='menu',{},0;battle:syncSides()
  for position=0,3 do battle:picFxFor(battle:battlerAt(position)).minimized=true end
  f.stack.states={f.world,battle}
  local cp,reason=f.checkpoints:capture(game)
  T.check(cp~=nil,edition..': native double captured '..tostring(reason))
  if cp then
   T.check(f.checkpoints:restore(game,cp),'native double restored')
   local fresh=f.stack:top()
   for position=0,3 do
    T.eq(fresh:picFxFor(fresh:battlerAt(position)).minimized,true,'picture effect belongs to restored position '..position)
   end
   local invalid={
    {'right HP',function(g,actor)field(g,field(g,actor,'mon').value,'hp').value={scalar=-1}end},
    {'right moves',function(g,actor)field(g,actor,'curMoves').value={scalar=false}end},
    {'right stages',function(g,actor)field(g,actor,'stages').value={scalar=false}end},
   }
   for _,side in ipairs({1,2})do
    for _,case in ipairs(invalid)do
     local bad=copy(cp);local graph=bad.runtime.battle.graph
     local sides=field(graph,graph.root,'sides').value
     local actors=field(graph,field(graph,sides,side).value,'battlers').value
     local actor=field(graph,actors,2).value
     if case[1]=='right HP'and side==1 then
      -- Player monsters are anchors into the saved party, not graph nodes.
      bad.save.party[2].hp=-1
     else case[2](graph,actor)end
     local save,top=game.save,f.stack:top();local ok,why=f.checkpoints:restore(game,bad)
     T.eq(ok,false,case[1]..': invalid right battler rejected')
     T.check(why=='invalid_battle_state'or why=='invalid_save',case[1]..': validation reason')
     T.eq(game.save,save,'invalid right battler preserves save')
     T.eq(f.stack:top(),top,'invalid right battler preserves controller')
    end
   end
   if two then
    local bad=copy(cp);local g=bad.runtime.battle.graph
    field(g,g.root,'oppClassB').value={scalar='MISSING_SECOND_TRAINER'}
    local save=game.save;local ok,why=f.checkpoints:restore(game,bad)
    T.eq(ok,false,'unavailable second trainer rejected');T.eq(why,'invalid_battle_state','second trainer rejected in preflight')
    T.eq(game.save,save,'unavailable second trainer preserves save')
   end
  end
  f.close()
 end
end
T.finish('native double checkpoint pictures, second trainer resources and right battler preflight')
