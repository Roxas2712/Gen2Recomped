-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Independent adapter: native item_menu window/font facts, host inventory IO.
-- Layout reference: Gen1Recomp fb7b0366, game3 bag_menu / rse/bag_menu.
local M={isOpaque=false,holdsUIAnchors=true,screenId='Gen3BagToss'};M.__index=M
function M.available(game)
  local version=require('src.core.GameVersion').get()
  local c=game and game.data and game.data.constants
  return require('src.import.Gen3BagTossAssets').valid(c and c.gen3BagToss,version)
    and require('src.import.Gen3NativeOptionsAssets').valid(c and c.gen3NativeOptions,version)
end
function M.open(owner,id,berry)
  local game=owner.game
  if not M.available(game)then return false end
  if require('src.ui.Gen3BagMenu').isImportant(game,id)then return true end
  local held=(game.save.inventory or{})[id]or 0
  if held<1 then return true end
  local def=game.data.items and game.data.items[id]
  game.stack:push(M.new(game,owner,{max=held,name=def and def.name or id,
    berry=berry==true or(def and def.pocket=='BERRY'),onCommit=function(qty)
      if qty<1 or qty%1~=0 or qty>((game.save.inventory or{})[id]or 0)then return false end
      require('src.inventory.Bag').remove(game.save,id,qty,game.data)
      owner:rebuild();return true
    end}))
  return true
end
function M.new(game,owner,opts)
  assert(M.available(game));assert(owner and opts and type(opts.onCommit)=='function')
  local version=require('src.core.GameVersion').get()
  local self=setmetatable({game=game,owner=owner,version=version,frlg=version~='emerald',
    max=math.max(1,math.floor(tonumber(opts.max)or 1)),qty=1,index=1,name=assert(opts.name),
    onCommit=opts.onCommit,oldMessage=owner.message,berry=opts.berry==true},M)
  self.mode=self.max==1 and'confirm'or'quantity'
  if version=='emerald'then
    local root=require('src.import.Gen3EmeraldHallAssets').ROOT
    local ui={frames={manifest=game.data.constants.gen3EmeraldHall.manifest,userCount=20,
      user=root..'frame_%d.rgba',std='user',sign=false,
      dialogue={path=root..'message_box.rgba',layout='message_box',manifestKey='message_box'},
      dialogueWindow={left=2,top=15,width=26,height=4}}}
    local context=require('src.ui.Gen3EmeraldSceneContext').new(game,{ui=ui})
    self.load,self.canvas=context.load,context.canvas
  else
    local bindings=require('src.ui.Gen3FrlgSceneBindings').new(game,{version=version})
    self.load=require('compat.gen1-rs.Loader').new(version,bindings)
    self.canvas=love.graphics.newCanvas(240,160,{dpiscale=1});self.canvas:setFilter('nearest','nearest')
  end
  self.load('src.ui.game3.chrome').setFrameType(math.max(0,math.min(self.frlg and 9 or 19,
    ((game.save.options or{}).gen3Frame or 1)-1)))
  self:refreshMessage()
  return self
end
function M:text(key,count)
  local words=self.game.data.constants.gen3BagToss.textIR
  local vars=count and{count}or{self.name,tostring(self.qty)}
  return self.load('src.core.game3.scripting.text_ir').toAscii(assert(words[key]),{stringVars=vars})
end
function M:refreshMessage()
  self.message=self:text(self.mode=='quantity'and'prompt'or self.mode)
  -- Emerald keeps this prose in the bag's existing description window.
  if not self.frlg then self.owner.message=self.message end
end
function M:uiSize()return self.owner:uiSize()end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return self.owner:sgbPalettes()end
function M:close()
  if self.closed then return end
  assert(self.game.stack:top()==self,'Native bag toss lost its owner')
  self.closed=true;self.game.stack:pop()
end
function M:update()
  if self.closed then return end
  local input=self.game.input;local changed=false
  if self.mode=='quantity'then
    local before=self.qty
    -- Keep the selected reference controller's bounded four-direction step.
    if input:wasPressed('up')or input:wasPressed('right')then self.qty=math.min(self.max,self.qty+1);changed=true
    elseif input:wasPressed('down')or input:wasPressed('left')then self.qty=math.max(1,self.qty-1);changed=true
    elseif input:wasPressed('a')then self.mode='confirm';self.index=1;self:refreshMessage();changed=true
    elseif input:wasPressed('b')then self:close();changed=true end
    if self.qty~=before then self:refreshMessage()end
  elseif self.mode=='confirm'then
    if input:wasPressed('up')or input:wasPressed('down')then self.index=3-self.index;changed=true
    elseif input:wasPressed('b')then self:close();changed=true
    elseif input:wasPressed('a')then
      changed=true
      if self.index==2 then self:close()
      elseif not self.committed then
        -- Only the caller's existing Bag.remove/rebuild path mutates items.
        if self.onCommit(self.qty)==false then self:close()
        else self.committed=true;self.mode='done';self:refreshMessage()end
      end
    end
  elseif input:wasPressed('a')or input:wasPressed('b')then self:close();changed=true end
  if changed then require('src.core.Sound').play(self.game.data,'Press_AB')end
end
function M:drawNative()
  local window=self.load('src.ui.game3.window');local font=self.load('src.ui.game3.frlg_font')
  local function frame(x,y,w,h)window.stdFrame(window.template(x,y,w,h))end
  local function prose(width)
    frame(6,15,width,4)
    font.draw(font.wrap(self.message,width*8),48,122,{colors=font.COLOR.NORMAL,maxWidth=width*8,linePitch=15})
  end
  if self.frlg then prose(self.mode=='done'and 23 or self.mode=='confirm'and 15 or 16)end
  if self.mode=='quantity'then
    local digits=self.frlg and 3 or self.berry and 3 or 2
    local count=self:text('count',string.format('%0'..digits..'d',self.qty))
    if self.frlg then
      frame(24,15,5,4);font.draw(count,196,130,{small=true,colors=font.COLOR.NORMAL})
    else
      frame(24,17,5,2);font.draw(count,192+math.floor((40-font.measure(count))/2),138,{colors=font.COLOR.NORMAL})
    end
  elseif self.mode=='confirm'then
    local x=self.frlg and 23 or 24;frame(x,15,self.frlg and 6 or 5,4)
    local y=self.frlg and 122 or 121
    font.draw(self:text('yes'),x*8+8,y,{colors=font.COLOR.NORMAL})
    font.draw(self:text('no'),x*8+8,y+16,{colors=font.COLOR.NORMAL})
    window.cursorPx(x*8,y+(self.index-1)*16)
  end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
    self:drawNative()
  end)
  if not ok then error(why,0)end
  local width=self:uiSize();g.setColor(1,1,1,1);g.draw(self.canvas,math.floor((width-240)/2),0)
end
function M:exit()
  self.closed=true;self.owner.message=self.oldMessage;self.onCommit=nil
  if self.canvas then self.canvas:release()end
  self.canvas,self.load=nil,nil
end
return M
