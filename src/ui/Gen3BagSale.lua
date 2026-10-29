-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Independent sale presenter; Gen3ShopMenu retains inventory/payment ownership.
-- View facts: Gen1Recomp fb7b0366, sell_flow and rse/shop_menu.
local M={isOpaque=false,holdsUIAnchors=true,screenId='Gen3BagSale'};M.__index=M
function M.available(game)
  local v=require('src.core.GameVersion').get();local c=game and game.data and game.data.constants
  return require('src.import.Gen3BagSaleAssets').valid(c and c.gen3BagSale,v)
    and require('src.import.Gen3NativeOptionsAssets').valid(c and c.gen3NativeOptions,v)
end
function M.open(owner,row)
  if not M.available(owner.game)then return false end
  local self=M.new(owner.game,owner,row);owner.game.stack:push(self);self:begin()
  return true
end
function M.new(game,owner,row)
  assert(M.available(game));assert(row and row.id)
  local v=require('src.core.GameVersion').get();local self=setmetatable({game=game,owner=owner,
    row=row,version=v,frlg=v~='emerald',mode='opening',qty=1,index=1,k=0},M)
  self.spec=game.data.constants.gen3BagSale
  self.name=assert(game.data.items[row.id]).name or row.id
  self.berry=game.data.items[row.id].pocket=='BERRY'
  if not self.frlg then
    local root=require('src.import.Gen3EmeraldHallAssets').ROOT
    local ui={frames={manifest=game.data.constants.gen3EmeraldHall.manifest,userCount=20,
      user=root..'frame_%d.rgba',std='user',sign=false,
      dialogue={path=root..'message_box.rgba',layout='message_box',manifestKey='message_box'},
      dialogueWindow={left=2,top=15,width=26,height=4}}}
    local context=require('src.ui.Gen3EmeraldSceneContext').new(game,{ui=ui})
    self.load,self.canvas=context.load,context.canvas
  else
    self.load=require('compat.gen1-rs.Loader').new(v,require('src.ui.Gen3FrlgSceneBindings').new(game,{version=v}))
    self.canvas=love.graphics.newCanvas(240,160,{dpiscale=1});self.canvas:setFilter('nearest','nearest')
  end
  self.load('src.ui.game3.chrome').setFrameType(math.max(0,math.min(self.frlg and 9 or 19,
    ((game.save.options or{}).gen3Frame or 1)-1)))
  return self
end
function M:text(key,vars)
  return self.load('src.core.game3.scripting.text_ir').toAscii(assert(self.spec.textIR[key]),{stringVars=vars or{}})
end
function M:amount()return self.unit*self.qty end
function M:begin()
  local def=self.game.data.items[self.row.id]
  if (tonumber(def.price)or 0)<=0 then self.mode='cant';return end
  require('src.ui.Gen3ShopMenu').sellItem(self.game,self.row.id,{
    bagSlot=self.row.rsSlot,max=self.row.qty,creditLimit=999999,
    ask=function(opts)
      self.max=math.min(opts.max,(not self.frlg and self.berry)and 999 or 99)
      self.unit=opts.unit;self.onQuantity=opts.onDone;self.mode='quantity'
      if self.max==1 then self:quantityDone()end
    end,
    confirm=function(_,answer)self.onConfirm=answer;self.mode='confirm';self.index=1 end,
    say=function()
      if self.mode=='committing'then
        self.mode='done';require('src.core.Sound').play(self.game.data,'Purchase')
      else self.mode='cant'end
    end,
    refresh=function()self.owner:rebuild()end,
  })
end
function M:quantityDone()
  local callback=self.onQuantity;self.onQuantity=nil;self.mode='waiting'
  if callback then callback(self.qty)end
  if self.mode=='waiting'then self:close()end
end
function M:answer(yes)
  local callback=self.onConfirm;self.onConfirm=nil;self.mode='committing'
  if callback then callback(yes)end
  -- A stale or refused transaction must not show a successful sale.
  if self.mode=='committing'then self:close()end
end
function M:close()
  if self.closed then return end
  assert(self.game.stack:top()==self,'Native sale lost its bag owner')
  self.closed=true;self.game.stack:pop()
end
function M:update()
  if self.closed then return end
  self.k=self.k+1;local input=self.game.input;local changed=false
  if self.mode=='quantity'then
    local old=self.qty
    if input:wasPressed('up')then self.qty=self.qty==self.max and 1 or self.qty+1
    elseif input:wasPressed('down')then self.qty=self.qty==1 and self.max or self.qty-1
    elseif input:wasPressed('right')then self.qty=math.min(self.max,self.qty+10)
    elseif input:wasPressed('left')then self.qty=math.max(1,self.qty-10)
    elseif input:wasPressed('a')then self:quantityDone();changed=true
    elseif input:wasPressed('b')then self:close();changed=true end
    changed=changed or old~=self.qty
  elseif self.mode=='confirm'then
    if input:wasPressed('up')or input:wasPressed('down')then self.index=3-self.index;changed=true
    elseif input:wasPressed('b')then self:answer(false);changed=true
    elseif input:wasPressed('a')then self:answer(self.index==1);changed=true end
  elseif self.mode=='done'or self.mode=='cant'then
    if input:wasPressed('a')or input:wasPressed('b')then self:close();changed=true end
  end
  if changed then require('src.core.Sound').play(self.game.data,'Press_AB')end
end
function M:uiSize()return self.owner:uiSize()end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return self.owner:sgbPalettes()end
function M:prose()
  if self.mode=='quantity'then return self:text('prompt',self.frlg and{self.name}or{[2]=self.name})end
  if self.mode=='confirm'then return self:text('confirm',self.frlg and{[3]=tostring(self:amount())}or{tostring(self:amount())})end
  if self.mode=='done'then return self:text('done',self.frlg and{self.name,[3]=tostring(self:amount())}or{tostring(self:amount()),self.name})end
  return self:text('cant',self.frlg and{self.name}or{[2]=self.name})
end
function M:drawNative()
  local window=self.load('src.ui.game3.window');local font=self.load('src.ui.game3.frlg_font')
  local normal={colors=font.COLOR.NORMAL};local small={small=true,colors=font.COLOR.NORMAL}
  local function frame(x,y,w,h)window.stdFrame(window.template(x,y,w,h))end
  local function price(amount)return self:text('money',{tostring(amount)})end
  local function rsePrice(amount,x,y)
    font.draw(price(amount),x+38+math.max(0,6-#tostring(amount))*font.advance(0x77),y+1,normal)
  end
  if self.mode~='cant'then
    local cash=math.max(0,math.floor(tonumber(self.game.save.money)or 0))
    if self.frlg then
      frame(1,1,8,3);font.draw(self:text('label'),8,8,normal)
      local value=string.rep(' ',math.max(0,6-#tostring(cash)))..price(cash)
      font.draw(value,72-font.measure(value,{small=true}),20,small)
    else
      frame(1,1,10,2);love.graphics.setColor(1,1,1,1);love.graphics.draw(self.graphic,3,3)
      rsePrice(cash,8,8)
    end
  end
  window.dialogueFrame();local message=font.wrap(self:prose(),208)
  font.draw(message,16,121,{colors=font.COLOR.NORMAL,maxWidth=208})
  if self.mode=='quantity'then
    local digits=(not self.frlg and self.berry)and 3 or 2
    local count=self:text('count',{string.format('%0'..digits..'d',self.qty)})
    if self.frlg then
      frame(17,9,12,4);font.draw(count,140,82,{small=true,letterSpacing=1,colors=font.COLOR.NORMAL})
      font.draw(string.rep(' ',math.max(0,6-#tostring(self:amount())))..price(self:amount()),192,82,small)
      local trig=self.load('src.core.game3.trig')
      local function bob(freq)local n=trig.sin((self.k*freq)%256)*2/256;return n<0 and math.ceil(n)or math.floor(n)end
      love.graphics.setColor(1,1,1,1)
      love.graphics.draw(self.graphic,self.arrow,144,64+bob(8))
      love.graphics.draw(self.graphic,self.arrow,144,112+bob(-8),0,1,-1)
    else frame(18,11,10,2);font.draw(count,144,89,normal);rsePrice(self:amount(),144,88)end
  elseif self.mode=='confirm'then
    frame(21,9,self.frlg and 6 or 5,4);local y=self.frlg and 74 or 73
    local pitch=self.frlg and font.LINE_PITCH or window.optionHeight()
    font.draw(self:text('yes'),176,y,normal);font.draw(self:text('no'),176,y+pitch,normal)
    window.cursorPx(168,y+(self.index-1)*pitch)
  end
end
function M:draw()
  local g=love.graphics
  if not self.graphic then
    local bytes=assert(love.filesystem.read(self.spec.graphic));assert(#bytes==2048)
    local data=love.image.newImageData(self.frlg and 16 or 32,self.frlg and 32 or 16,'rgba8',bytes)
    self.graphic=g.newImage(data);data:release()
    self.graphic:setFilter('nearest','nearest')
    if self.frlg then self.arrow=g.newQuad(0,16,16,16,16,32)end
  end
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0);self:drawNative()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,math.floor((self:uiSize()-240)/2),0)
end
function M:exit()
  self.closed=true;self.onConfirm,self.onQuantity=nil,nil
  for _,name in ipairs{'arrow','graphic','canvas'}do if self[name]then self[name]:release();self[name]=nil end end
  self.load=nil
end
return M
