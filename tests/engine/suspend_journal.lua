package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local S=require('src.core.SaveSerializer')
local V=require('src.core.GameVersion');V.set('red')
local Save=require('src.core.SaveData')
local Game=require('src.core.Game')
local Stack=require('src.core.StateStack')
local World=require('src.world.OverworldController')
local J=require('src.core.SuspendJournal');J.buildId='fixture-build';J.contentId='fixture-content'
local rng=42
love.math.getRandomState=function()return tostring(rng)end
love.math.setRandomState=function(s)rng=assert(tonumber(s))end
love.math.newRandomGenerator=function()return {setState=function(_,s)assert(tonumber(s))end}end
love.math.random=function(a,b)
 rng=(rng*48271)%2147483647
 if not a then return rng/2147483647 end
 if not b then b=a;a=1 end
 return a+rng%(b-a+1)
end
love.data={}
local data=T.fixtures.fresh()
Stack:init();Game.stack=Stack;Game.data=data;Game.renderer=require('src.render.Renderer')
Game.input=require('src.core.Input');Game.input:init()
Game.save=Save.newGame({version='red',noHooks=true,pcItems={FIX_POTION=1}})
Save.validate(Game.save,data)
Game.save.party={require('src.pokemon.Pokemon').new(data,'FIXMON_A',30)}
Game.save.meta.playthroughId='native-suspend-test'
Game.save.player.map='FIX_TOWN';Game.save.player.x=2;Game.save.player.y=3;Game.save.player.facing='down'
Game.overworld=World;Game.world=World;Game.mods=nil;Game.modStatus={loaded={}}
World:_checkpointRebuild({map='FIX_TOWN',x=2,y=3,facing='down'});Stack.states={World}
local nativeUpdate=World.update
World.update=function(self,dt)
 if Game.input:wasPressed('a') and not Game.save.flags.SUSPEND_BATTLE_STARTED then
  Game.save.flags.SUSPEND_BATTLE_STARTED=true
  self.runner:run({{'start_battle','wild','FIXMON_C',5},{'set_flag','SUSPEND_STORY_CONTINUED'}})
 end
 return nativeUpdate(self,dt)
end
local function step(button)
 Game.input.state=button and {[button]=true} or {};Game.input.pressed=button and {[button]=true} or {};Game.input.sources={}
 J.step(Game,1/60,function()Game.stack:update(1/60)end)
 Game.save.playTime=(tonumber(Game.save.playTime) or 0)+1/60
end
step();step('a')
for i=1,1500 do
 local b=Stack:top()
 if b and b.isBattleState and b.phase=='menu' then break end
 step(i%3==0 and 'a' or nil)
end
T.check(Stack:top().isBattleState,'native script enters the actual shared battle engine')
T.check(World.runner:isRunning(),'story coroutine is waiting for its battle result')
local cp,code,detail=require('src.core.Checkpoint').capture(Game)
if not cp then local ok,why=pcall(require('src.core.CheckpointBattle').capture,Game,Stack:top(),function(v)return assert(S.decode(S.encodeExact(v)))end);error(tostring(detail)..' / '..tostring(why))end
-- Remain inside the same battle beyond the former 18,000-tick cutoff.
-- Rolling native decision checkpoints must compact history, not discard it.
for _=1,20040 do step()end
local long,reason=J.capture(Game);assert(long,reason)
T.eq(long.anchor.kind,'battle','a long battle establishes its own native checkpoint')
T.check(#long.steps<=J.BATTLE_CHECKPOINT_TICKS,'a long battle retains only the tail since its latest decision checkpoint')
-- A device can render a different number of frames from the replay. Nested
-- sprite caches can also point at a live monster; those references must not
-- change the canonical paths used for its actual HP, moves and battle stats.
local battle=Stack:top();local enemy=battle.enemy
local before=J.encode(J.witness(Game))
local presentation={enemy._caughtIcon,enemy.picAnim,enemy.monAnim,battle.scrollPx}
enemy._caughtIcon={mon=enemy.mon};enemy.picAnim={left=8};enemy.monAnim={clock=56}
battle.scrollPx=8;battle._gen3OamCompositedFrame=408;battle._gen3OamObjectRanks={};battle._gen3OamResidual='inactive'
T.eq(J.encode(J.witness(Game)),before,'render-only caches and their monster aliases do not change the semantic witness')
enemy._caughtIcon,enemy.picAnim,enemy.monAnim,battle.scrollPx=unpack(presentation,1,4)
battle._gen3OamCompositedFrame=nil;battle._gen3OamObjectRanks=nil;battle._gen3OamResidual=nil
local hp=enemy.mon.hp;enemy.mon.hp=hp-1
T.check(J.encode(J.witness(Game))~=before,'actual enemy damage still changes the witness')
enemy.mon.hp=hp
local capsule,why=J.capture(Game);assert(capsule,why)
local encoded=J.encode(capsule)
T.check(capsule.witness.states[#capsule.witness.states].kind=='battle','suspend retains an in-battle target rather than normal progress only')
local originalSave=Game.save
Stack.states={{screenId='TitleState'}}
local ok,problem=J.restore(Game,assert(S.decode(encoded)))
assert(ok,'native continuation replay restores from title: '..tostring(problem))
T.check(Game.save~=originalSave and Stack:top().isBattleState,'restore reconstructs new native objects')
T.check(World.runner:isRunning(),'waiting story coroutine is reconstructed without serializing Lua code')
T.check(Stack:top().player.mon==Game.save.party[1],'restored battle stays bound to the actual save party')
T.check(Stack:top().player.curMoves==Game.save.party[1].moves,'restored PP slots remain live save references')
T.check(Stack:top().participants[Game.save.party[1]],'experience participants bind to the restored party too')
T.eq(S.encode(J.witness(Game)),S.encode(capsule.witness),'reconstructed battle, progress, RNG and native phases match')
local battle=Stack:top();battle.result='win';battle:finish()
for _=1,300 do if Game.save.flags.SUSPEND_STORY_CONTINUED then break end;Game.stack:update(1/60)end
T.check(Game.save.flags.SUSPEND_STORY_CONTINUED,'finishing the restored battle continues the original story command after start_battle')
local changed=assert(S.decode(encoded));changed.build='other-build'
T.check(not J.restore(Game,changed),'different engine code is refused before touching the game')
local wrong=assert(S.decode(encoded));wrong.content='other-world-data'
T.check(not J.restore(Game,wrong),'different world scripts are refused as well as battle tables')
local prior=Game.save;local priorBytes=S.encode(prior);local priorRng=love.math.getRandomState()
Stack.states={{screenId='TitleState'}}
local corrupt=assert(S.decode(encoded));corrupt.witness.save.money=-1234
T.check(not J.restore(Game,corrupt),'a replay whose final state differs is rejected')
T.check(Game.save==prior and S.encode(Game.save)==priorBytes and Stack:top().screenId=='TitleState','failed replay rolls back the original save and screen owners')
T.eq(love.math.getRandomState(),priorRng,'failed replay preserves the original RNG')
Game.linkSession=true;T.check(not J.capture(Game),'online sessions cannot be rewound');Game.linkSession=nil
T.finish('Native suspend journal')
