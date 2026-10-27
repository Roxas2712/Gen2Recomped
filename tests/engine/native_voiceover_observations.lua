-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Ui=require('src.core.game3.battle.ui')
local Voice=require('src.battle.Gen3VoiceoverPresentation')
local Battle=require('src.core.game3.battle')
local G=require('src.core.Game3')
local Summary=require('src.ui.Gen3SummaryLayout')
local original,features=package.loaded['src.core.Game'],package.loaded['src.mods.FeatureOptions']
T.eq(Ui.voiceoverDim(),0);T.eq(Ui.litHealthboxShown(),false);T.eq(Ui.quickBallPrompt(),nil)
local inverse={[9]=0,[10]=1,[11]=2,[12]=3}
for max=1,64 do for pp=0,max do
 T.eq(Ui.ppColorState(pp,max),inverse[Summary.ppColor(pp,max)])
 T.eq(Ui.ppColorIndex(pp,max),Summary.ppColor(pp,max),'existing palette-index ABI remains unchanged')
end end
T.eq(Ui.ppColorState('0','10'),2);T.eq(Ui.ppColorState(0,0),3)
T.eq(Ui.ppColorState(0/0,10),nil);T.eq(Ui.ppColorState(1,math.huge),nil)
T.eq(Ui.moveTypeOf(nil,1,{type=0}),0);T.eq(Ui.moveTypeOf({moveTypes={[2]=7}},2,{type=0}),7)
T.eq(Ui.moveTypeOf({moveTypes={[2]=0}},2,{type=7}),0,'numeric zero is a real type identity')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
 package.loaded['src.core.Game']=game
 local b=f.fresh('TACKLE').battle;b.enter=false;b:syncSides();game.stack:push(b)
 b.phase='messages';b.queue={};b.current=nil;b.waitFrames=0;b.introSlide=0
 local rolls=0;b.rng=function()rolls=rolls+1;return 1 end
 local frame=b.frame;for _=1,12 do T.eq(Ui.voiceoverDim(),0);T.eq(Ui.litHealthboxShown(),false)end
 T.eq(b.gen3Voiceover,nil);T.eq(b.frame,frame)
 if edition=='firered'or edition=='leafgreen'then
  game.data.constants.gen3TeachyTV={voiceovers={status={[2]='Native voice'}}}
  b.pokedudeDemo={lesson='status',voiceDone={}}
  T.eq(b:queuePokedudeVoices({2}),true)
  local cue=b.queue[1];T.eq(cue.gen3Voiceover,true);T.eq(cue.gen3VoiceoverHealthbox,true)
  T.eq(b:updateQueue(),true);T.eq(b.current,nil,'native queue holds the caption until its fade finishes')
  for tick=1,80 do
   b:tickFx();T.eq(Ui.voiceoverDim(),math.min(8,math.floor(tick/5))/16)
   T.eq(Ui.litHealthboxShown(),tick==80)
   T.eq(b:updateQueue(),true)
   if tick<80 then T.eq(b.current,nil)end
  end
  T.eq(b.current,cue);T.eq(b.gen3Voiceover.phase,'message');T.eq(Ui.voiceoverDim(),.5)
  local state=b.gen3Voiceover;local clock=state.clock;local nativeFrame=b.frame
  for _=1,10 do T.eq(Ui.voiceoverDim(),.5);T.eq(Ui.litHealthboxShown(),true)end
  T.eq(b.gen3Voiceover,state);T.eq(state.clock,clock);T.eq(b.frame,nativeFrame)
  -- Finish the caption through the actual native typer/input owner.
  game.input.wasPressed=function(_,key)return key=='a'or key=='b'end
  local ticks=0
  while b.current and ticks<500 do b:tickFx();b:updateQueue();ticks=ticks+1 end
  T.check(ticks<500,'native input releases the typed voiceover')
  game.input.wasPressed=function()return false end
  local actions=0;b:act(function()actions=actions+1 end)
  T.eq(b:updateQueue(),true);T.eq(b.gen3Voiceover.phase,'unhighlight')
  for tick=1,79 do b:tickFx();b:updateQueue();T.eq(actions,0,'native action waits for both return fades')end
  b:tickFx();b:updateQueue();T.eq(actions,1);T.eq(b.gen3Voiceover,nil)
  T.eq(Ui.voiceoverDim(),0);T.eq(Ui.litHealthboxShown(),false)
  -- Ordinary native narration has only one fade in/out, without spotlight.
  b.pokedudeDemo=nil;b.current=nil;b.queue={};Voice.queue(b,'Native caption',false)
  b:updateQueue()
  for _=1,40 do b:tickFx();b:updateQueue()end
  T.eq(b.current,b.gen3Voiceover.cue);T.eq(Ui.voiceoverDim(),.5);T.eq(Ui.litHealthboxShown(),false)
  local saved=game.save;game.save={};T.eq(Ui.voiceoverDim(),.5,'the native controller remains the actual owner')
  game.save=saved
 else
  b:say('Ordinary native text');b:updateQueue()
  T.neq(b.current,nil);T.eq(b.gen3Voiceover,nil,'Hoenn narration does not enter a FR/LG controller')
 end
 -- Quick-item labels come from the same native availability and inventory owner.
 b.current=nil;b.queue={};b.gen3Voiceover=nil;b.pokedudeDemo=nil;b.phase='menu';b.afterQueue='menu'
 b.showPlayerBack=false;b.showEnemyTrainer=false;b.enemySendingOut=nil
 b:updateQueue() -- Let this older native queue retire its insertion cursor before readiness.
 for _,who in ipairs{b.player,b.enemy}do who.shownHP=who.mon.hp;who.shownStatus=who.mon.status end
 package.loaded['src.mods.FeatureOptions']={enabled=function(key)return key=='quickBall'end}
 game.data.items.POKE_BALL={index=4,name='NATIVE BALL',effect='BALL'}
 game.save.inventory.POKE_BALL=2
 T.eq(Ui.quickBallPrompt(),'NATIVE BALL\nL: NEXT R: THROW')
 game.save.inventory.POKE_BALL=0;T.eq(Ui.quickBallPrompt(),nil)
 game.save.inventory.POKE_BALL=2;game.stack:push({});T.eq(Ui.quickBallPrompt(),nil);game.stack:pop()
 T.eq(rolls,0,'presentation cannot roll combat RNG')
 game.stack:pop();T.eq(Ui.voiceoverDim(),0);T.eq(Ui.litHealthboxShown(),false)
 Battle._service.release();f.close();G.release()
end
package.loaded['src.core.Game']=original;package.loaded['src.mods.FeatureOptions']=features
T.finish('native tutorial cue clock/queue, observational UI, PP/type and quick-item contracts')
