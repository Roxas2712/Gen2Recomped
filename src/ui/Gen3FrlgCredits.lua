-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Exact FR/LG controller; its map/camera, fade and WIN0 live in this view.
local Base=require('src.ui.Gen3RsCredits')
local M=setmetatable({screenId='Gen3FrlgCredits',isOpaque=true,holdsUIAnchors=true},{__index=Base});M.__index=M
function M.available(game)
 local version=require('src.core.GameVersion').get()
 return require('src.import.Gen3FrlgCreditsAssets').valid(game and game.data and game.data.constants
  and game.data.constants.gen3FrlgCredits,version)
  and require('src.import.Gen3FrlgHallAssets').valid(game.data.constants.gen3FrlgHall,version)
end
function M.new(game,onDone)
 assert(M.available(game))
 local version=require('src.core.GameVersion').get();local p=game.save.player or{}
 local session={version=version,gender=(p.gender=='girl'or p.gender=='female'or p.gender==1 or p.female==true)and 1 or 0}
 local self=setmetatable({game=game,onDone=onDone,session=session,resources={},renderer={},maps={},mapLoads={}},M)
 local privateGame={};self.privateGame=privateGame
 local runtime={session=session,getSession=function()return session end,_game=privateGame}
 local bindings,audio,row=require('src.ui.Gen3FrlgSceneBindings').new(game,session,runtime)
 local field={hideActors=false,setCameraPanning=function(x,y)self.panX,self.panY=x,y end}
 local nativeMap={MUSIC_DISABLE_KEEP=1,MUSIC_DISABLE_OFF=0}
 local function loadMap(id,at)
  assert(game.data.maps[id],'Missing original FR/LG credits map '..tostring(id))
  self.map=require('src.world.MapLoader').load(game.data,id);assert(self.map.renderer,'Credits map has no renderer')
  self.maps[id]=self.map;self.mapLoads[#self.mapLoads+1]=id
  self.mapId=id;self.camX,self.camY=at.x*16+8-120,at.y*16+8-80
 end
 function nativeMap.load(_,_,id,at)loadMap(id,at)end
 bindings['src.core.game3.map']=nativeMap
 bindings['src.core.game3.field_view']=field
 bindings['src.import.gba.map_catalog']={mapIdFor=function(g,n)return('MAP_G%02d_N%02d'):format(g,n)end}
 bindings['src.core.game3.tileset_anim']={step=function()require('src.render.TileRenderer').tick(1/60)end}
 local flags={};bindings['src.core.game3.scripting.flags']={setFlag=function(_,_,id,value)flags[id]=value end}
 bindings['src.core.game3.pokemon']={frontPic=function(n)
  local r=row(n);local path=require('src.pokemon.Sprites').path(game.data,r.id,'front',{kind='credits'})
  return path and{image=require('src.render.Assets').image(path)}or nil
 end}
 bindings.__package.loaded['src.render.Renderer']=self.renderer
 -- Observe the controller's own WIN0 scissor while rendering its overlay.
 -- The proxy is private to this loader, never installed on host love.graphics.
 local graphics=setmetatable({intersectScissor=function(x,y,w,h)
  if x==0 and w==240 then self.band={x=x,y=y,w=w,h=h}end
  return love.graphics.intersectScissor(x,y,w,h)
 end},{__index=love.graphics})
 local function own(object)self.resources[#self.resources+1]=object;return object end
 for _,key in ipairs{'newImage','newQuad','newCanvas'}do
  local create=love.graphics[key];graphics[key]=function(...)return own(create(...))end
 end
 local images=setmetatable({newImageData=function(...)return own(love.image.newImageData(...))end},{__index=love.image})
 bindings.__globals={love=setmetatable({graphics=graphics,image=images},{__index=love})}
 self.load=require('compat.gen1-rs.Loader').new(version,bindings)
 self.scene=self.load('src.ui.game3.credits');self.audio=audio
 self.canvas=love.graphics.newCanvas(240,160,{dpiscale=1});self.canvas:setFilter('nearest','nearest')
 self.overlay=love.graphics.newCanvas(240,160,{dpiscale=1});self.overlay:setFilter('nearest','nearest')
 -- The cartridge invokes DoCredits after warping out of the Hall room.
 -- Only this view visits Indigo; the durable Hall snapshot stays untouched.
 loadMap('MAP_G03_N09',{x=11,y=6});assert(self.scene.start())
 return self
end
function M:enter()
 self.audio.playSong('MUS_CREDITS')
end
function M:update()
 if self.closed then return end
 self.scene.handleInput(self.game.input);self.scene.update()
 if self.privateGame.softResetRequested then self:finish()end
end
function M:finish()
 if self.closed then return end
 self.finished=true;return Base.finish(self)
end
function M:draw()
 local g=love.graphics
 local ok,why=require('src.render.GraphicsScope').call(function()
  self.band=nil
  g.setCanvas(self.overlay);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
  self.scene.draw()
  g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,1)
  local band=self.band
  if band and self.scene.state().world and self.map then
   g.setScissor(band.x,band.y,band.w,band.h)
   g.setColor(1,1,1,1)
   local x,y=math.floor(self.camX+(self.panX or 0)),math.floor(self.camY+(self.panY or 0))
   local r=self.map.renderer
   if r.drawBorderFill then r:drawBorderFill(x,y,240,160)end
   r:draw(x,y,240,160);if r.drawAbove then r:drawAbove(x,y,240,160)end
   local alpha=self.renderer.worldFadeAlpha or 0;local color=self.renderer.worldFadeColor or{0,0,0}
   if alpha>0 then g.setColor(color[1],color[2],color[3],alpha);g.rectangle('fill',0,0,240,160)end
  end
  g.setScissor();g.setColor(1,1,1,1);g.setBlendMode('alpha','premultiplied');g.draw(self.overlay,0,0)
 end)
 if not ok then error(why,0)end
 g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
 if self.closed and not self.canvas then return end
 self.closed=true;if self.scene then self.scene.reset()end
 for _,object in ipairs(self.resources or{})do pcall(object.release,object)end
 self.resources={}
 for _,key in ipairs{'canvas','overlay'}do if self[key]then self[key]:release();self[key]=nil end end
 -- MapLoader owns its shared renderers; never release the live world's maps.
 self.maps={};self.map=nil
end
return M
