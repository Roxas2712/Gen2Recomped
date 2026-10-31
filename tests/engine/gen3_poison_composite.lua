-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.world.Gen3FieldPoison')
local V=require('src.core.GameVersion')
local O=require('src.world.OverworldController')
local Game=require('src.core.Game')
local Copy=require('src.mods.Merge').deepCopy
local g=love.graphics
local oldShader=g.newShader;local oldDraw=g.draw
local shader={send=function(self,key,value)self[key]=value end}
g.newShader=function(code)T.check(code:find('floor(pixel/mosaicSize)',1,true)~=nil);return shader end
local draws={};g.draw=function(image)draws[#draws+1]={image=image,shader=g.getShader(),target=g.getCanvas()}end
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 local expected=(edition=='firered'or edition=='leafgreen')and{2,3,4,5,6,5,4,3,2,1}or{3,5,7,9,11,9,7,5,3,1}
 local w={save={hp=20,status='PSN',inventory={POTION=2},flags={sentinel=true}},popup={frames=120}}
 local before=Copy(w.save);T.eq(M.start(w,edition),true)
 for frame,size in ipairs(expected)do
  T.eq(M.size(w),size,'cartridge MOSAIC register plus one, frame '..frame)
  for _,dimensions in ipairs{{240,160},{320,180},{161,145}}do
   local target={};g.setCanvas(target);local priorShader={};g.setShader(priorShader)
   local owner=w.popup;local canvas=w.gen3PoisonCanvas;local calls=0
   M.background(w,dimensions[1],dimensions[2],function()
    calls=calls+1
    if size>1 then T.neq(g.getCanvas(),target,'BG-only capture is separate from actors/UI')end
   end)
   T.eq(calls,1);T.eq(g.getCanvas(),target);T.eq(g.getShader(),priorShader)
   T.eq(M.size(w),size,'repeated draws never advance animation')
   T.eq(w.popup,owner);T.eq(w.popup.frames,120,'mosaic never advances the map popup')
   if size>1 then
    T.same(shader.sourceSize,dimensions);T.eq(shader.mosaicSize,size)
    T.eq(draws[#draws].target,target,'full BG pass returns to its original canvas')
   end
  end
  M.tick(w)
 end
 T.eq(w.gen3PoisonMosaic,nil);T.eq(M.size(w),1);T.same(w.save,before,'render clock never damages or edits saved state')
end
local w={};M.start(w,'leafgreen');local target={};g.setCanvas(target);local prior={};g.setShader(prior)
T.raises(function()M.background(w,240,160,function()error('broken BG draw')end)end)
T.eq(g.getCanvas(),target,'failure restores the native render target');T.eq(g.getShader(),prior)
T.eq(M.start({},'gold'),false);T.eq(M.start({},'platinum'),false)
-- GBA no longer queues any black veil, including on an old transient flag.
local slot,previous
for i=1,100 do local name,value=debug.getupvalue(O.drawUI,i);if not name then break end
 if name=='Game'then slot,previous=i,value;debug.setupvalue(O.drawUI,i,Game);break end end
T.check(slot~=nil)
local rect=g.rectangle;local black=0;g.rectangle=function(...)black=black+1 end
Game.data={constants={}};Game.save={options={}};Game.renderer={uiSize=function()return 240,160 end}
for _,version in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 V.set(version);local popup={frames=120,rsNative={draw=function()end}}
 O.drawUI({drawFieldWeather=function()end,mapNameSign=popup,poisonFlash=8})
 T.eq(black,0);T.eq(popup.frames,120)
end
g.rectangle=rect;g.newShader=oldShader;g.draw=oldDraw
if slot then debug.setupvalue(O.drawUI,slot,previous)end
T.finish('Original GBA BG mosaic timing, full background surfaces, sharp popup/OBJ and draw immutability')
