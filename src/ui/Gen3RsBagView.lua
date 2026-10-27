-- Read-only presentation adapter for the byte-exact RS reference renderer.
-- The host owns inventory, item use, registered IDs and every callback.
local Loader = require('compat.gen1-rs.Loader')
local Font = require('src.render.Font')
local Assets = require('src.render.Assets')
local M = {}
M.__index = M
local POCKETS = {'ITEMS','POKE_BALLS','TM_CASE','BERRY_POUCH','KEY_ITEMS'}
local ACTION = {use='USE',toss='TOSS',give='GIVE',cancel='CANCEL',
  register='SET',checkTag='CHECK_TAG',confirm='CONFIRM'}

function M.available(game)
  local s = game and game.data and game.data.constants and game.data.constants.gen3RsBag
  local v = require('src.core.GameVersion').get()
  return type(s)=='table' and s.format==1 and s.version==v and (v=='ruby' or v=='sapphire')
end

local function readTable(path)
  local chunk = assert(love.filesystem.load(path), 'Missing native RS bag manifest '..path)
  setfenv(chunk,{})
  return chunk()
end

-- Reference maxWidth clips glyphs; it does not abbreviate or wrap names.
-- Explicit ROM newlines keep the native sixteen-pixel pitch.
local function drawText(text,x,y,opts)
  local colors = assert(opts.colors)
  Font.pushStyle({text=colors.fg,shadow=colors.shadow})
  local ok,err = pcall(function()
    for line in (tostring(text or '')..'\n'):gmatch('(.-)\n') do
      local pen=0
      for _,code in ipairs(Font.encode(line)) do
        local w=Font.advanceOf(code)
        if pen+w <= opts.maxWidth or pen==0 then
          Font.drawCode(code,x+pen,y)
          pen=pen+w
        end
      end
      y=y+(opts.linePitch or 16)
    end
  end)
  Font.popStyle()
  if not ok then error(err,0) end
end

function M.new(bag)
  local self=setmetatable({bag=bag,manifests={},images={},frameQuads={}},M)
  local game=bag.game
  local spec=assert(game.data.constants.gen3RsBag)
  local pcSpec=game.data.constants.gen3RsItemPc
  local function textIR(key)
    return pcSpec and pcSpec.textIR[key]or spec.tossTextIR and spec.tossTextIR[key]
  end
  local function manifest(sub)
    if not self.manifests[sub] then
      local man=readTable('data/generated/gba/'..sub..'/manifest.lua')
      assert(man.game==spec.version and man.layout=='rs','Mixed-edition RS bag cache')
      self.manifests[sub]=man
    end
    return self.manifests[sub]
  end
  local function image(path)
    assert(Assets.exists(path),'Missing native RS bag image '..tostring(path))
    return Assets.image(path)
  end
  local palette={[0]={0,0,0,0}}
  for i=1,15 do
    local w=assert(spec.palette[i+1])
    local function channel(v)return math.floor(v*255/31+0.5)/255 end
    palette[i]={channel(w%32),channel(math.floor(w/32)%32),channel(math.floor(w/1024)%32),1}
  end
  local font={STDPAL=palette,COLOR={NORMAL={fg=palette[1],shadow=palette[8],bg=palette[0]}},
    sync=function()end,measure=function(s)return Font.width(s)end}
  font.draw=function(str,x,y,opts)
    local g=self.grid
    -- The native berry grid gives CHECK TAG the first row's full 96px.
    -- The pinned renderer passes a generic 48px text clip despite its own
    -- 96px cursor, cutting off G. Correct only that spanning blank cell.
    if g and g.rows==3 and g.cols==2 and g.cells[1]=='CHECK_TAG' and not g.cells[4]
      and str==spec.text.OtherText_CheckTag and x==8 and y==48 then
      local wide={}
      for k,v in pairs(opts)do wide[k]=v end
      wide.maxWidth=self.renderer.cursorWidth(self.view,g,1)
      return drawText(str,x,y,wide)
    end
    return drawText(str,x,y,opts)
  end
  local function frame(tx,ty,tw,th)
    local count=manifest('rse/bag_chrome').frames
    local n=math.max(1,math.min(#count,math.floor(tonumber((game.save.options or {}).gen3Frame) or 1)))
    local img=image(count[n])
    local q=self.frameQuads
    if not q[0] then
      local w,h=img:getDimensions()
      for i=0,8 do q[i]=love.graphics.newQuad(i%3*8,math.floor(i/3)*8,8,8,w,h) end
    end
    love.graphics.setColor(1,1,1,1)
    love.graphics.rectangle('fill',tx*8,ty*8,tw*8,th*8)
    for row=-1,th do for col=-1,tw do
      local tile
      if row==-1 then tile=col==-1 and 0 or col==tw and 2 or 1
      elseif row==th then tile=col==-1 and 6 or col==tw and 8 or 7
      elseif col==-1 then tile=3 elseif col==tw then tile=5 end
      if tile then love.graphics.draw(img,q[tile],(tx+col)*8,(ty+row)*8) end
    end end
  end
  local function info(id) return (game.data.items or {})[id] or {} end
  local berries,berryNumbers={},{}
  for id,d in pairs(game.data.items or {}) do
    if d.pocket=='BERRY' then berries[#berries+1]={id=id,index=d.index} end
  end
  table.sort(berries,function(a,b)return a.index<b.index end)
  for n,row in ipairs(berries) do berryNumbers[row.id]=n end
  self.load=Loader.new(spec.version,{
    ['src.ui.game3.rse.scene_kit']={manifest=manifest,image=image,playSe=function(name)
      return require('src.core.Sound').playId(game.data,assert(game.data.constants.gen3RsPresentation.songIds[name]))
    end},
    ['src.ui.game3.frlg_font']=font,
    ['src.ui.game3.chrome']={stdFrame=frame,dialogueFrame=function()
      assert(bag.rsPcChrome,'Native PC message frame required').dialogueFrame()
    end},
    ['src.core.game3.gba_fx']={draw=function(fn)fn()end},
    ['src.core.game3.rom_text']={overrides={},has=function(key)return textIR(key)~=nil end,ir=textIR,
      plain=function(key,ctx)
      if textIR(key)then
        return self.load('src.core.game3.scripting.text_ir').toAscii(textIR(key),ctx)
      end
      return (self.actionLabels and self.actionLabels[key]) or assert(spec.text[key],'Missing RS bag text '..tostring(key))
    end},
    ['src.core.game3.items_data']={info=info,toNumericId=function(id)return info(id).index or tonumber(id) or 0 end,
      isHm=function(id)return info(id).machine and info(id).machine.kind=='HM' end,
      tmNumber=function(id)return info(id).machine and info(id).machine.number end,
      berryNumber=function(id)return berryNumbers[id] end,fieldUseKind=function()end},
    ['src.core.game3.bag']={removeSlot=function(store,pocket,index,qty)
      local view=self.view;local selected=assert(view._rsBag.deposit or view._rsBag.toss)
      assert(store==view._bag and pocket==view.currentPocket()and index==selected.index)
      local row=bag.rows[index]
      if view._rsBag.deposit then
        local receipt=assert(self.depositReceipt,'Native deposit must commit both stores before acknowledgement')
        assert(receipt.id==selected.id and receipt.qty==qty and row and row.id==selected.id)
        self.depositReceipt=nil;bag:rebuild();self:prepare();return true
      end
      local held=row and row.qty or 0
      if not row or row.id~=selected.id or type(qty)~='number'or qty%1~=0 or qty<1 or qty>held
        or require('src.ui.Gen3BagMenu').isImportant(game,selected.id)then return false end
      local removed=require('src.inventory.Bag').remove(game.save,selected.id,qty,game.data,row.rsSlot)
      if removed==false then return false end
      if not game.save.inventory[selected.id]and game.save.registeredItem==selected.id then
        game.save.registeredItem=nil
      end
      bag:rebuild();self:prepare();return true
    end},
    ['src.core.game3.options']={lrMode=function()return false end}, -- Host owns pocket navigation.
    ['src.core.game3.storage']={addPcItem=function(session,id,qty)
      assert(session==self.view._session and bag.rsPcTransaction)
      local selected=assert(self.view._rsBag.deposit);local row=bag.rows[selected.index]
      if not row or row.id~=id or not row.rsSlot then return false end
      local ok=bag.rsPcTransaction:deposit(row.rsSlot,qty)
      if ok then self.depositReceipt={id=id,qty=qty}end
      return ok
    end},
    ['src.core.game3.mail']={isMailItem=function(id)
      for _,d in pairs(game.data.items or {}) do if d.index==id then return d.mail==true end end
      return false
    end},
    ['src.core.game3.pokemon']={moveFromTmItem=function(id)return info(id).machine and info(id).machine.move end,
      moveName=function(id)return assert(game.data.moves[id]).name end},
  })
  self.renderer=self.load('src.ui.game3.rs.bag_menu')
  self.data=self.load('src.ui.game3.rs.bag_menu_data')
  local grid=self.renderer.grid
  self.renderer.grid=function(view,row)return self.grid or grid(view,row)end
  self.view={open=true,_rsBag={frame=0,gridPos=1,pos={}},_session={},_bag={},mode='list',
    list=function()return self.rows end,currentPocket=function()return POCKETS[bag.pocket] end}
  self.view.showMessage=function(text)
    local pages={};for page in(tostring(text)..'\f'):gmatch('(.-)\f')do pages[#pages+1]=page end
    self.view.messagePages=pages;self.view.messagePage=1
    self.view.messageText=pages[1];self.view.mode='message'
  end
  self.view.handleInput=function(input)
    local view=self.view
    assert(view.mode=='message','Unexpected delegated native RS bag mode')
    if input:wasPressed('a')or input:wasPressed('b')or input:wasPressed('start')then
      require('src.core.Sound').playId(game.data,game.data.constants.gen3RsPresentation.songIds.SE_SELECT)
      view.messagePage=view.messagePage+1
      if view.messagePages[view.messagePage]then view.messageText=view.messagePages[view.messagePage]
      else view.mode='list';view.messageText=nil;view.messagePages=nil;view._rsBag.deposit=nil end
    end
  end
  return self
end

function M:prepare(actionMenu)
  local bag,view=self.bag,self.view
  self.rows={}
  for _,row in ipairs(bag.rows) do
    if not row.close then
      self.rows[#self.rows+1]={id=row.id,name=row.label,qty=row.qty,description=row.description,
        info=(bag.game.data.items or {})[row.id]}
    end
  end
  view.cursor,view.scroll,view.pocketIdx=bag.index,bag.top-1,bag.pocket
  local player=bag.game.save.player or {}
  view._session.gender=player.gender=='girl' and 'female' or player.gender=='boy' and 'male' or bag.game.save.gender
  view._session.playerGender=bag.game.save.playerGender
  if bag.rsTutorial then view._session.gender='male';view._session.playerGender=0 end
  view._session.registeredItem=bag.game.save.registeredItem
  view._rsBag.frame=bag.tick or 0
  view._rsBag.swap=bag.rsSwap
  view._rsBag.shake=bag.rsShake
  view._rsBag.ball=bag.rsBall
  view._rsBag.bagDrop=bag.rsDrop
  view._open=bag.rsOpen and {k=bag.rsOpen} or nil
  view._switch=bag.rsSwitch and {k=bag.rsSwitch} or nil
  view._battle=bag.battle
  view._location=bag.sell and 'shop' or bag.store=='deposit' and 'itempc'
    or bag.pick and 'berry_tree' or nil
  view.mode=(bag.rsToss or bag.rsDeposit)and view.mode or bag.rsSaleActive and 'sell' or actionMenu and 'action' or 'list'
  if bag.message and self.rows[bag.index] then self.rows[bag.index].description=bag.message end
  self.grid,self.actionLabels=nil,nil
  if actionMenu then
    local cells,labels={},{}
    local nr,nc=actionMenu.rows,actionMenu.columns
    for c=0,nc-1 do for r=0,nr-1 do
      local e=actionMenu.entries[r*nc+c+1]
      local action=e and ACTION[e.kind]
      cells[#cells+1]=action or false
      if action then labels[self.data.ACTION_TEXT[action]]=e.label end
    end end
    self.grid={cells=cells,rows=nr,cols=nc}
    self.actionLabels=labels
    view._rsBag.gridPos=(actionMenu.index-1)%nc*nr+math.floor((actionMenu.index-1)/nc)+1
  end
end

function M:beginToss(id)
  self:prepare()
  local row=assert(self.rows[self.bag.index]);assert(row.id==id)
  assert(not require('src.ui.Gen3BagMenu').isImportant(self.bag.game,id))
  self.view._open,self.view._switch=nil,nil
  assert(self.renderer.beforeAction(self.view,'TOSS',row))
  self.bag.rsToss=true
end

function M:updateToss(input)
  self.renderer.handleInput(input,self.view)
  if self.view.mode=='list'then self.bag.rsToss=nil end
end

function M:beginDeposit(id)
  self:prepare()
  local row=assert(self.rows[self.bag.index]);assert(row.id==id and self.bag.rsPcTransaction)
  self.view._open,self.view._switch=nil,nil;self.bag.rsDeposit=true
  self.renderer.handleInput({wasPressed=function(_,key)return key=='a'end,isDown=function()return false end},self.view)
end
function M:updateDeposit(input)
  self.renderer.handleInput(input,self.view)
  if self.view.mode=='list'then self.bag.rsDeposit=nil end
end

function M:draw(actionMenu)
  self:prepare(actionMenu)
  love.graphics.push('all')
  local ok,err=pcall(self.renderer.draw,self.view)
  love.graphics.pop()
  self.grid,self.actionLabels=nil,nil
  if not ok then error(err,0) end
end

return M
