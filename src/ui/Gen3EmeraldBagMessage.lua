-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The deposit result owns the native dialogue while the bag remains visible.
local M={isOpaque=false,holdsUIAnchors=true,screenId='Gen3EmeraldBagMessage'};M.__index=M
function M.new(game,owner,text,presentation)
 assert(owner.emerald)
 owner.emeraldView=owner.emeraldView or require('src.ui.Gen3EmeraldBagView').new(owner)
 local self=setmetatable({game=game,owner=owner,view=owner.emeraldView,message=tostring(text or''),
  emeraldBagMessageOwner=owner,presentation=presentation},M)
 self.canvas=love.graphics.newCanvas(240,160,{dpiscale=1});self.canvas:setFilter('nearest','nearest')
 return self
end
function M:uiSize()return self.owner:uiSize()end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return self.owner:sgbPalettes()end
function M:update()
 if self.closed then return end
 local input=self.game.input
 if input:wasPressed('a')or input:wasPressed('b')then
  assert(self.game.stack:top()==self);self.closed=true
  require('src.core.Sound').play(self.game.data,'Press_AB');self.game.stack:pop()
 end
end
function M:drawNative()
 local window=self.view.load('src.ui.game3.window');local font=self.view.load('src.ui.game3.frlg_font')
 window.dialogueFrame()
 font.draw(font.wrap(self.message,208),16,121,{colors=font.COLOR.NORMAL,maxWidth=208,linePitch=font.linePitch()})
end
function M:draw()
 local g=love.graphics;local ok,why=require('src.render.GraphicsScope').call(function()
  g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0);self:drawNative()
 end)
 if not ok then error(why,0)end
 g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
 self.closed=true
 if self.canvas then self.canvas:release()end
 self.canvas,self.view,self.presentation=nil,nil,nil
end
return M
