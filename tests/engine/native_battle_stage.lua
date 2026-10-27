-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local A=require('src.core.game3.battle.anim')
local Stage=require('src.core.game3.battle.stage')
local Battle=require('src.core.game3.battle')
local Native=require('src.battle.Gen3Battle')
local Ball=require('src.battle.Gen3BallAnim')
local G=require('src.core.Game3')
local original=package.loaded['src.core.Game']
T.eq(A.stage(),nil,'a stage cannot invent a native battle')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
 package.loaded['src.core.Game']=game
 local b=f.fresh('TACKLE').battle;b.enter=false;game.stack:push(b)
 b.introSlide=8;b.frlgIntro={t=0,hold=2};b.showPlayerBack=true;b.showEnemyTrainer=true
 b.introBalls=true;b.introBallsFrom=nil
 local stage=A.stage();T.eq(stage,A.stage(),'one stage identity per native admission')
 T.eq(stage.slideDone,false);T.eq(stage.win0[1],80);T.eq(stage.win0[2],80)
 T.eq(stage.trainer.player.visible,true);T.eq(stage.trainer.enemy.visible,true)
 local frame=b.frame;local queue=#b.queue;local rolls=0;b.rng=function()rolls=rolls+1;return 1 end
 local mask=stage.win0;local trainer=stage.trainer.player;local box=stage.healthbox.player
 for _=1,8 do
  T.eq(stage.healthbox[0],box);T.eq(box.visible,false)
  T.eq(stage.healthbox[1].visible,false);T.eq(stage.healthbox[2].visible,false)
  T.eq(stage.bgSlide.playerOx,-stage.bgSlide.enemyOx)
 end
 T.eq(b.frame,frame);T.eq(#b.queue,queue);T.eq(rolls,0)
 T.eq(b.introBallsFrom,nil,'queries cannot stamp the party-bar clock')
 local copied={};for key,value in pairs(stage)do copied[key]=value end
 T.eq(copied.trainer,stage.trainer);T.eq(copied.win0,mask)
 T.raises(function()stage.slide=1 end,'read-only');T.raises(function()trainer.visible=false end,'read-only')
 for _,t in ipairs{0,1,32,33,43,44,60}do
  b.frlgIntro.t=t;local top,bottom=Native.introWindow(b)
  if t<44 then T.eq(stage.win0[1],top);T.eq(stage.win0[2],bottom)
  else T.eq(stage.win0,nil);T.eq(mask[1],nil)end
 end
 b.frlgIntro.hold=0;b.introSlide=0;b.showPlayerBack=false;b.showEnemyTrainer=false;b.introBalls=nil
 T.eq(stage.slideDone,true);T.eq(box.visible,true);T.eq(stage.healthbox.enemy.visible,true)
 b.player.fainted=true;T.eq(box.visible,true,'native single player panel remains during completion')
 b.enemy.fainted=true;T.eq(stage.healthbox.enemy.visible,false)
 b.player.fainted=false;b.enemy.fainted=false
 b.demo=true;T.eq(box.visible,false);b.demo=nil;b.safari=true;T.eq(box.visible,false);b.safari=nil
 game.data.field=game.data.field or{};game.data.field.playerForms={boy={},girl={}}
 game.save.player.gender='girl';T.eq(trainer.gender,1)
 game.save.player.gender='boy';T.eq(trainer.gender,0)
 b.picOff={back={x=-12},foe={x=7}};T.eq(trainer.ox,-12);T.eq(stage.trainer.enemy.ox,7)
 game.data.constants.gen3BallAnim={timing={},sounds={}}
 local a=Ball.new(game.data,{ball=3,battler=b.player,sendOut='player',to={x=72,y=80}})
 b.gen3Ball=a;b.gen3BallPlaying=true
 local ball=stage.ball;T.eq(ball,stage.balls[0]);T.eq(stage.balls[1],nil);T.eq(ball.ballId,3)
 T.eq(ball.battler,0);T.eq(ball.side,'player');T.eq(ball.frame,0);T.eq(ball.visible,true)
 for i=1,3 do a:update();T.eq(ball.x,a.x+(a.shakeOffset or 0));T.eq(ball.y,a.y);T.eq(ball.frame,a.ballFrame-1)end
 T.eq(b.frame,frame);T.eq(rolls,0);T.eq(a.frame,3)
 b.gen3Ball=Ball.new(game.data,{ball=1,battler=b.enemy,sendOut='opponent'})
 T.eq(ball.visible,false,'an old ball cannot project a replacement timeline')
 T.neq(stage.ball,ball);T.eq(stage.ball,stage.balls[1]);T.eq(stage.ball.side,'enemy')
 b.gen3Ball=nil;T.eq(stage.ball,nil)
 local cover={};game.stack:push(cover);T.eq(A.stage(),stage,'covered native stages remain observable');game.stack:pop()
 local previous=game.save;game.save={};local replacement=A.stage();T.neq(replacement,stage)
 T.eq(trainer.visible,false);T.eq(box.visible,false);T.eq(stage.slideDone,nil)
 game.save=previous;T.neq(A.stage(),stage,'restoring an old cohort cannot revive a retained stage')
 game.stack:pop();T.eq(A.stage(),nil);T.eq(mask[1],nil)
 Stage._service.release();f.close();G.release()
end
-- Preserve capture identity: the catch observer and full stage must point
-- at the same actual ball, including its post-catch resting frame.
do
 local f=require('tools.battle-source-runtime.fixture').new('firered');local game=f.game
 package.loaded['src.core.Game']=game
 game.data.constants.itemOrder={[4]='POKE_BALL'};game.data.items.POKE_BALL={index=4,name='POKE BALL'}
 game.data.constants.gen3BallAnim={timing={},sounds={},itemToBall={[4]=0}}
 local b=f.fresh('TACKLE').battle;b.enter=false;game.stack:push(b)
 b.phase='messages';b.queue={};b.current=nil;b.nextInsert=nil;b.rng=function(lo)return lo or 0 end
 local Catch=require('src.core.game3.battle.catch_seq')
 b:throwBall('POKE_BALL');local entry=b.queue[#b.queue];b.queue={entry};b:updateQueue()
 local native=b.gen3Ball
 T.neq(native,nil);T.eq(A.stage().ball,Catch._ball.stage)
 T.eq(A.stage().ball.ballId,native.ball);T.eq(A.stage().ball.battler,1)
 local held=A.stage().ball;game.stack:pop();T.eq(held.visible,false)
 Catch._service.release();Stage._service.release();f.close();G.release()
end
package.loaded['src.core.Game']=original
T.finish('native battle stage, actual entry/HUD/ball/window state, capture identity and retirement')
