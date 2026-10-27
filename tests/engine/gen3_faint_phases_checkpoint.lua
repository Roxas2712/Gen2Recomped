-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared semantic-state qualification, not an ordinary gameplay save claim.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
love=require('tests.love_stub')
local seed=718834
love.math.random=function(a,b)
  seed=(seed*48271)%2147483647
  if not a then return seed/2147483647 end
  if not b then a,b=1,a end
  return a+seed%(b-a+1)
end
love.math.getRandomState=function()return tostring(seed)end
love.math.setRandomState=function(value)seed=assert(tonumber(value))end
love.math.newRandomGenerator=function()return{setState=function(_,value)assert(tonumber(value))end}end
local Fixture=require('tests.checkpoint_fixture')
local Serializer=require('src.core.SaveSerializer')
local function copy(value)return assert(Serializer.decode(Serializer.encode(value)))end
local function field(graph,ref,key)
  for _,e in ipairs(graph.nodes[assert(ref.node)].entries)do if e.key==key then return e end end
  error('missing semantic field '..key)
end
for _,edition in ipairs({'ruby','emerald'})do
  local f=Fixture.boot(edition,3,'unified');local game=f.game
  local b=require('src.battle.BattleState').newTrainer(game,'OPP_FIX_YOUNGSTER',1)
  b.phase,b.queue,b.introSlide='menu',{},0;b:syncSides();f.stack.states={f.world,b}
  local actor=b.player
  -- Prepared legal semantic state: raw mod HP writes may coexist with the
  -- native logical marker. Native HP-command production is qualified in
  -- gen3_faint_phases; this test isolates serialization and preflight.
  require('src.battle.Gen3Faint').mark(actor)
  T.eq(actor._gbaLogicalFaint,true,'prepared marker uses the actual native owner')
  local cp,why=f.checkpoints:capture(game)
  if not cp then
    local accepted,detail=pcall(require('src.core.CheckpointBattle').capture,game,b,copy)
    if not accepted then print('Native checkpoint rejection: '..tostring(detail))end
  end
  T.check(cp~=nil,'prepared faint state capture '..tostring(why));assert(cp,why)
  local graph=cp.runtime.battle.graph;local player=field(graph,graph.root,'player').value
  T.eq(field(graph,player,'_gbaLogicalFaint').value.scalar,true,'native logical state is serialized')
  for _,invalid in ipairs({0,1,0.5,'true'})do
    local bad=copy(cp);local g=bad.runtime.battle.graph
    field(g,field(g,g.root,'player').value,'_gbaLogicalFaint').value={scalar=invalid}
    local save,top=game.save,f.stack:top();local ok,reason=f.checkpoints:restore(game,bad)
    T.eq(ok,false,'invalid native faint marker is rejected')
    T.eq(reason,'invalid_battle_state','native marker preflight reason')
    T.eq(game.save,save,'rejected marker does not publish a save');T.eq(f.stack:top(),top,'rejected marker does not publish a battle')
  end
  local ok,reason=f.checkpoints:restore(game,copy(cp));T.eq(ok,true,'native faint state restores '..tostring(reason));assert(ok,reason)
  local resumed=f.stack:top();T.eq(resumed.player._gbaLogicalFaint,true,'cold graph retains native logical death')
  resumed.player.mon.hp=10
  local move=resumed.player.curMoves[1];local before=move.pp
  resumed:executeAction(resumed.player,resumed.enemy,move)
  T.eq(move.pp,before,'raw HP cannot revive a cold-restored logically fainted actor')
  resumed:abilityHeal(resumed.player,1,4)
  T.eq(resumed.player._gbaLogicalFaint,nil,'real native healing clears the restored marker')
  T.eq(require('src.battle.Gen3Faint').isFainted(resumed.player),false,'native healed actor is alive again')
  local seen=0
  f.loaded.loader.exports.checkpoint_fixture.api.events:on('battle.fainted',function()
    seen=seen+1
    local accepted,detail=pcall(require('src.core.CheckpointBattle').capture,game,resumed,copy)
    T.eq(accepted,false,'native checkpoint owner rejects a half-announced faint')
    T.check(tostring(detail):find('faint announcement is active',1,true)~=nil,'native announcement guard precedes graph construction')
  end)
  require('src.battle.Gen3Faint').mark(resumed.player)
  resumed:onFaint(resumed.player)
  T.eq(seen,1,'real native emitter reaches the announcement guard')
  T.eq(resumed._gbaFaintAnnouncement,nil,'announcement owner retires after callbacks')
  f.close()
end
T.finish('native faint-state cold serialization, strict marker preflight and genuine heal ownership')
