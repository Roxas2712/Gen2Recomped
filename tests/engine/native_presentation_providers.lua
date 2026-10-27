-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local original=package.loaded['src.core.Game']
local P=require('src.ui.game3.presentation')
T.eq(P,require('src.render.NativePresentation'))
T.eq(package.loaded['src.core.Game'],original,'presentation import does not start Game')
T.eq(P.apiVersion,1)
for _,name in ipairs{'pcWorkflow','paperDevices','paperMotion','battlePaper','hoennPaper','bagPaperCases','actionPaper','recordsLearningPaper','smartPaperAtlas'}do
 T.eq(P.features[name],nil,'unfinished family is not advertised: '..name)
end
local G=require('src.core.Game3')
local R=require('src.render.Renderer');R:init()
local NativeGame=require('src.core.Game')
local g=love.graphics
local function provider(extra)
 local p={enabled=function()return true end,draw=function()return false end}
 for k,v in pairs(extra or{})do p[k]=v end
 return p
end
local function tuple(...)return{n=select('#',...),...}end
T.raises(function()P.register('',provider())end,'owner')
T.raises(function()P.register('bad',{})end,'enabled and draw')
T.raises(function()P.register('bad',provider{present=true})end,'callback')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition)
 local game=setmetatable(f.game,{__index=NativeGame});package.loaded['src.core.Game']=game
 local marks={};local function mark(name)marks[#marks+1]={name=name,target=g.getCanvas(),owner=G._callbackOwner()}end
 local world={isOverworld=true,isOpaque=true,uiSize=function()return 240,160 end,draw=function()mark('world')end}
 game.overworld=world;game.stack:push(world)
 local modal={isOpaque=false,uiSize=function()return 240,160 end,draw=function()mark('modal')end}
 game.stack:push(modal)
 local enabled,paints,notes,begins=0,0,0,0
 G._withCallbackOwner('qa-mod',function()
  P.register('qa-provider',provider{
   enabled=function(view)enabled=enabled+1;T.eq(G.native(view),game);T.eq(G._callbackOwner(),'qa-mod');return true end,
   begin=function(view)begins=begins+1;T.eq(G.native(view),game)end,
   draw=function(kind,ctx)T.eq(kind,'frame');T.eq(ctx.x,4);g.setColor(.9,.8,.7,.6);g.push();return true end,
   notify=function(kind)T.eq(kind,'launched');notes=notes+1 end,
   widget=function(_,native)paints=paints+1;local v=tuple(native());T.same(v,{n=3,[2]=4});native();return false end})
 end)
 local start={g.getColor()};local depth=g.getStackDepth and g.getStackDepth()
 T.eq(P.begin(G.forNative(game),240,160),true);T.eq(begins,1)
 for i=1,5 do T.eq(P.draw('frame',{x=4}),true)end
 T.same({g.getColor()},start);if depth then T.eq(g.getStackDepth(),depth)end
 T.eq(enabled,1,'selection checks are cached within a native frame')
 P.notify('launched');T.eq(notes,1)
 local calls=0;local retained
 local function native()calls=calls+1;T.eq(G._callbackOwner(),nil);return nil,4,nil end
 T.eq(P.widget('card',native),false);T.eq(calls,1,'false after native paint cannot double paint')
 P.register('qa-widget',provider{widget=function(_,paint)retained=paint;paint();return true end})
 P.widget('card',native);T.eq(calls,2);T.eq(retained(),false,'retained immediate lease expires')
 local stale=P.register('same',provider());local fresh=P.register('same',provider())
 T.eq(stale(),false);T.eq(P.health('same').registered,true);T.eq(fresh(),true)
 P.unregister('qa-widget');P.unregister('same')
 P.flush(game,960,640);T.eq(P.health('qa-provider').queued,0)
 T.eq(P.draw('frame',{x=4}),false,'no independent painting outside the native frame')
 P._service.release()
 -- Queued painting is FIFO and stays on the compositor's current target.
 local target=g.newCanvas(960,640);local saved=g.getCanvas()
 local on=true;local presented=0;local frames=game.frame
 local p=provider{enabled=function()return on end,defer=function()return true end,
  present=function(kind,paint,ctx)
   presented=presented+1;T.eq(ctx.width,960);T.eq(ctx.height,640);T.eq(G.native(ctx.game),game)
   T.eq(g.getCanvas(),target);paint();paint();return false
  end}
 P.register('queue',p);P.begin(game,320,160)
 local seq={};local savedLease
 P.layer('one',function()seq[#seq+1]='one';T.eq(g.getCanvas(),target)end)
 P.layer('two',function()seq[#seq+1]='two' end)
 g.setCanvas(target);P.flush(game,960,640)
 T.same(seq,{'one','two'});T.eq(presented,2);T.eq(g.getCanvas(),target);T.eq(game.frame,frames)
 for _,mode in ipairs{'disable','unregister','owner-release','replacement','error'}do
  local draws=0
  G._withCallbackOwner('queue-mod',function()P.register('queue',provider{
   enabled=function()return on end,defer=function()return true end,
   present=function(_,paint)if mode=='error'then g.push();error('provider paint failed')end;return true end})end)
  on=true;P.begin(game,240,160);P.layer('recover',function()draws=draws+1;T.eq(g.getCanvas(),target)end)
  if mode=='disable'then on=false
  elseif mode=='unregister'then P.unregister('queue')
  elseif mode=='owner-release'then P._service:releaseOwner('queue-mod')
  elseif mode=='replacement'then P.register('queue',provider{defer=function()return true end,present=function()error('new provider must not receive old work')end})end
  P.flush(game,960,640);T.eq(draws,1,mode..' preserves admitted native fallback')
  if mode=='error'then T.eq(P.health('queue').error:find('provider paint failed',1,true)~=nil,true)end
 end
 -- Errors in native painters remain fatal even when provider catches them.
 local attempts=0
 P.register('queue',provider{defer=function()return true end,present=function(_,paint)
  savedLease=paint;pcall(paint);pcall(paint);return true end})
 P.begin(game,240,160);P.layer('bad',function()attempts=attempts+1;error('native painter failed')end)
 T.raises(function()P.flush(game,960,640)end,'native painter failed');T.eq(attempts,1)
 T.raises(savedLease,'native painter failed');T.eq(P.health('queue').queued,0)
 if depth then T.eq(g.getStackDepth(),depth)end
 P.register('widget-error',provider{widget=function(_,paint)pcall(paint);return true end})
 P.begin(game,240,160);attempts=0
 T.raises(function()P.widget('bad',function()attempts=attempts+1;error('native widget failed')end)end,'native widget failed')
 T.eq(attempts,1);P._service.release()
 -- Reentrant layers during a window callback paint inline; none are lost
 -- into a second deferred queue or a second native frame.
 local recursive=0
 P.register('queue',provider{defer=function()return true end,present=function(_,paint)
  T.eq(P.begin(game),false);P.layer('nested',function()recursive=recursive+1;paint()end);return true end})
 P.begin(game,240,160);calls=0;P.layer('outer',function()calls=calls+1 end);P.flush(game,960,640)
 T.eq(calls,1);T.eq(recursive,1);T.eq(P.health('queue').queued,0)
 -- Do not call retained painters after any session/stack/edition retirement.
 for _,mutation in ipairs{'data','save','mods','stack','middle','edition','view-retirement','release'}do
  P.register('queue',provider{defer=function()return true end,present=function()return false end})
  P.begin(game,240,160);calls=0;P.layer('retired',function()calls=calls+1 end)
  local restore
  if mutation=='middle'then local prior=game.stack.states[1];game.stack.states[1]={};restore=function()game.stack.states[1]=prior end
  elseif mutation=='edition'then require('src.core.GameVersion').set('crystal');restore=function()require('src.core.GameVersion').set(edition)end
  elseif mutation=='release'then P._service.release();restore=function()end
  elseif mutation=='view-retirement'then G.release();restore=function()end
  else local prior=game[mutation];game[mutation]={};restore=function()game[mutation]=prior end end
  T.eq(P.flush(game,960,640),false);T.eq(calls,0,mutation..' retires queued work');restore()
 end
 P._service.release();g.setCanvas(saved);if target.release then target:release()end
 -- Drive the actual Game -> modal seam -> Renderer path. The world remains
 -- on its native surface; deferred UI reaches the current window composite.
 local callbackTarget;local deferCount=0
 P.register('integration',provider{defer=function(kind)T.eq(kind,'ui_stack');deferCount=deferCount+1;return true end,
  present=function(kind,paint,ctx)callbackTarget=g.getCanvas();T.eq(ctx.ui.first,2);paint();paint();return true end})
 marks={};NativeGame._draw(game)
 T.eq(#marks,2);T.eq(marks[1].name,'world');T.eq(marks[1].target,R.canvas)
 T.eq(marks[2].name,'modal');T.eq(marks[2].target,callbackTarget);T.eq(deferCount,1)
 T.eq(P.health('integration').queued,0);T.eq(g.getCanvas(),nil)
 P._service.release();game.stack:pop();game.stack:pop();f.close();G.release()
end
for _,edition in ipairs{'red','crystal','platinum','black'}do
 local f=require('tools.battle-source-runtime.fixture').new('firered')
 local game=setmetatable(f.game,{__index=NativeGame});package.loaded['src.core.Game']=game
 require('src.core.GameVersion').set(edition)
 P.register('gba-only',provider{enabled=function()error('GBA presentation reached another generation')end})
 local paints=0;game.stack:push({isOpaque=true,draw=function()paints=paints+1 end})
 NativeGame._draw(game);T.eq(paints,1);T.eq(P.health('gba-only').error,nil)
 P._service.release();game.stack:pop();f.close();G.release()
end
package.loaded['src.core.Game']=original;require('src.core.GameVersion').set('firered')
T.finish('native presentation providers, frame leases, window fallback and lifecycle routing')
