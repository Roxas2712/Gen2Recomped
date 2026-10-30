-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Independent Emerald deposit quantity overlay; the bag owns its transaction.
-- Window/font anchors: pinned Gen1Recomp fb7b0366 rse bag presenter.
local M={isOpaque=false,holdsUIAnchors=true,screenId='Gen3EmeraldDepositQuantity'};M.__index=M
function M.new(game,owner,opts)
 assert(owner.emerald and type(opts.onDone)=='function')
 owner.emeraldView=owner.emeraldView or require('src.ui.Gen3EmeraldBagView').new(owner)
 local self=setmetatable({game=game,owner=owner,view=owner.emeraldView,
  max=math.max(1,math.floor(opts.max)),qty=1,berry=opts.berry==true,
  onDone=opts.onDone,oldMessage=owner.message},M)
 self.canvas=love.graphics.newCanvas(240,160,{dpiscale=1});self.canvas:setFilter('nearest','nearest')
 owner.message=assert(opts.prompt)
 return self
end
function M:uiSize()return self.owner:uiSize()end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return self.owner:sgbPalettes()end
function M:finish(qty)
 if self.closed then return end
 assert(self.game.stack:top()==self,'Deposit quantity lost its owner')
 local done=self.onDone
 self.closed=true;self.game.stack:pop()
 if done then done(qty)end
end
function M:update()
 if self.closed then return end
 local input=self.game.input;local before=self.qty
 if input:wasPressed('up')then self.qty=self.qty==self.max and 1 or self.qty+1
 elseif input:wasPressed('down')then self.qty=self.qty==1 and self.max or self.qty-1
 elseif input:wasPressed('right')then self.qty=math.min(self.max,self.qty+10)
 elseif input:wasPressed('left')then self.qty=math.max(1,self.qty-10)
 elseif input:wasPressed('a')then
  require('src.core.Sound').play(self.game.data,'Press_AB');return self:finish(self.qty)
 elseif input:wasPressed('b')then
  require('src.core.Sound').play(self.game.data,'Press_AB');return self:finish(nil)
 end
 if self.qty~=before then require('src.core.Sound').play(self.game.data,'Press_AB')end
end
function M:drawNative()
 local load=self.view.load
 local window=load('src.ui.game3.window');local font=load('src.ui.game3.frlg_font')
 window.stdFrame(window.template(24,17,5,2))
 local text=self.view:text('count',{string.format(self.berry and'%03d'or'%02d',self.qty)})
 font.draw(text,192+math.floor((40-font.measure(text))/2),138,{colors=font.COLOR.NORMAL})
end
function M:draw()
 local g=love.graphics
 local ok,why=require('src.render.GraphicsScope').call(function()
  g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0);self:drawNative()
 end)
 if not ok then error(why,0)end
 g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
 self.closed=true;self.owner.message=self.oldMessage;self.onDone=nil
 if self.canvas then self.canvas:release()end
 self.canvas=nil;self.view=nil
end
return M
