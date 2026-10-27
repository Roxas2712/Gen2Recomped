-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Ui=require('src.core.game3.battle.ui')
local Selection=require('src.battle.Gen3SelectionPresentation')
local Battle=require('src.core.game3.battle')
local G=require('src.core.Game3')
local C=require('src.core.game3.battle.anim_coords')
local original=package.loaded['src.core.Game']
T.eq(Ui.targetHidden(0),false);T.eq(Ui.bounceOffset('mon',0),0);T.eq(Ui.previewCoeff(0),0)
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
 package.loaded['src.core.Game']=game
 local b=f.fresh('TACKLE').battle;b.enter=false;game.stack:push(b)
 b.phase='menu';b.queue={};b.current=nil;b.waitFrames=0
 -- Sparse imported integer values deliberately distinguish signed ASR from
 -- truncation and from an invented floating-point sine fallback.
 game.data.constants.gen3BattleAnimSine={[128]=0,[135]=-43,[192]=-256,[199]=-252,[143]=256}
 local frame=b.frame;local rolls=0;b.rng=function()rolls=rolls+1;return 1 end
 T.eq(Selection._snapshot(b),nil)
 for _=1,8 do T.eq(Ui.bounceOffset('mon',0),0);T.eq(Ui.targetHidden(1),false)end
 T.eq(Selection._snapshot(b),nil,'queries cannot create a native controller')
 b:tickFx();T.eq(b.frame,frame+1);T.eq(Ui.bounceOffset('hb',0),1);T.eq(Ui.bounceOffset('mon',0),0)
 local born=Selection._snapshot(b).monFrom
 for _=1,8 do T.eq(Ui.bounceOffset('hb','player'),1);T.eq(Ui.bounceOffset('hb','enemy'),0)end
 T.eq(b.frame,frame+1);T.eq(Selection._snapshot(b).monFrom,born);T.eq(rolls,0)
 b:tickFx();T.eq(Ui.bounceOffset('hb',0),0,'negative fixed-point sine rounds down')
 T.eq(Selection._snapshot(b).monFrom,born,'repeated controller input cannot restart the bounce')
 b.phase='moveSelect';b:tickFx();T.eq(Selection._snapshot(b).monFrom,born,'the actor keeps one bounce through move selection')
 b.phase='targetSelect';b.targetChoices={b.enemy,b.player};b.targetIndex=1
 T.eq(Ui.targetHidden(1),false,'a query cannot start a target blink')
 b:tickFx();local targetFrom=Selection._snapshot(b).targetFrom;T.eq(Ui.targetHidden(1),false);T.eq(Ui.bounceOffset('hb',1),1)
 T.eq(Selection._snapshot(b).healthboxDelta,15);T.eq(Selection._snapshot(b).monFrom,born)
 b:tickFx();T.eq(Ui.bounceOffset('hb',1),2,'target healthbox uses its own native delta')
 for i=2,24 do
  b:tickFx();local hidden=i>=8 and i<16 or i>=24
  T.eq(Ui.targetHidden(1),hidden);T.eq(Ui.targetHidden(0),false)
  T.eq(Selection._snapshot(b).targetFrom,targetFrom)
 end
 b.targetIndex=2;T.eq(Ui.targetHidden(1),false);T.eq(Ui.targetHidden(0),false)
 b:tickFx();T.eq(Ui.targetHidden(0),false);T.eq(Selection._snapshot(b).targetPosition,0);T.eq(Selection._snapshot(b).healthboxPosition,0)
 -- Actual additional native battlers and side binding, not cloned UI actors.
 local Native=require('src.battle.BattleState');local Pokemon=require('src.pokemon.Pokemon')
 for id=2,3 do
  local mon=Pokemon.new(game.data,'CHARMANDER',30,function(lo)return lo or 0 end)
  b:placeBattler(id,Native.makeBattler(game.data,mon,id%2==0,id%2==0 and game.save or nil,b))
 end
 b.double=true;b:syncSides();b.targetChoices={b:battlerAt(3)};b.targetIndex=1;b:tickFx()
 C.bind(2,3);T.eq(Ui.bounceOffset('hb','enemy'),Ui.bounceOffset('hb',3));C.bind(nil)
 for _=1,8 do b:tickFx()end
 T.eq(Ui.targetHidden(3),true);T.eq(Ui.targetHidden(1),false)
 for _,key in ipairs{-1,0.5,4,math.huge,'missing'}do T.eq(Ui.targetHidden(key),false);T.eq(Ui.bounceOffset('hb',key),0)end
 T.eq(Ui.targetHidden(0/0),false);T.eq(Ui.bounceOffset('unknown',0),0)
 b:battlerAt(3).gen3TransformWhite=0.5;T.eq(Ui.previewCoeff(3),8)
 b:battlerAt(3).gen3TransformWhite=2;T.eq(Ui.previewCoeff(3),16)
 b:battlerAt(3).gen3TransformWhite=nil;T.eq(Ui.previewCoeff(3),0)
 local save=game.save;game.save={};T.eq(Ui.targetHidden(3),false);T.eq(Ui.bounceOffset('hb',3),0)
 game.save=save;b.phase='messages';T.eq(Ui.targetHidden(3),false);T.eq(Ui.bounceOffset('mon',0),0)
 b:tickFx();T.eq(Selection._snapshot(b),nil)
 b.phase='menu';game.data.constants.gen3BattleAnimSine=nil;b:tickFx();T.eq(Ui.bounceOffset('hb',0),0)
 T.eq(rolls,0);T.eq(#b.queue,0,'selection presentation never executes battle commands')
 game.stack:pop();T.eq(Ui.targetHidden(3),false);T.eq(Ui.bounceOffset('hb',0),0)
 Battle._service.release();C._service.release();f.close();G.release()
end
package.loaded['src.core.Game']=original
T.finish('native selection frame, target blink, integer bounce, white coefficient and cohort lifetime')
