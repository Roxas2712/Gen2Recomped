-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Ui=require('src.core.game3.battle.ui')
local Chrome=require('src.ui.game3.battle_chrome')
local Frames=require('src.battle.Gen3BattleFrames')
local Native=require('src.battle.Gen3Battle')
local Battle=require('src.core.game3.battle')
local Scope=require('src.render.GraphicsScope')
local Font=require('src.render.Font')
local Assets=require('src.render.Assets')
local Renderer=require('src.render.Renderer')
local G=require('src.core.Game3')
local g=love.graphics
local oldGame=package.loaded['src.core.Game']
local oldBox,oldImage,oldDraw,oldSerial=Font.drawBox,Assets.image,g.draw,Renderer.frameSerial
local boxes,images={},{}
Font.drawBox=function(...)boxes[#boxes+1]={...}end
local image=g.newCanvas(240,48)
Assets.image=function(path)if path=='native-frame-2'then return image end;return oldImage(path)end
g.draw=function(img,...)images[#images+1]={img,...}end
T.eq(Ui.drawMenuFrames('menu'),false,'no invented battle or window owner')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
 package.loaded['src.core.Game']=game
 local b=f.fresh('TACKLE').battle;b.enter=false;b:syncSides();game.stack:push(b)
 b.phase='menu';b.queue={};b.current=nil
 game.save.options.gen3Frame=2
 game.data.constants.gen3BattleTextbox={images={action='native-frame-2',moves='native-frame-2',message='native-frame-2'},
  frames={count=2},frameImages={[2]={action='native-frame-2',moves='native-frame-2',message='native-frame-2'}}}
 local target=g.newCanvas(240,160);local other=g.newCanvas(240,160)
 g.setCanvas(target);Renderer.frameSerial=20;boxes={};images={}
 local frame,queue=b.frame,#b.queue;local rolls=0;b.rng=function()rolls=rolls+1;return 1 end
 local function pair(mode)
  local ok=Scope.call(function()
   T.eq(Chrome.drawPanel(mode),true)
   local drawn,count=Ui.drawMenuFrames(mode);T.eq(drawn,true);T.eq(count,0)
  end);T.eq(ok,true)
 end
 pair('menu');pair('moves');pair('none')
 T.eq(#images,3);T.eq(#boxes,0,'packed native panels are not painted over')
 -- A receipt is one-use and bound to the actual target, admission and frame.
 local drawn,count=Ui.drawMenuFrames('menu');T.eq(drawn,true);T.eq(count,2)
 T.eq(#boxes,2);local w=Native.windows(b)
 T.same(boxes[1],{w.prompt.tx,w.prompt.ty,w.prompt.tw,w.prompt.th})
 T.same(boxes[2],{w.action.tx,w.action.ty,w.action.tw,w.action.th})
 boxes={};Chrome.drawPanel('menu');g.setCanvas(other)
 T.eq(select(2,Ui.drawMenuFrames('menu')),2,'same-size canvases retain their own identity')
 T.eq(#boxes,2);T.eq(g.getCanvas(),other)
 boxes={};g.setCanvas(target);Chrome.drawPanel('menu');Renderer.frameSerial=21
 T.eq(select(2,Ui.drawMenuFrames('menu')),2,'a later compositor frame cannot reuse a packed receipt')
 boxes={};Chrome.drawPanel('menu');b.frame=b.frame+1
 T.eq(select(2,Ui.drawMenuFrames('menu')),2,'native frame drift retires the receipt')
 boxes={};Chrome.drawPanel('menu');Chrome._service.releaseOwner('anything')
 T.eq(select(2,Ui.drawMenuFrames('menu')),2,'owner release retires painted state')
 boxes={};Chrome.drawPanel('menu');local save=game.save;game.save={options={}}
 T.eq(select(2,Ui.drawMenuFrames('menu')),2,'a changed save cannot inherit an older receipt');game.save=save
 boxes={};T.raises(function()Ui.drawMenuFrames('bad')end,'invalid battle panel mode');T.eq(#boxes,0)
 -- MRT descriptions may be structural; their canvas handles remain opaque.
 local a={target,other,depthstencil=target};local copy={target,other,depthstencil=target}
 T.eq(Battle._sameRenderTarget(a,copy),true)
 T.eq(Battle._sameRenderTarget(a,{other,target,depthstencil=target}),false)
 T.eq(Battle._sameRenderTarget(a,{target,other,depthstencil=other}),false)
 T.eq(Battle._sameRenderTarget(target,other),false)
 -- Without the compositor serial, only a single active graphics scope pairs.
 Renderer.frameSerial=nil;boxes={};pair('menu');T.eq(#boxes,0)
 Chrome.drawPanel('menu');T.eq(select(2,Ui.drawMenuFrames('menu')),2)
 Renderer.frameSerial=22;boxes={}
 game.data.constants.gen3BattleTextbox=nil
 T.eq(Chrome.drawPanel('moves'),false);T.eq(select(2,Ui.drawMenuFrames('moves')),2)
 local s=Native.strip(b);T.same(boxes[1],{s.tx,s.ty,20,s.th})
 T.eq(select(2,Ui.drawMenuFrames('none')),0)
 -- RS draws the existing native panel and its separate selected frame.
 if edition=='ruby'or edition=='sapphire'then
  local trace={};local chrome={_frameType=0}
  chrome.setFrameType=function(n)chrome._frameType=n end
  chrome.userFrame=function(...)trace[#trace+1]={...}end
  local panel={images={action=image,moves=image,message=image},chrome=chrome}
  b.rsBattlePanel=panel
  T.eq(Chrome.drawPanel('menu'),true);T.eq(select(2,Ui.drawMenuFrames('menu')),1)
  T.same(trace[1],{1,18,15,11,4})
  trace={};T.eq(Frames.rsFrames(b,'action'),true);T.same(trace[1],{1,18,15,11,4})
  trace={};T.eq(Frames.rsFrames(b,'moves'),true)
  T.same(trace[1],{1,1,15,20,4});T.same(trace[2],{1,23,15,6,4})
  b.safari=true;trace={}
  T.eq(select(2,Ui.drawMenuFrames('menu')),1);T.eq(#trace,0,'Safari retains its native fallback')
  b.safari=nil;b.rsBattlePanel=nil
 end
 -- The graphics fence restores target and stack even if the native painter fails.
 local depth=g.getStackDepth and g.getStackDepth()
 Font.drawBox=function()g.push('all');g.setCanvas(other);error('native window failure')end
 T.raises(function()Ui.drawMenuFrames('menu')end,'native window failure')
 T.eq(g.getCanvas(),target);if depth then T.eq(g.getStackDepth(),depth)end
 Font.drawBox=function(...)boxes[#boxes+1]={...}end
 T.eq(b.frame,frame+1);T.eq(#b.queue,queue);T.eq(rolls,0,'window presentation cannot run battle rules')
 Chrome.drawPanel('menu');game.stack:pop();Chrome._service.poll()
 T.eq(Ui.drawMenuFrames('menu'),false)
 Chrome._service.release();Battle._service.release();g.setCanvas();f.close();G.release()
 if target.release then target:release();other:release()end
end
Font.drawBox,Assets.image,g.draw,Renderer.frameSerial=oldBox,oldImage,oldDraw,oldSerial
package.loaded['src.core.Game']=oldGame
T.finish('native battle frames, packed-panel reuse, RS ownership, targets and retirement')
