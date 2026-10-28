-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Host save/callback views over the byte-exact native RS credits controller.
local M={};M.__index=M;M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3RsCredits'
function M.available(game)
  return require('src.import.Gen3RsCreditsAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3RsCredits,require('src.core.GameVersion').get())
end
function M.new(game,onDone)
  assert(M.available(game))
  local save=game.save
  local basic=require('compat.gen1-rs.Loader').new(require('src.core.GameVersion').get())
  local native=require('compat.gen1-rs.Constants').new(basic)
  local session,bindings=require('src.ui.Gen3CreditsSession').new(game,assert(native:var('VAR_STARTER_MON')))
  local self
  self=setmetatable(require('src.ui.Gen3RsSceneContext').new(game,{bindings=bindings}),M)
  self.onDone,self.session=onDone,session
  self.scene=self.load('src.ui.game3.rs.credits')
  self.state=self.scene.start({session=session,hasRecords=(tonumber(save.hallOfFame)or 0)>1,
    onDone=function()self:finish()end})
  return self
end
function M:finish()
  if self.closed then return end
  self.closed=true;local cb=self.onDone;self.onDone=nil
  assert(self.game.stack:top()==self,'Native credits lost their host owner')
  self.game.stack:pop();if cb then cb()end
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update()
  if self.closed then return end
  self.scene.handleInput(self.game.input);self.scene.update()
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
    self.scene.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  self.closed=true
  if self.scene then self.scene.reset()end
  for _,img in pairs(self.state and self.state.images or{})do if img.release then img:release()end end
  if self.load then self.load('src.core.game3.gba_ppu').clearCache()end
  if self.canvas then self.canvas:release();self.canvas=nil end
end
return M
