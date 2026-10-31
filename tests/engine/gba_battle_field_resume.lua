-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=require('tests.checkpoint_fixture')
local VM=require('src.script.Gen3ScriptVM')
local C=require('src.script.Gen3Commands')
local S=require('src.core.SaveSerializer')
local rng='owned-field-return-rng'
love.math.getRandomState=function()return rng end
love.math.setRandomState=function(v)rng=v end

for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 for _,mode in ipairs{'win','caught','run','checkpoint','yielding'}do
  local f=Fixture.boot(edition,3);local game,world,stack=f.game,f.world,f.stack
  local id='OWNED_BATTLE_RETURN_'..edition..'_'..mode
  local def=require('src.mods.Merge').deepCopy(game.data.maps.FIX_TOWN)
  def.id=id;game.data.maps[id]=def
  world:setMap(id,2,3,'down',{via='boot'})
  game.data.map_scripts={source='RomExtractorGen3',maps={[id]={callbacks={
   {type=3,script='TRANSITION'},{type=5,script='RESUME'},{type=1,script='LOAD'}}}},scripts={
   LOAD={{'addvar',0x4063,1},{'end'}},TRANSITION={{'addvar',0x4064,1},{'end'}},
   RESUME={{'checkflag',0x830},{'goto_if',1,'CLEAN'},{'end'}},
   CLEAN={{'addvar',0x4061,1},{'copyvar',0x4062,0x8004},
    {'setflag',0x3D5},{'end'}}}}
  if mode=='yielding'then table.insert(game.data.map_scripts.scripts.CLEAN,2,{'delay',2})end
  VM.register(game.data,'scenes')
  local oldPush=world.pushBattle
  world.pushBattle=function(_,battle)stack.states[#stack.states+1]=battle end
  world.runner:run({{'g3_set_flag','FLAG_G3_0830'},
   {'g3_setvar',0x8004,19},{'start_battle','wild','FIXMON_B',10},
   {'g3_clear_flag','FLAG_G3_0830'},{'set_flag','OWNED_SUFFIX'}},
   {mapId=id,npc=world.npcs[1]})
  world.pushBattle=oldPush
  local battle=stack:top();battle.phase,battle.queue,battle.introSlide='menu',{},0
  T.eq(C.getVar(game.save,0x4061),0,'No return callback while the battle is active')
  T.eq(game.save.flags.OWNED_SUFFIX,nil,'Caller remains suspended')
  if mode=='checkpoint'then
   local cp,code,detail=f.checkpoints:capture(game)
   T.check(cp~=nil,'Actual script battle checkpoint captures: '..tostring(code)..' '..tostring(detail))
   if cp then
    local bytes=S.encode(cp)
    local ok,why=f.checkpoints:restore(game,cp);T.check(ok,'Actual native checkpoint restores: '..tostring(why))
    if ok then
     battle=stack:top()
     T.eq(C.getVar(game.save,0x4061),0,'Restoring the battle does not replay return scripts')
     T.eq(S.encode(assert(f.checkpoints:capture(game))),bytes,'Complete restored battle recaptures unchanged')
    end
   end
  end
  stack.states={world};battle.onFinish(mode=='caught'and'caught'or mode=='run'and'run'or'win')
  for _=1,20 do if not world.runner:isRunning()then break end;world.runner:update(1/60)end
  T.eq(C.getVar(game.save,0x4061),1,'Native ON_RESUME runs exactly once before the event suffix')
  T.eq(C.getVar(game.save,0x4062),19,'Return callback observes the original temporary battle arguments')
  T.eq(game.save.flags.FLAG_G3_03D5,true,'Callback cleanup executes while its control flag is set')
  T.eq(game.save.flags.FLAG_G3_0830==true,false,'Caller clears the flag after callback cleanup')
  T.eq(game.save.flags.OWNED_SUFFIX,true,'Caller continues after the return callback, including a yielded callback')
  T.eq(C.getVar(game.save,0x4063),0,'Battle return does not run ON_LOAD')
  T.eq(C.getVar(game.save,0x4064),0,'Battle return does not run ON_TRANSITION')
  T.eq(world.runner:isRunning(),false,'The original runner terminates normally')
  -- The world completion pass must not request the scripted return again.
  T.eq(battle.g3FieldResumed,true,'The completed battle owns its return receipt')
  T.eq(#(world.pendingScripts or{}),0,'Scripted callbacks are not delayed in the world queue')
  f.close()
 end
end

-- An ordinary wild battle has no suspended event caller; the field runner
-- owns its queued callback and must not request it a second time.
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen','red','crystal'}do
 local f=Fixture.boot(edition,3);local game,world=f.game,f.world
 local id='OWNED_RANDOM_RETURN_'..edition
 local def=require('src.mods.Merge').deepCopy(game.data.maps.FIX_TOWN)
 def.id=id;game.data.maps[id]=def;world:setMap(id,2,3,'down',{via='boot'})
 game.data.map_scripts={source='RomExtractorGen3',maps={[id]={callbacks={{type=5,script='RESUME'}}}},
  scripts={RESUME={{'addvar',0x4061,1},{'end'}}}}
 VM.register(game.data,'scenes')
 local battle=require('src.battle.BattleState').newWild(game,'FIXMON_B',10)
 world:afterBattle('run',battle)
 local gba=require('src.core.GameVersion').isGen3()
 T.eq(#(world.pendingScripts or{}),gba and 1 or 0,'Only GBA battle returns queue the native callback')
 local jobs=world.pendingScripts or{};world.pendingScripts={}
 for _,job in ipairs(jobs)do world.runner:run(job.script,job.extra)end
 T.eq(C.getVar(game.save,0x4061),gba and 1 or 0,'The actual field runner executes the queued callback')
 world:afterBattle('run',battle)
 T.eq(#(world.pendingScripts or{}),0,'Repeated completion cannot queue the callback twice')
 f.close()
end

-- The same prelude refuses a retired map and consumes its receipt once.
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 local f=Fixture.boot(edition,3);local world=f.world
 local calls=0;local original=world.gen3FieldResumed
 world.gen3FieldResumed=function()calls=calls+1 end
 local Commands=require('src.script.Commands')
 if not Commands._resumeFieldAfterBattle then
  T.check(false,'The native field-return prelude is available')
 else
 local battle={};local ctx={overworld=world,gen3PendingFieldReturn={battle=battle,map={id='OLD_MAP'}}}
 Commands._resumeFieldAfterBattle(ctx)
 T.eq(calls,0,'A map retired by whiteout/warp cannot receive old battle callbacks')
 T.eq(ctx.gen3PendingFieldReturn,nil,'Retired-map receipt is consumed')
 ctx.gen3PendingFieldReturn={battle=battle,map=world.map}
 Commands._resumeFieldAfterBattle(ctx);Commands._resumeFieldAfterBattle(ctx)
 T.eq(calls,1,'Repeated completion consumes one callback receipt')
 end
 world.gen3FieldResumed=original;f.close()
end
T.finish('All five GBA battle returns precede native event continuation and survive native checkpoint reconstruction')
