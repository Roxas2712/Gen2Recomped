-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native RS window/font/cursor over the host's unchanged action rows.
-- Geometry: pinned game3/rs/start_menu_data.lua at fb7b0366.
local M={};M.__index=M
function M.available(game)
  return require('src.ui.Gen3RsStarterSelect').available(game)and true or false
end
function M.new(owner)
  local context=require('src.ui.Gen3RsSceneContext').new(owner.game)
  local self=setmetatable({owner=owner,load=context.load,canvas=context.canvas},M)
  self.window=self.load('src.ui.game3.window')
  self.font=self.load('src.ui.game3.frlg_font')
  self.cursor=self.load('src.ui.game3.rs.menu_cursor')
  self.kit=self.load('src.ui.game3.rse.scene_kit')
  return self
end
function M:template()
  local width=6
  for _,row in ipairs(self.owner.rows)do
    width=math.max(width,math.ceil(self.font.measure(row.label)/8))
  end
  width=math.min(28,width)
  return self.window.template(29-width,1,width,math.min(8,math.max(1,#self.owner.rows))*2+2)
end
function M:arrow(frame,x,y)
  local entry=assert(self.kit.manifest('rse/bag').sprites.arrows_vertical)
  local img=assert(self.kit.image(entry.png));local iw,ih=img:getDimensions()
  self.arrows=self.arrows or{}
  self.arrows[frame]=self.arrows[frame]or love.graphics.newQuad(0,frame*entry.h,entry.w,entry.h,iw,ih)
  love.graphics.draw(img,self.arrows[frame],x,y,0,1,1,entry.w/2,entry.h/2)
end
function M:draw()
  local owner,g=self.owner,love.graphics
  local tpl=owner:contentTemplate();local first,last=owner:visibleRange()
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
    self.load('src.ui.game3.chrome').setFrameType(math.max(0,((owner.game.save.options or{}).gen3Frame or 1)-1))
    self.window.stdFrame(tpl)
    local x,y=tpl.left*8,tpl.top*8+8
    for i=first,last do
      self.window.printPx(owner.rows[i].label,x,y+(i-first)*16,{maxWidth=tpl.width*8})
    end
    if first<=last then self.cursor.draw(x,y+(owner.index-first)*16,tpl.width*8)end
    if first>1 then self:arrow(0,x+tpl.width*4,math.max(8,tpl.top*8))end
    if last<#owner.rows then self:arrow(1,x+tpl.width*4,math.min(152,(tpl.top+tpl.height)*8))end
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  if self.canvas then self.canvas:release();self.canvas=nil end
end
return M
