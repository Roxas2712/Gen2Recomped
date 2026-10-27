-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Chrome=require('src.ui.game3.battle_chrome')
local Native=require('src.battle.Gen3Battle')
local Battle=require('src.core.game3.battle')
local Ui=require('src.core.game3.battle.ui')
local Stage=require('src.core.game3.battle.stage')
local Assets=require('src.render.Assets')
local G=require('src.core.Game3')
local original=package.loaded['src.core.Game']
local image,draw=Assets.image,love.graphics.draw
local bar=love.graphics.newCanvas(128,8);local balls=love.graphics.newCanvas(32,8)
Assets.image=function(path)if path=='qa-native-party-bar'then return bar elseif path=='qa-native-party-balls'then return balls else return image(path)end end
local trace={}
love.graphics.draw=function(...)trace[#trace+1]={...}end
T.eq(Chrome.drawPartyBar(),false,'no invented battle or party owner')
local function record()
 return{bar='qa-native-party-bar',balls='qa-native-party-balls',count=6,barWidth=128,barHeight=8,ballSide=8,step=10,
  icons={empty=0,alive=1,status=2,fainted=3},
  player={barX=136,barY=96,ballX=160,ballY=88,packFrom=1,packStep=1},
  opponent={barX=-24,barY=40,ballX=30,ballY=33,packFrom=6,packStep=-1,flip=true}}
end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game;package.loaded['src.core.Game']=game
 local b=f.fresh('TACKLE').battle;b.enter=false;game.stack:push(b)
 local summary=record();game.data.constants.gen3BattleHud={partySummary=summary}
 b.kind='trainer';b.introBalls=true;b.introBallsFrom=nil;b.frame=40
 b.enemyParty={{species='CHARMANDER',hp=20},{species='CHARMANDER',hp=0},{species='CHARMANDER',hp=10,status='PAR'}}
 local frame,queue=b.frame,#b.queue;local rolls=0;b.rng=function()rolls=rolls+1;return 1 end
 local stage=Stage.current();T.eq(stage.partyBar.player.visible,true);T.eq(stage.partyBar.enemy.visible,true)
 T.eq(b.introBallsFrom,nil,'observations do not start the paint clock')
 -- Both the native HUD entry point and public drawing borrow one renderer.
 for _,player in ipairs{true,false}do
  for _,age in ipairs{0,1,7,14,17,18,33,40}do
   b.introBallsFrom=40;b.frame=40+age;trace={}
   T.eq(Native.drawPartySummary(b,player),true);local expected=trace;trace={}
   local row=stage.partyBar[player and'player'or'enemy']
   T.eq(Chrome.drawPartyBar(row.x,row.y,row.balls,row.ox,not player,row),true)
   T.same(trace,expected,'same native bar/packed icons at age '..age)
  end
 end
 b.frame=40;b.introBallsFrom=nil;trace={}
 local row=stage.partyBar.player
 T.eq(Chrome.drawPartyBar(row.x,row.y,row.balls,row.ox,false,row),true)
 T.eq(b.introBallsFrom,40,'first real public paint starts the same native stamp')
 T.eq(#trace,1,'icons wait for the native landing time')
 b.frame=80;trace={};love.graphics.setColor(.2,.3,.4,.5)
 T.eq(Chrome.drawPartyBar(141,103,row.balls,2,false,{alpha=.5,ballHidden={true,false,true,true,true,true},ballOx={[2]=7}}),true)
 T.eq(#trace,2);T.same({trace[1][2],trace[1][3]},{143,103})
 T.same({trace[2][3],trace[2][4]},{182,95},'native icon geometry plus per-icon offset')
 T.same({love.graphics.getColor()},{.2,.3,.4,.5})
 local nativeBar,nativeBalls=bar,balls
 bar=love.graphics.newCanvas(256,16);balls=love.graphics.newCanvas(96,24);trace={}
 T.eq(Chrome.drawPartyBar(136,96,row.balls,0,false,{ballHidden={}}),true)
 T.same({trace[1][4],trace[1][5],trace[1][6]},{0,.5,.5},'bar texel density preserves its logical size')
 T.same({trace[2][5],trace[2][6],trace[2][7]},{0,1/3,1/3},'icons may have a different texel density')
 T.eq(trace[2][2].w,24,'icon quad uses physical texels')
 bar,nativeBar=nativeBar,bar;balls,nativeBalls=nativeBalls,balls
 T.eq(b.frame,80);T.eq(#b.queue,queue);T.eq(rolls,0,'painting never consumes battle RNG')
 local base=Chrome.drawPartyBar;local wrappers=0
 Chrome.drawPartyBar=function(...)wrappers=wrappers+1;base(...);return base(...)end
 trace={};T.eq(Native.drawPartySummary(b,true),true);T.eq(wrappers,1);T.eq(#trace,7,'nested bases borrow the native row once')
 Chrome.drawPartyBar=function()return false end;b.introBallsFrom=nil;trace={}
 T.eq(Native.drawPartySummary(b,true),false);T.eq(#trace,0);T.eq(b.introBallsFrom,nil,'held drawing does not start a clock')
 Chrome.drawPartyBar=base
 local function bad(opts)
  b.introBallsFrom=nil
  T.raises(function()Chrome.drawPartyBar(nil,nil,nil,nil,false,opts)end,'party summary')
  T.eq(b.introBallsFrom,nil,'invalid options cannot stamp presentation')
 end
 for _,opts in ipairs{{alpha=0/0},{alpha=2},{ballHidden={1}},{ballOx={math.huge}},{extended=true}}do bad(opts)end
 T.raises(function()Chrome.drawPartyBar(0/0,1)end,'invalid party summary position')
 T.raises(function()Chrome.drawPartyBar(1,1,{'invalid-icon'})end,'invalid party summary icon')
 local actualDraw=love.graphics.draw;local failedDraws=0
 love.graphics.draw=function()failedDraws=failedDraws+1;love.graphics.push();error('native party draw failed')end
 Chrome.drawPartyBar=function(...)
  local args={...};pcall(base,unpack(args));pcall(base,unpack(args));return true
 end
 T.raises(function()Native.drawPartySummary(b,true)end,'native party draw failed')
 T.eq(failedDraws,1,'a swallowed native failure cannot replay the body')
 T.same({love.graphics.getColor()},{.2,.3,.4,.5},'failed wrappers restore graphics state')
 Chrome.drawPartyBar=base;love.graphics.draw=actualDraw
 -- Cursor records are zero-based detached observations. The native numeric
 -- selection remains one-based and is still available through _swapIndex.
 b.moveSwapIndex=1;local swap=Ui._swap;T.same(swap,{cursor=0});T.eq(Ui._swapIndex,1)
 swap.cursor=3;T.eq(b.moveSwapIndex,1);T.eq(Ui._swap.cursor,0)
 b.moveSwapIndex=2;T.eq(Ui._swap.cursor,1);T.eq(Ui._swapIndex,2)
 T.raises(function()Ui._swap={}end,'read-only');T.raises(function()Ui._swapIndex=1 end,'read-only')
 b.moveSwapIndex=nil;T.eq(Ui._swap,nil);T.eq(Ui._swapIndex,nil)
 game.stack:pop();T.eq(Chrome.drawPartyBar(),false,'retired battle cannot paint')
 f.close();Battle._service.release();G.release()
end
Assets.image,love.graphics.draw=image,draw;package.loaded['src.core.Game']=original
T.finish('native trainer party rows, once-only paint clocks, source swap cursor shape and owner retirement')
