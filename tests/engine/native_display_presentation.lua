-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local initialGame=package.loaded['src.core.Game']
local Display=require('src.core.game3.display')
local R=require('src.render.Renderer')
T.eq(package.loaded['src.core.Game'],initialGame,'display import cannot bootstrap another game')
local g=love.graphics
local dimensions,pixels,draw,newCanvas=g.getDimensions,g.getPixelDimensions,g.draw,g.newCanvas
local ww,wh,pw,ph=1024,768,1024,768
g.getDimensions=function()return ww,wh end;g.getPixelDimensions=function()return pw,ph end
R:init()
local zoom=require('src.render.Zoom');local oldZoom=zoom.offset;zoom.offset=0
for _,size in ipairs{{1024,768,1024,768},{900,600,1800,1200},{640,480,1280,1440},{400,800,1100,2200}}do
 ww,wh,pw,ph=unpack(size)
 for _,surface in ipairs{{240,160},{304,144}}do
  R:setUISize(unpack(surface));R:beginFrame()
  local before=R:frameRects()
  local cx,cy,sx,sy
  g.draw=function(image,x,y,rotation,scaleX,scaleY)
   if image==R.canvas then cx,cy,sx,sy=x,y,scaleX,scaleY end
  end
  R:endFrame()
  local active=R:surfaceRects(unpack(surface))
  T.eq(active.uox,cx);T.eq(active.uoy,cy);T.eq(active.Ux,sx);T.eq(active.Uy,sy,'active fitting matches the actual native UI blit')
  g.newCanvas=function()error('fitting must not allocate a GPU target')end
  local x,ox,oy,width,height,y=Display.fit()
  T.eq(width,240*x);T.eq(height,160*y);T.eq(x*before.dpiX,y*before.dpiY,'detached fit retains square framebuffer pixels')
  local capture=R:surfaceRects(240,160,700,500)
  T.eq(capture.ww,700);T.eq(capture.wh,500);T.eq(capture.pw,700*before.dpiX);T.eq(capture.ph,500*before.dpiY)
  T.eq(capture.uiw,240);T.eq(capture.uih,160)
  T.eq(R:uiSize(),surface[1]);T.eq(select(2,R:uiSize()),surface[2],'capture fitting cannot resize the native controller surface')
  capture.uiw=1;T.eq(R:surfaceRects(240,160,700,500).uiw,240)
  local after=R:frameRects();T.eq(after.Ux,before.Ux);T.eq(after.uox,before.uox);T.eq(after.uiw,before.uiw)
  g.newCanvas=newCanvas
 end
end
T.raises(function()Display.fit(0,500)end,'positive finite dimensions')
T.raises(function()Display.fit(0/0,500)end,'positive finite dimensions')
T.raises(function()R:surfaceRects(-1,160)end,'positive finite dimensions')
R:setUISize(240,160)
local fit,uiScale=R.fitScale,R.uiScale
R.fitScale=function()return 3 end;R.uiScale=function()return 2 end
local x,ox,oy,width,height,y=Display.fit();T.eq(x*R:frameRects().dpiX,2,'active surface observes native scale overrides');T.eq(width,240*x)
R.fitScale,R.uiScale=fit,uiScale
R.uiCentered=false;R.worldActive=true;zoom.offset=-2
local q=R:surfaceRects(240,160,1200,800);T.check(q.Up<=q.Sp);T.check(q.Up>=math.ceil(q.Sp/2))
R.uiFill=true;q=R:surfaceRects(240,160,713,481);T.eq(q.Up,math.min(q.pw/240,q.ph/160))
R.uiFill=false;R.uiCentered=true;zoom.offset=0
ww,wh,pw,ph=1024,768,1024,768;g.draw=draw
local NativeGame=require('src.core.Game')
local G=require('src.core.Game3')
local f=require('tools.battle-source-runtime.fixture').new('firered')
-- Retain the real class helpers used by the current native compositor while
-- exposing this synthetic session through the normal singleton binding.
local game=setmetatable(f.game,{__index=NativeGame});package.loaded['src.core.Game']=game
local b=f.fresh('TACKLE').battle;b.enter=false;game.stack:push(b)
local base=Display.present
T.eq(base(G.forNative(game)),nil,'a source present call outside its native phase cannot draw')
local callbacks,serial,frame=0,R.frameSerial,b.frame
Display.present=function(view)
 callbacks=callbacks+1;T.eq(G.native(view),game)
 local depth=g.getStackDepth and g.getStackDepth()
 base(view);base(view)
 return false,nil,'native display return'
end
local a,middle,c=NativeGame._draw(game)
T.eq(a,false);T.eq(middle,nil);T.eq(c,'native display return');T.eq(callbacks,1)
T.eq(R.frameSerial,serial+1,'two source base calls paint one actual native frame');T.eq(b.frame,frame,'presentation cannot update the combat clock')
T.eq(base(G.forNative(game)),nil)
local depth=g.getStackDepth and g.getStackDepth()
Display.present=function()g.push();error('source display failure')end
T.raises(function()NativeGame._draw(game)end,'source display failure')
if depth then T.eq(g.getStackDepth(),depth,'source graphics pushes cannot escape the native frame')end
Display.present=function(view)
 local ok=pcall(base,view);T.eq(ok,false);return true
end
local begin=R.beginFrame;R.beginFrame=function()error('native frame failure')end
T.raises(function()NativeGame._draw(game)end,'native frame failure');R.beginFrame=begin
Display.present=function(view)local saved=game.save;game.save={options={}};local value,why=base(view);game.save=saved;return value,why end
serial=R.frameSerial;a,c=NativeGame._draw(game);T.eq(a,false);T.eq(c,'native display cohort changed');T.eq(R.frameSerial,serial)
Display.present=function(view)game.stack:push({});local value,why=base(view);game.stack:pop();return value,why end
serial=R.frameSerial;a,c=NativeGame._draw(game);T.eq(a,false);T.eq(R.frameSerial,serial,'a changed stack cannot paint the previously resolved frame')
local seams=require('src.mods.ModSeams');local priorOwner=G._callbackOwner()
Display.present=function(view)T.eq(G._callbackOwner(),'display_owner');return base(view)end
seams._journal[#seams._journal+1]={tbl=Display,key='present',after=Display.present,owner='display_owner'}
serial=R.frameSerial;NativeGame._draw(game);T.eq(R.frameSerial,serial+1);T.eq(G._callbackOwner(),priorOwner);table.remove(seams._journal)
Display.present=base;serial=R.frameSerial;NativeGame._draw(game);T.eq(R.frameSerial,serial+1,'unmodified display keeps direct native painting')
-- Merely importing this module cannot redirect an ordinary non-GBA frame.
game.stack:pop();game.stack:push({uiSize=function()return 160,144 end,draw=function()g.rectangle('fill',0,0,8,8)end,isOpaque=function()return true end})
require('src.core.GameVersion').set('red')
Display.present=function()error('source GBA presentation reached another generation')end
serial=R.frameSerial;NativeGame._draw(game);T.eq(R.frameSerial,serial+1)
Display.present=base;require('src.core.GameVersion').set('firered');f.close();G.release()
package.loaded['src.core.Game']=initialGame
g.getDimensions,g.getPixelDimensions,g.draw,g.newCanvas=dimensions,pixels,draw,newCanvas;zoom.offset=oldZoom
T.finish('native display surface fitting, frame ownership and once-only presentation')
