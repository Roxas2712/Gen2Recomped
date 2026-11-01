-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Host ownership around the unchanged pinned original cinematic controller.
local M={screenId='Gen3Cutscene',isOpaque=true,holdsUIAnchors=true};M.__index=M
function M.available(game)
 return require('src.import.Gen3EmeraldRaySceneAssets').valid(game and game.data and game.data.constants
  and game.data.constants.gen3EmeraldRayScene,require('src.core.GameVersion').get())
end
function M.new(game,opts)
 assert(M.available(game));opts=opts or{}
 local spec=game.data.constants.gen3EmeraldRayScene
 local self=setmetatable(require('src.ui.Gen3EmeraldSceneContext').new(game,{bindings={
  ['src.core.game3.constants']={of=function(version)
   assert(version=='emerald');return{require=function(_,family,name)
    if family=='songs'and name=='MUS_RAYQUAZA_APPEARS'then return spec.song end
    if family=='species'and name=='SPECIES_RAYQUAZA'then return spec.rayquaza end
    error('Unexpected native cinematic constant '..tostring(family)..'.'..tostring(name))
   end}
  end},
 }}),M)
 self.onDone=opts.onDone
 local audio=self.load('src.core.game3.audio');local play=audio.playSong
 audio.playSong=function(id,...)
  if tonumber(id)==0 then return require('src.core.Music').stop()end
  return play(id,...)
 end
 local part=tonumber(opts.part)or 0;assert(part==math.floor(part)and part>=0 and part<=6)
 self.part=part
 self.scene=self.load('src.ui.game3.rse.rayquaza_scene').new({animId=part,endEarly=part==0})
 self.step=self.load('src.ui.game3.rse.scene_kit').stepper()
 return self
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
 if self.closed then return end
 self.step:collect(self.game.input)
 local done=self.step:run(dt,function(input)
  if not self.scene.done then self.scene:frame(input)end
  return self.scene.done or nil
 end)
 if done then self:finish()end
end
function M:finish()
 if self.closed then return end
 self.closed=true;local callback=self.onDone;self.onDone=nil
 assert(self.game.stack:top()==self,'Native cinematic lost its host owner')
 self.game.stack:pop()
 local music=require('src.core.Music');local world=self.game.overworld
 if not music.current()and world and world.map then
  music.playMap(self.game.data,world.map.id,self.game.save.onBike,world.player and world.player.surfing)
 end
 if callback then callback()end
end
function M:draw()
 local g=love.graphics
 local ok,why=require('src.render.GraphicsScope').call(function()
  g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0);self.scene:draw()
 end)
 if not ok then error(why,0)end
 g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
 self.closed=true
 if self.load then self.load('src.core.game3.gba_ppu').clearCache()end
 if self.canvas then self.canvas:release()end
 self.canvas,self.scene,self.step,self.load=nil,nil,nil,nil
end
return M
