-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local R=require('src.render.Renderer')
local O=require('src.world.OverworldController')
local Game=require('src.core.Game')
local Copy=require('src.mods.Merge').deepCopy
local slot,previous
for i=1,100 do
 local name,value=debug.getupvalue(O.drawUI,i)
 if not name then break end
 if name=='Game'then slot,previous=i,value;debug.setupvalue(O.drawUI,i,Game);break end
end
T.check(slot~=nil)
local g=love.graphics
local rect,draw,dims,pixels=g.rectangle,g.draw,g.getDimensions,g.getPixelDimensions
local events={}
g.rectangle=function(mode,x,y,w,h,...)
 local _,_,_,a=g.getColor()
 if a==0.45 then events[#events+1]={kind='poison',mode=mode,x=x,y=y,w=w,h=h}end
 if a==0.7 then events[#events+1]={kind='transition'}end
 return rect(mode,x,y,w,h,...)
end
g.draw=function(texture,...)
 if texture==R.canvas then events[#events+1]={kind='UI'}end
 return draw(texture,...)
end
Game.renderer=R;Game.save={options={},flags={sentinel=true}};Game.data={constants={gen=3}}
R:init();R:setUISize(240,160)
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 V.set(edition)
 for _,size in ipairs{{720,480,720,480},{900,600,1800,1200},{640,480,1280,1440}}do
  g.getDimensions=function()return size[1],size[2]end
  g.getPixelDimensions=function()return size[3],size[4]end
  local popup={frames=120,rsNative={draw=function()end}}
  local w={drawFieldWeather=function()end,poisonFlash=8,mapNameSign=popup}
  local save=Copy(Game.save)
  R:beginFrame(true);R:beginWorldPass();R:endWorldPass();events={}
  O.drawUI(w)
  T.eq(#events,0,'poison never paints a partial UI rectangle')
  T.eq(R.fieldPoisonAlpha,0.45)
  T.eq(w.mapNameSign,popup,'drawing retains the popup owner')
  T.eq(popup.frames,120,'poison drawing does not advance popup animation')
  R.screenVeil={1,0.7};R:endFrame(nil,{})
  local ui,poison,transition
  for i,e in ipairs(events)do
   if e.kind=='UI'then ui=i end
   if e.kind=='poison'then
    poison=i;T.eq(e.mode,'fill');T.eq(e.x,0);T.eq(e.y,0)
    T.eq(e.w,size[1]);T.eq(e.h,size[2],'pulse covers the window at every DPI/aspect ratio')
   end
   if e.kind=='transition'then transition=i end
  end
  T.check(ui and poison and transition and ui<poison and poison<transition,
   'anchored popup and field pulse together underneath the transition')
  T.same(Game.save,save,'compositing cannot change health, inventory, flags or saved options')
  R:beginFrame(true);T.eq(R.fieldPoisonAlpha,nil,'pulse cannot leak into the next frame')
  w.poisonFlash=4;O.drawUI(w);T.eq(R.fieldPoisonAlpha,nil,'clear beat requests no veil')
 end
end
g.rectangle,g.draw,g.getDimensions,g.getPixelDimensions=rect,draw,dims,pixels
if slot then debug.setupvalue(O.drawUI,slot,previous)end
T.finish('GBA poison final composite, popup lifetime, wide windows, DPI and transition ownership')
