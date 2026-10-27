-- Native RS shop controller over the host's authoritative bag and money.
local M={};M.__index=M;M.isOpaque=false;M.holdsUIAnchors=true;M.screenId='Gen3RsShop'
function M.available(game,opts)
  local v=require('src.core.GameVersion').get()
  local s=game and game.data and game.data.constants and game.data.constants.gen3RsShop
  if not((v=='ruby'or v=='sapphire')and type(s)=='table'and s.version==v and s.format==1)then return false end
  local seen={}
  for _,def in pairs(game.data.items or {})do if def.index then
    if seen[def.index]then return false end
    seen[def.index]=true
  end end
  if opts and opts.kind~='decoration'then
    for _,id in ipairs(opts.stock or {})do
      local def=(game.data.items or {})[id]
      if not def or type(def.index)~='number'then return false end
    end
  end
  return true
end
function M.new(game,opts)
  assert(M.available(game,opts));opts=opts or {}
  local tx=require('src.inventory.Gen3RsShopTransaction').new(game)
  local self=setmetatable({game=game,opts=opts,transaction=tx,session=tx.session},M)
  local manifests={}
  local function manifest(sub)
    if not manifests[sub]then
      local f=assert(love.filesystem.load('data/generated/gba/'..sub..'/manifest.lua'));setfenv(f,{})
      manifests[sub]=f();assert(manifests[sub].game==self.session.version,'Mixed-edition RS shop pack')
    end
    return manifests[sub]
  end
  local items={info=function(n)return tx:row(n).def end,
    displayName=function(n)return tx:row(n).def.name end,
    description=function(n)return tx:row(n).def.description or ''end,
    toNumericId=function(n)return type(n)=='number'and n or tx:number(n)end,
    pocketOf=function(n)
      local d=tx:row(n).def
      return ({ITEM='ITEMS',BALL='POKE_BALLS',KEY_ITEM='KEY_ITEMS',TM_HM='TM_CASE',BERRY='BERRY_POUCH'})[d.pocket]or d.pocket
    end}
  local C=require('compat.gen1-rs.Constants').new(require('compat.gen1-rs.Loader').new(self.session.version))
  C.items=require('compat.gen1-rs.Loader').new(self.session.version)('src.core.game3.constants.ruby.items')
  local background
  local function cacheRead(_,path)return love.filesystem.read(path)end
  local function drawBg(x,y)
    if not background then
      local raw=assert(cacheRead(nil,'data/generated/gba/items/shop/'..manifest('items/shop').bg))
      background=love.graphics.newImage(love.image.newImageData(240,160,'rgba8',raw));background:setFilter('nearest','nearest')
    end
    love.graphics.setColor(1,1,1,1);love.graphics.draw(background,x,y)
  end
  local decor=require('src.world.Gen3Decorations')
  local bindings={
    ['src.core.game3.display']={W=240,H=160,TILE=8,COLS=30,ROWS=20},
    ['src.core.game3.constants']={of=function()return C end},
    ['src.core.game3.dataset']={cache=function()return {read=cacheRead}end},
    ['src.core.game3.items_data']=items,['src.core.game3.bag']=tx:bindings(),
    ['src.ui.game3.shop_chrome']={drawBg=drawBg},
    ['src.core.game3.rse.decoration_inventory']={info=function(n)return decor.byId(game.data,n)end,
      add=function(n)if not decor.roomFor(game.data,game.save,n)then return false end;return decor.give(game.save,n,1)end},
    ['src.core.game3.rse.tv']={isPokeNewsActive=function(_,kind,applies)
      for _,row in pairs(game.save.gen3PokeNews or {})do
        if row.kind==kind then return row.state==2 and applies~=nil and applies(kind)==true end
      end
      return false
    end},
    ['src.core.game3.rse.init']={call=function(system,name,_,_,...)
      assert(system=='tv','Unexpected native shop service')
      if name=='shouldApplyPokeNews'then
        return game.overworld and game.overworld.map.id=='MAP_G00_N01'and opts.localId==25 or false
      end
      assert(name=='tryPutSmartShopperOnAir','Unexpected native shop TV request')
      -- Keep the actual native purchase history available to the caller.
      -- Full TV show generation remains a separate host integration.
      self.purchaseHistory=(...)
    end},
    ['src.ui.game3.bag_menu']={show=function(_,options)
      local bag=require('src.ui.Gen3BagMenu').new(game,{sell=true,onCancel=options.onClose,
        onSell=function(id,screen)self:openSale(id,screen)end})
      local update,draw=bag.update,bag.draw
      function bag:update(dt)
        self.rsShopOwner.fade.tick(dt or 1/60);return update(self,dt)
      end
      function bag:draw()
        draw(self)
        local fade=self.rsShopOwner.fade
        if fade.active or (fade.t or 0)>0 then self.rsShopOwner:render(function()end)end
      end
      bag.rsShopOwner=self
      self.sellBag=bag;game.stack:push(bag)
    end,currentPocket=function()
      local bag=self.sellBag;local row=bag and bag.pockets[bag.pocket]
      return row and ({BERRY='BERRY_POUCH'})[row.key]or row and row.key
    end},
    ['src.core.game3.pokemon']={moveFromTmItem=function(n)
      local d=tx:row(n).def;return type(d.machine)=='table'and d.machine.move or d.move
    end,moveName=function(id)return game.data.moves[id]and game.data.moves[id].name or ''end},
  }
  local context=require('src.ui.Gen3RsSceneContext').new(game,{bindings=bindings,
    packageLoaded={['src.core.game3.scripting.space']=false}})
  self.load,self.canvas=context.load,context.canvas
  self.ui=self.load('src.ui.game3.rs.shop_menu');self.fade=self.load('src.ui.game3.fade')
  local profile=self.load('src.core.game3.profile');profile.family=function()return 'rse'end
  profile.forSession().ui.shopMenu=self.ui
  local text=self.load('src.core.game3.rom_text')
  text.irOr=function(key,fallback)return text.has(key)and text.ir(key)or fallback end
  local shop={_session=self.session,_items={},close=function()self:close()end}
  for i,id in ipairs(opts.stock or {})do shop._items[i]=opts.kind=='decoration'and id or tx:number(id)end
  self.shop=shop
  self.ui.show(shop,{martType=opts.kind=='decoration'and(opts.shopMode==2 and 'DECOR2'or 'DECOR')or 'NORMAL'})
  return self
end
function M:close()
  if self.closed then return end
  self.closed=true;self.game.stack:pop()
  if self.opts.onQuit then self.opts.onQuit()end
end
function M:openSale(id,bag)
  local game=self.game;local screen={isOpaque=false,holdsUIAnchors=true,screenId='Gen3RsShopSale'}
  local selected=assert(bag:selected());assert(selected.id==id,'Sale selection changed')
  self.transaction.selection=selected.rsSlot
  screen.uiSize=M.uiSize;screen.wantsFillScale=M.wantsFillScale;screen.sgbPalettes=M.sgbPalettes
  local flow=self.load('src.ui.game3.sell_flow').start({itemId=self.transaction:number(id),
    session=self.session,bag=self.transaction.token,owned=selected.qty,
    onDone=function()game.stack:pop();bag:rebuild()end})
  screen.flow=flow
  bag.rsSaleActive=true
  local tx=self.transaction
  function screen:exit()bag.rsSaleActive=nil;tx.selection=nil end
  function screen:update(dt)
    self.owner.fade.tick(dt or 1/60);flow:handleInput(game.input);self.state=flow.state
  end
  function screen:draw()self.owner:render(function()flow:draw()end)end
  screen.owner=self;game.stack:push(screen)
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return {require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:worldCamera(world)
  if self.shop.mode~='buy'then return end
  local p=world.player;local x,y=p.cellX,p.cellY
  local d=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[p.facing]or {-1,0}
  return (x+d[1]+self.ui.CAMERA_OFFSET.x)*16,(y+d[2]+self.ui.CAMERA_OFFSET.y)*16
end
function M:update(dt)
  if self.closed then return end
  self.fade.tick(dt or 1/60);self.ui.handleInput(self.shop,self.game.input)
  self.state,self.mode=self.shop.state,self.shop.mode
  self.index=self.shop.mode=='root'and self.shop.cursor or self.shop.scroll+self.shop.row+1
end
function M:render(draw)
  local g=love.graphics;local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
    draw();self.fade.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:draw()self:render(function()self.ui.draw(self.shop)end)end
function M:exit()
  self.closed=true
  if self.ui then self.ui.reset()end
  if self.fade then self.fade.clear()end
  if self.canvas then self.canvas:release()end
  self.ui,self.canvas,self.load=nil,nil,nil
end
return M
