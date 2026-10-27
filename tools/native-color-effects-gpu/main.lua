-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
io.stdout:setvbuf('no')
function love.errorhandler(e)io.stderr:write(debug.traceback(tostring(e),2)..'\n');return function()return 1 end end
local root=assert(os.getenv('NATIVE_BALL_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
local ran=false
function love.draw()
 if ran then return end;ran=true
 local g=love.graphics;local Fx=require('src.core.game3.gba_fx');local Alpha=require('src.render.NativeGbaAlpha')
 local checks,paints=0,0
 local function check(ok,why)checks=checks+1;assert(ok,why)end
 check(love.filesystem.getIdentity():match('^oasc%-gen2recomp%-qa%-'),'own identity')
 check(g.getRendererInfo():lower():find(os.getenv('POKEPORT_GRAPHICS_BACKEND'),1,true),'requested backend')
 local rgb={3,13,29};local background={12,4,20};local targetColor={31,0,7}
 local data=love.image.newImageData(16,16)
 for y=0,15 do for x=0,15 do data:setPixel(x,y,rgb[1]/31,rgb[2]/31,rgb[3]/31,1)end end
 local image=g.newImage(data);image:setFilter('nearest','nearest');data:release()
 local function fade(c,to,n)local out={};for i=1,3 do out[i]=c[i]+math.floor((to[i]-c[i])*n/16)end;return out end
 local function brighten(c,n)return fade(c,{31,31,31},n)end
 local function samePixel(pixels,x,y,wanted,label)
  local r,gg,b,a=pixels:getPixel(x,y)
  for i,value in ipairs{r,gg,b}do check(math.abs(value-wanted[i]/31)<=1.1/255,label..' channel'..i..' actual'..value..' wanted'..wanted[i]/31)end
  check(a>.99,label..' alpha')
 end
 for _,dpi in ipairs{1,2}do
  local canvas=g.newCanvas(16,16,{dpiscale=dpi,format='rgba8',msaa=0});canvas:setFilter('nearest','nearest')
  local function setup()
   g.setCanvas(canvas);g.origin();g.setScissor();g.setShader();g.setColor(1,1,1,1)
   g.setBlendMode('replace','premultiplied');g.clear(background[1]/31,background[2]/31,background[3]/31,1)
  end
  local function read()
   g.setCanvas();return g.readbackTexture(canvas)
  end
  local function paint()paints=paints+1;g.draw(image,0,0)end
  for n=0,16 do
   setup();local before=paints;Fx.draw(paint,{y=n,color=targetColor});check(paints==before+1,'fade callback once')
   local pixels=read();samePixel(pixels,4*dpi,6*dpi,fade(rgb,targetColor,n),'fade '..n..' dpi'..dpi);pixels:release()
  end
  for _,n in ipairs{0,1,8,16}do
   setup();Fx.draw(paint,{bldy=n});local pixels=read();samePixel(pixels,2*dpi,2*dpi,brighten(rgb,n),'brightness');pixels:release()
  end
  for _,pair in ipairs{{0,16},{1,15},{7,9},{8,8},{16,0},{16,16}}do
   setup();local before=paints
   Fx.draw(paint,{y=5,color=targetColor},{eva=pair[1],evb=pair[2]})
   check(paints==before+1,'combined colour/alpha callback once')
   local colour=fade(rgb,targetColor,5);local wanted={}
   for i=1,3 do wanted[i]=math.min(31,math.floor((colour[i]*pair[1]+background[i]*pair[2])/16))end
   local pixels=read();samePixel(pixels,3*dpi,3*dpi,wanted,'combined alpha dpi'..dpi);pixels:release()
  end
  setup();Fx.draw(paint,{gray=true,y=4,color=targetColor,bldy=6})
  local gray=math.floor((rgb[1]*76+rgb[2]*151+rgb[3]*29)/256)
  local shade=gray>=30 and 31 or gray>=25 and 27 or gray>=20 and 21 or gray>=15 and 16 or gray>=10 and 11 or gray>=5 and 5 or 0
  local pixels=read();samePixel(pixels,4*dpi,4*dpi,brighten(fade({shade,shade,shade},targetColor,4),6),'grayscale order');pixels:release()
  local maskData=love.image.newImageData(8,8)
  for y=0,7 do for x=0,7 do maskData:setPixel(x,y,1,1,1,x<4 and 1 or 0)end end
  local mask=g.newImage(maskData);mask:setFilter('nearest','nearest');maskData:release()
  setup();Fx.draw(paint,{objWin={image=mask,x=4,y=4,w=8,h=8,bldy=16}})
  pixels=read();samePixel(pixels,5*dpi,5*dpi,{31,31,31},'inside object window')
  samePixel(pixels,10*dpi,5*dpi,rgb,'transparent mask part');samePixel(pixels,2*dpi,2*dpi,rgb,'outside object window');pixels:release()
  setup();Fx.draw(paint,{band=8});pixels=read()
  for _,y in ipairs{0,8,15}do samePixel(pixels,5*dpi,y*dpi,brighten(rgb,15-math.abs(y-8)),'band row'..y..' dpi'..dpi)end
  pixels:release();mask:release()
  setup();Fx.withClip({x=2,y=3,w=5,h=6},paint);pixels=read()
  samePixel(pixels,3*dpi,4*dpi,rgb,'inside clip');samePixel(pixels,1*dpi,1*dpi,background,'outside clip');pixels:release()
  -- Existing default native-alpha users keep their old integer operation.
  setup();local alpha=Alpha.new();local done,why=alpha:paint(7,9,paint);check(done,why)
  pixels=read();local wanted={};for i=1,3 do wanted[i]=math.floor((rgb[i]*7+background[i]*9)/16)end
  samePixel(pixels,3*dpi,3*dpi,wanted,'default native alpha');pixels:release();alpha:release()
  canvas:release()
 end
 Fx._service.release();image:release()
 print('NATIVE_COLOR_EFFECTS_GPU_OK',checks,paints);love.event.quit(0)
end
