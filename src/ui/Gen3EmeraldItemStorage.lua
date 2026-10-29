-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Existing pinned item-storage controller over atomic host item transactions.
local M={isOpaque=false,holdsUIAnchors=true,screenId='Gen3EmeraldItemStorage'};M.__index=M
function M.available(game)
 local c=game.data.constants or{}
 if require('src.core.GameVersion').get()~='emerald'
  or not require('src.import.Gen3EmeraldItemPcAssets').valid(c.gen3EmeraldItemPc,'emerald')
  or not require('src.import.Gen3EmeraldBagAssets').valid(c.gen3EmeraldBag,'emerald')then return false end
 local numbers,slots={},0
 for _,def in pairs(game.data.items or{})do if def.index then
  if numbers[def.index]then return false end;numbers[def.index]=true
 end end
 for id,qty in pairs(game.save.pcItems or{})do
  local def=game.data.items[id]
  if not def or type(def.index)~='number'or def.index<=0 or type(qty)~='number'
   or qty~=qty or qty%1~=0 or qty<1 or qty>999 then return false end
  slots=slots+1
 end
 return slots<=50
end
function M.new(game,opts)
 assert(M.available(game));opts=opts or{}
 local self=setmetatable({game=game,quads={}},M)
 local spec=game.data.constants.gen3EmeraldItemPc
 self.tx=require('src.inventory.Gen3RsItemPcTransaction').new(game,{version='emerald',
  pcLimits={pcItems=spec.capacity,pcSlotMax=spec.slotMax}})
 assert(self.tx.valid)
 local items={}
 function items.info(n)return game.data.items[self.tx:id(n)]or{}end
 function items.displayName(n)local def=items.info(n);return def.name or self.tx:id(n)end
 function items.description(n)local def=items.info(n);return def.description or def.desc or''end
 function items.toNumericId(id)return type(id)=='number'and id or self.tx:number(id)end
 local bindings={
  ['src.core.game3.items_data']=items,
  ['src.core.game3.storage']={ensure=function(s)assert(s==self.tx.session);return self.tx.store end},
  ['src.core.game3.bag']={
   canAdd=function(token,n,q)assert(token==self.tx.token);return self.tx:canWithdraw(n,q)end,
   add=function(token,n,q)assert(token==self.tx.token);return self.tx:withdraw(n,q)end},
  ['src.ui.game3.rse.bag_chrome']={
   returnIconIndex=function()return game.data.constants.gen3ItemIcons.count-1 end,
   drawItemIcon=function(n,x,y)self:drawIcon(n,x,y)end},
  ['src.ui.game3.stack']={push=function(id)assert(id=='rse_item_storage')end,
   pop=function(id)
    assert(id=='rse_item_storage'and game.stack:top()==self)
    game.stack:pop()
   end},
 }
 local root=require('src.import.Gen3EmeraldHallAssets').ROOT
 local context=require('src.ui.Gen3EmeraldSceneContext').new(game,{bindings=bindings,textIR=spec.textIR,
  ui={frames={manifest=game.data.constants.gen3EmeraldHall.manifest,userCount=20,
   user=root..'frame_%d.rgba',std='user',sign=false}}})
 self.load,self.canvas=context.load,context.canvas
 self.load('src.ui.game3.chrome').setFrameType(math.max(0,math.min(19,
  ((game.save.options or{}).gen3Frame or 1)-1)))
 self.ui=self.load('src.ui.game3.rse.item_storage')
 self.ui.show({session=self.tx.session,toss=opts.toss,onClose=opts.onCancel})
 return self
end
function M:drawIcon(n,x,y)
 local spec=self.game.data.constants.gen3ItemIcons;local index=tonumber(n)or(spec.count-1)
 if index<0 or index>=spec.count then index=tonumber(spec.blank)or 0 end
 local image=require('src.render.Assets').image(spec.image)
 local size,cols=tonumber(spec.size)or 24,tonumber(spec.cols)or 1
 if not self.quads[index]then
  self.quads[index]=love.graphics.newQuad(index%cols*size,math.floor(index/cols)*size,size,size,image:getDimensions())
 end
 love.graphics.setColor(1,1,1,1);love.graphics.draw(image,self.quads[index],x,y)
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update()
 if self.closed then return end
 local ui=self.ui;local before=ui.state
 ui.update();ui.handleInput(self.game.input)
 if self.closed then return end
 if before~='remove'and ui.state=='remove'and ui._toss then
  local row=self.tx.store.items[ui.scroll+ui.row+1]
  if not(row and self.tx:toss(row.id,ui.quantity))then
   ui.quantity=0;ui.state='error'
   ui._message=self.load('src.core.game3.rom_text').plain('gText_NoItems');self.tx:refresh()
  end
 elseif before=='remove'and ui.state=='list'then self.tx:refresh()
 elseif before=='swap'and ui.state=='list'then
  if not self.tx:reorder()then self.tx:refresh()end
 end
end
function M:draw()
 local g=love.graphics;local ok,why=require('src.render.GraphicsScope').call(function()
  g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0);self.ui.draw()
 end)
 if not ok then error(why,0)end
 g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
 self.closed=true
 if self.ui and self.ui.open then self.ui.open=false;self.ui._onClose=nil end
 if self.canvas then self.canvas:release()end
 for _,quad in pairs(self.quads)do quad:release()end
 self.canvas,self.load,self.quads=nil,nil,{}
end
return M
