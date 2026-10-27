-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
io.stdout:setvbuf('no')
function love.errorhandler(e)io.stderr:write(debug.traceback(tostring(e),2)..'\n');return function()return 1 end end
local root=assert(os.getenv('NATIVE_BALL_ENGINE'));package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
local ran=false
function love.draw()
 if ran then return end;ran=true
 local g=love.graphics;local P=require('src.ui.game3.presentation')
 local V=require('src.core.GameVersion');local G=require('src.core.Game3')
 local R=require('src.render.Renderer');local checks,frames=0,0
 local function check(on,why)checks=checks+1;assert(on,why)end
 check(love.filesystem.getIdentity():match('^oasc%-gen2recomp%-qa%-'),'owned profile')
 check(g.getRendererInfo():lower():find(os.getenv('POKEPORT_GRAPHICS_BACKEND'),1,true),'requested backend')
 local function setup(target)
  g.setCanvas(target);g.origin();g.setShader();g.setScissor();g.setDepthMode()
  g.setColor(1,1,1,1);g.setBlendMode('alpha','alphamultiply');g.clear(.125,.25,.5,1)
 end
 local function picture(width)
  g.setColor(.9,.1,.2,1);g.rectangle('fill',2,5,width-15,4)
  g.setColor(.1,.8,.3,.75);g.rectangle('fill',13,29,19,121)
  g.setColor(.3,.4,1,1);g.rectangle('fill',width-28,107,17,31)
 end
 local function read(target)
  g.setCanvas();local data=g.readbackTexture(target);local bytes=data:getString();data:release();return bytes
 end
 for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
  V.set(edition)
  local game={data={},save={},mods={},stack={states={{}}}}
  package.loaded['src.core.Game']=game
  for _,dpi in ipairs{1,2}do for _,width in ipairs{240,320}do for _,size in ipairs{{480,320},{640,480}}do
   local w,h=size[1],size[2]
   local actual=g.newCanvas(w,h,{dpiscale=dpi,format='rgba8',msaa=0})
   local expected=g.newCanvas(w,h,{dpiscale=dpi,format='rgba8',msaa=0})
   for _,mode in ipairs{'false-after-paint','error','disabled','unregistered','handled','nested'}do
    local on=true;local count=0;local retained
    local function paint()count=count+1;picture(width)end
    local function fit()
     local scale=math.max(1,math.floor(math.min(w/width,h/160)))
     g.origin();g.translate(math.floor((w-width*scale)/2),math.floor((h-160*scale)/2));g.scale(scale,scale)
    end
    P.register('pixels',{enabled=function()return on end,draw=function()return false end,
     defer=function()return true end,present=function(_,native,ctx)
      retained=native;check(G.native(ctx.game)==game,'source game view')
      check(g.getCanvas()==actual,'present retains compositor target')
      if mode=='error'then g.push();g.setScissor(0,0,1,1);error('provider pixel error')end
      fit()
      if mode=='nested'then P.layer('child',function()native();native()end)
      else native();native()end
      return mode=='handled'or mode=='nested'
     end})
    setup(actual);P.begin(game,width,160);check(P.layer('pixels',paint),'admitted queue')
    if mode=='disabled'then on=false elseif mode=='unregistered'then P.unregister('pixels')end
    local depth=g.getStackDepth();P.flush(game,w,h)
    check(g.getCanvas()==actual,'flush keeps actual canvas')
    check(g.getStackDepth()==depth,'provider stack restored')
    check(count==1,'native painter executes once')
    if retained then check(retained()==false,'paint lease expires')end
    setup(expected);fit();picture(width)
    check(read(actual)==read(expected),'native window pixels '..edition..' dpi'..dpi..' width'..width..' '..mode)
    P._service.release();frames=frames+1
   end
   actual:release();expected:release()
  end end end
  G.release()
 end
 g.setCanvas();print('NATIVE_PRESENTATION_GPU_OK',checks,frames);love.event.quit(0)
end
