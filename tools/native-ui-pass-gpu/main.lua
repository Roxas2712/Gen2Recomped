-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
function love.errorhandler(err)io.stderr:write(debug.traceback(tostring(err),2)..'\n');return function()return 1 end end
local root=assert(os.getenv('NATIVE_BALL_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
local g=love.graphics;local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local function read(canvas)local data=g.readbackTexture(canvas);local value=data:getString();data:release();return value end
local ran=false
function love.draw()
 if ran then return end;ran=true
 local renderer=g.getRendererInfo()
 check(renderer:lower():find(assert(os.getenv('POKEPORT_GRAPHICS_BACKEND')),1,true),'actual requested renderer')
 check(love.filesystem.getIdentity():match('^oasc%-gen2recomp%-qa%-'),'owned QA identity')
 local Pass=require('src.ui.game3.ui_pass');local base=Pass.drawUi
 local NativeGame=require('src.core.Game');local R=require('src.render.Renderer');R:init()
 -- Capture the real compositor through its existing output-owner contract.
 -- These pixel tests require no default-window framebuffer or OS acceptance.
 local Runtime=require('src.mods.Runtime')
 local events,hooks,errors=Runtime.events,Runtime.hooks,Runtime.errors
 local output=require('src.mods.Hooks').new();local completed,frameCanvas=0,nil
 output:wrap('render.output_enabled',function()return true end,0,'ui-pass-qa')
 output:wrap('render.output',function(_,ctx)
  completed=completed+1;frameCanvas=ctx.canvas;return true
 end,0,'ui-pass-qa')
 Runtime.install(events,output,{})
 local f=require('tools.battle-source-runtime.fixture').new('firered')
 local game=setmetatable(f.game,{__index=NativeGame});package.loaded['src.core.Game']=game
 local world={isOpaque=true,isOverworld=true,uiSize=function()return 240,160 end,draw=function()
  g.setColor(.125,.25,.5,1);g.rectangle('fill',0,0,240,160)
 end};game.overworld=world;game.stack:push(world)
 local b=f.fresh('TACKLE').battle;b.enter=false;b.isOpaque=false
 b.draw=function()g.setColor(1,.5,0,1);g.rectangle('fill',40,40,20,20)end;game.stack:push(b)
 local paints=0
 local a={isOpaque=false,uiSize=function()return 240,160 end,draw=function()
  paints=paints+1;g.setColor(0,1,1,1);g.rectangle('fill',10,10,17,9)
 end}
 local c={isOpaque=false,uiSize=function()return 240,160 end,draw=function()
  paints=paints+1;g.setColor(1,0,1,1);g.rectangle('fill',80,60,13,7)
 end};game.stack:push(a);game.stack:push(c)
 local function frame(mode)
  if mode=='absent'then package.loaded['src.ui.game3.ui_pass']=nil
  else package.loaded['src.ui.game3.ui_pass']=Pass end
  Pass.drawUi=mode=='wrapped'and function()base();return base()end
   or mode=='held'and function()return false end or base
  local before,clock,frames=paints,b.frame,completed;NativeGame._draw(game)
  check(paints-before==(mode=='held'and 0 or 2),'native overlays paint exactly once')
  check(b.frame==clock,'UI drawing has no command clock')
  check(completed==frames+1 and frameCanvas~=nil,'actual compositor completes one owned output frame')
  return read(R.canvas),read(frameCanvas)
 end
 local original,originalFrame=frame('absent')
 local native,nativeFrame=frame('default')
 check(native==original and nativeFrame==originalFrame,'default module preserves native and composed pixels')
 native,nativeFrame=frame('wrapped')
 check(native==original and nativeFrame==originalFrame,'repeated base calls preserve native and composed pixels')
 local underlay,underlayFrame=frame('held')
 for _,dpi in ipairs{1,2}do
  local hud=g.newCanvas(240,160,{format='rgba8',dpiscale=dpi,msaa=0})
  local expected=love.image.newImageData(240*dpi,160*dpi,'rgba8')
  for y=0,160*dpi-1 do for x=0,240*dpi-1 do
   if x>=10*dpi and x<27*dpi and y>=10*dpi and y<19*dpi then expected:setPixel(x,y,0,1,1,1)
   elseif x>=80*dpi and x<93*dpi and y>=60*dpi and y<67*dpi then expected:setPixel(x,y,1,0,1,1)end
  end end
  local function capture(shift)
   g.setCanvas(hud);g.origin();g.setShader();g.setScissor();g.clear(0,0,0,0);g.setCanvas()
   Pass.drawUi=function()
    g.setCanvas(hud);g.origin();g.setShader();g.setScissor();g.translate(shift or 0,0);base();return base()
   end
   local before=paints;NativeGame._draw(game);check(paints==before+2,'redirected native UI paints once')
   check(read(R.canvas)==underlay,'world and battle are never captured into the HUD')
   check(read(frameCanvas)==underlayFrame,'redirected UI is absent from the owned world/battle output')
   return read(hud)
  end
  check(capture()==expected:getString(),'redirected UI matches independent physical-pixel rectangles dpi'..dpi)
  check(capture(1)~=expected:getString(),'positive control detects one logical pixel displacement')
  expected:release();hud:release()
 end
 -- This boundary must also restore the physical clip when a source fails
 -- after leaking a push and changing the render target's pixel density.
 local caller=g.newCanvas(240,160,{format='rgba8',dpiscale=2,msaa=0})
 local foreign=g.newCanvas(8,4,{format='rgba8',dpiscale=1,msaa=0})
 local shader=g.newShader('vec4 effect(vec4 c,Image t,vec2 uv,vec2 p){return Texel(t,uv)*c;}')
 g.setCanvas(caller);g.origin();g.setShader();g.setScissor();g.clear(.2,.3,.4,1)
 g.setShader(shader);g.setScissor(2,1,236,110);local depth=g.getStackDepth()
 Pass.drawUi=function()g.push('all');g.setCanvas(foreign);g.setScissor(1,1,2,2);error('intentional UI target failure')end
 local ok,why=pcall(Pass._nativeDrawUi,game,function()error('failed callback must not reach native UI')end)
 check(not ok and tostring(why):find('intentional UI target failure',1,true),'source failure retained')
 check(g.getCanvas()==caller and g.getShader()==shader and g.getStackDepth()==depth,'borrowed graphics state restored')
 g.setShader();g.setColor(1,0,1,1);g.rectangle('fill',0,0,240,160);g.setCanvas();g.setScissor()
 local pixels=g.readbackTexture(caller)
 for _,point in ipairs{{0,0},{3,2},{4,2},{6,4},{474,220},{478,224}}do
  local x,y=point[1],point[2];local red=pixels:getPixel(x,y)
  local inside=x>=4 and x<476 and y>=2 and y<222
  check(math.abs(red-(inside and 1 or .2))<=1.01/255,'physical native UI clip at '..x..','..y)
 end
 pixels:release();caller:release();foreign:release();shader:release();Pass.drawUi=base
 for _=1,4 do game.stack:pop()end;f.close();require('src.core.Game3').release()
 Runtime.install(events,hooks,errors)
 print('NATIVE_UI_PASS_GPU_OK',renderer,checks);love.event.quit(0)
end
