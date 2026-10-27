-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Playfield=require('src.render.Playfield')
local V=require('src.render.GameViewport')
local R=require('src.mods.Runtime')
local G=love.graphics
local old={G.getDimensions,G.getPixelDimensions,R.wantsHook,R.call}
local windowW,windowH,dpi=1280,720,1
G.getDimensions=function()return windowW,windowH end
G.getPixelDimensions=function()return windowW*dpi,windowH*dpi end
local requested
R.wantsHook=function(name)return name=='render.viewport'and requested~=nil end
R.call=function(name,next,...)
 if name=='render.viewport'then return requested end
 return next(...)
end
local function check(w,h,x,y,rw,rh)
 local a,b,c,d=Playfield.cutout(w,h)
 T.eq(a,x);T.eq(b,y);T.eq(c,rw);T.eq(d,rh)
end
local originalTarget=G.getCanvas()
for _,size in ipairs{{1280,720},{600,900},{1016,708},{1400,600}}do
 windowW,windowH=size[1],size[2]
 for _,scale in ipairs{1,2,3}do
  dpi=scale;requested=nil;V.reset()
  check(windowW,windowH,nil,nil,nil,nil)
  V.begin(3);check(windowW,windowH,nil,nil,nil,nil);V.finish({})
  requested={x=24,y=32,width=windowW-76,height=windowH-120,capture=true}
  local r=V.begin(3)
  check(windowW,windowH,24,32,r.width,r.height)
  check(r.width,r.height,0,0,r.width,r.height)
  check(240,160,nil,nil,nil,nil)
  check(windowW*dpi+1,windowH*dpi+1,nil,nil,nil,nil)
  T.eq(G.getCanvas(),originalTarget,'query cannot change the native render target')
  local canvas=V.target();local inFrame=V.inFrame
  for i=1,3 do check(r.width,r.height,0,0,r.width,r.height)end
  T.eq(V.target(),canvas);T.eq(V.inFrame,inFrame,'repeated queries do not consume a frame')
  V.finish({});check(windowW,windowH,nil,nil,nil,nil)
  requested={capture=true};V.begin(3)
  check(windowW,windowH,nil,nil,nil,nil,'full-size captures reserve no cutout')
  V.finish({})
 end
end
for _,size in ipairs{{0,720},{1280,0},{0/0,720},{1280,math.huge},{'1280',720}}do
 check(size[1],size[2],nil,nil,nil,nil)
end
V.reset();G.getDimensions,G.getPixelDimensions,R.wantsHook,R.call=unpack(old)
T.eq(Playfield.push,nil,'a query does not invent a second rendering owner')
T.finish('native frame cutout coordinates, local/window spaces, DPI, previews and retirement')
