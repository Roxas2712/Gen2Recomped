-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local R=require('src.render.Renderer')
local P=require('src.render.PaletteFX')
local Flash=require('src.world.Gen3Flash')
local Overworld=require('src.world.OverworldController')
local Game=require('src.core.Game')
local gameSlot,previousGame
for i=1,100 do
 local name,value=debug.getupvalue(Overworld.drawGen3Flash,i)
 if not name then break end
 if name=='Game'then gameSlot,previousGame=i,value;debug.setupvalue(Overworld.drawGen3Flash,i,Game);break end
end
T.check(gameSlot~=nil,'bind the ordinary world draw to the synthetic native session')
local A=require('src.render.Assets')
local S=require('src.render.SpriteRenderer')
local Copy=require('src.mods.Merge').deepCopy
local g=love.graphics
local draw,image,mask=g.draw,A.image,Flash.drawMask
local dims,pixels=g.getDimensions,g.getPixelDimensions
A.image=function()return g.newCanvas(16,96)end
local sprite=S.new({id='FLASH_RGBA_PROBE',image='flash-rgba-probe',frames=6,trueColor=true})
local events={}
g.draw=function(texture,...)
 if texture==sprite.image and g.getCanvas()~=R.worldCanvas then events[#events+1]='sprite replay'end
 if texture==R.uprightCanvas then events[#events+1]='upright composite'end
 if texture==R.canvas then events[#events+1]='UI'end
 return draw(texture,...)
end
Flash.drawMask=function(...)
 events[#events+1]={kind='mask',args={...}}
 return mask(...)
end
Game.renderer=R
R:init();R:setUISize(240,160)
for _,version in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 V.set(version)
 for _,size in ipairs{{720,480,720,480},{900,600,1800,1200},{640,480,1280,1440}}do
  g.getDimensions=function()return size[1],size[2]end
  g.getPixelDimensions=function()return size[3],size[4]end
  Game.data={constants={gen3Flash={maxLevel=1,radii={200,24},screen={240,160}}}}
  Game.save={gen3FlashLevel=1,options={},flags={sentinel=true}}
  local before=Copy(Game.save)
  R:beginFrame(true);R:beginWorldPass()
  local w,h=R:worldViewSize();local cx,cy=math.floor(w/2),math.floor(h/2)
  local world={player={px=cx-8,py=cy-8}}
  events={};sprite:draw(16,16,0,0,'down',0,false)
  T.eq(#P.spriteRedraws(),1,'actual RGBA world sprite uses the late colour replay')
  Overworld.drawGen3Flash(world,{x=0,y=0},w,h)
  T.eq(#events,0,'native world window waits for the final world composite')
  R:endWorldPass();R:endFrame(nil,{})
  local replay,window,ui
  for i,event in ipairs(events)do
   if event=='sprite replay'then replay=i end
   if event=='UI'then ui=i end
   if type(event)=='table'and event.kind=='mask'then
    window=i;T.same(event.args,{24,w,h,cx,cy},'native integer radius and player anchor are retained')
   end
  end
  T.check(replay and window and replay<window,'Flash covers the real post-zone sprite replay')
  T.check(window and ui and window<ui,'dialogue/UI is composited above darkness')
  T.same(Game.save,before,'drawing and presentation cannot change Flash/save state')
  R:beginFrame(true)
  T.eq(R.worldFlashWindow,nil,'next frame cannot inherit the cave window')
  -- A source-owned capture still receives its inline mask, not a window
  -- accidentally queued for the surrounding native frame.
  R:beginWorldPass();local foreign=g.newCanvas(w,h);g.setCanvas(foreign);events={}
  Overworld.drawGen3Flash(world,{x=0,y=0},w,h)
  T.eq(R.worldFlashWindow,nil,'independent capture does not queue a native mask')
  T.eq(#events,1,'independent capture keeps the inline mask')
  if events[1]then T.same(events[1].args,{24,w,h,cx,cy})end
  R:endWorldPass()
 end
end
-- The projected actor pass is also underneath the window. Projection itself
-- remains the existing renderer's responsibility.
V.set('leafgreen');R:beginFrame(true);R:beginWorldPass()
local w,h=R:worldViewSize();R:beginUprightPass();R:endUprightPass()
T.check(R:setWorldFlashWindow(24,w,h,w/2,h/2))
events={};R:endWorldPass();R:endFrame(nil,{})
local upright,window,ui
for i,event in ipairs(events)do
 if event=='upright composite'then upright=i end
 if event=='UI'then ui=i end
 if type(event)=='table'then window=i end
end
T.check(upright and window and upright<window and window<ui,'upright actors cannot escape the window or cover UI')
local Tilt=require('src.render.Tilt')
local active,project,point=Tilt.active,R.drawTiltedWorld,Tilt.groundPoint
Tilt.active=function()return true end
R.drawTiltedWorld=function()return true end
local anchorCalls=0
Tilt.groundPoint=function(x,y,vw,vh)
 anchorCalls=anchorCalls+1;T.same({x,y,vw,vh},{17,29,w,h},'projection receives the same native player anchor')
 return 43,71
end
R:beginFrame(true);R:beginWorldPass();R:setWorldFlashWindow(24,w,h,17,29)
events={};R:endWorldPass();R:endFrame(nil,{})
T.eq(anchorCalls,1,'a projected world transforms the anchor once')
for _,event in ipairs(events)do
 if type(event)=='table'then T.same(event.args,{24,w,h,43,71},'projected window follows the upright player')end
end
Tilt.active,R.drawTiltedWorld,Tilt.groundPoint=active,project,point
R:beginFrame(true);R:beginWorldPass();R:setWorldOverride(g.newCanvas(w,h))
T.eq(R:setWorldFlashWindow(24,w,h,w/2,h/2),false,'completed foreign world images keep their own effects')
R:endWorldPass()
g.draw,A.image,Flash.drawMask,g.getDimensions,g.getPixelDimensions=draw,image,mask,dims,pixels
debug.setupvalue(Overworld.drawGen3Flash,gameSlot,previousGame)
T.finish('native GBA Flash covers replayed sprites and preserves capture/UI ownership')
