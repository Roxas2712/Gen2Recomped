-- Exact RS player/item-PC controllers over stable host inventory transactions.
local M={};M.__index=M;M.isOpaque=false;M.holdsUIAnchors=true;M.screenId='Gen3RsPlayerPC'
function M.available(game)
  local version=require('src.core.GameVersion').get()
  if not require('src.import.Gen3RsItemPcAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3RsItemPc,version)then return false end
  local seen={}
  for _,d in pairs(game.data.items or{})do if d.index then
    if seen[d.index]then return false end;seen[d.index]=true
  end end
  local slots=0
  for id,qty in pairs(game.save.pcItems or{})do
    local def=game.data.items[id]
    if not def or type(def.index)~='number'or def.index<=0 or type(qty)~='number'
      or qty~=qty or qty%1~=0 or qty<1 or qty>999 then return false end
    slots=slots+1
  end
  -- Keep malformed/overfilled legacy PC saves accessible through the old
  -- non-destructive menu; never truncate them just to enable this renderer.
  return slots<=50
end
local function rootContext(game)
  local version=require('src.core.GameVersion').get()
  local load=require('compat.gen1-rs.Loader').new(version)
  local symbols=load('src.import.gba.syms').of(version)
  local function text(symbol)
    return assert(game.data.text[('TEXT_%X'):format(symbols.off(symbol))],
      'Missing original RS PC field text '..symbol)
  end
  return version,load,text
end
function M.rootRows(game)
  if not M.available(game)then return end
  local version,base=rootContext(game)
  local C=require('compat.gen1-rs.Constants').new(base)
  local ir=base('src.core.game3.scripting.text_ir')
  local name=(game.save.player or{}).name or''
  local load=require('compat.gen1-rs.Loader').new(version,{
    __package={loaded={}},['src.ui.game3.window']={},['src.ui.game3.frlg_font']={},
    ['src.core.game3.storage']={},['src.core.game3.profile']={forSession=function()return{id=version}end},
    ['src.core.game3.scripting.flags']={forVersion=function()return{IDS={
      FLAG_SYS_GAME_CLEAR=C:flag('FLAG_SYS_GAME_CLEAR'),FLAG_SYS_PC_LANETTE=C:flag('FLAG_SYS_PC_LANETTE')}}end,
      getFlag=function(_,_,id)
        local flags=game.save.flags or{};local v=flags[id]
        if v==nil then v=flags[('FLAG_G3_%04X'):format(id)]end
        return v==true or v==1
      end},
    ['src.core.game3.rom_text']={plain=function(key,ctx)
      return ir.toAscii(assert(game.data.constants.gen3RsItemPc.textIR[key]),ctx)
    end},
  })
  return load('src.ui.game3.rse.player_pc').rootEntries({_session={version=version,name=name}})
end
function M.decorateRoot(menu,game,rows)
  local _,_,fieldText=rootContext(game)
  local context=require('src.ui.Gen3RsSceneContext').new(game,{
    bindings={['src.core.game3.storage']={}},textIR=game.data.constants.gen3RsItemPc.textIR})
  local owner=setmetatable({game=game,load=context.load,canvas=context.canvas},M)
  local ui=context.load('src.ui.game3.rse.player_pc');local labels={}
  for i,row in ipairs(rows)do labels[i]=row.label end
  local pc={_session={version=require('src.core.GameVersion').get()},
    _status=fieldText('Text_WhichPCShouldBeAccessed')}
  local update,exit=menu.update,menu.exit
  menu.screenId='Gen3RsPcRoot';menu.holdsUIAnchors=true
  menu.uiSize,menu.wantsFillScale,menu.wantsEdgeBleed,menu.sgbPalettes=M.uiSize,M.wantsFillScale,M.wantsEdgeBleed,M.sgbPalettes
  function menu:update(dt)
    for _,key in ipairs({'up','down','a','b'})do if game.input:wasPressed(key)then
      require('src.core.Sound').playId(game.data,game.data.constants.gen3RsPresentation.songIds.SE_SELECT);break
    end end
    return update(self,dt)
  end
  function menu:draw()owner:render(function()
    ui.drawMenu(labels,self.index,#labels*2);ui.drawStatus(pc)
  end)end
  function menu:exit()
    if exit then exit(self)end
    if owner.canvas then owner.canvas:release();owner.canvas=nil end
  end
  return menu
end
function M.bootMessage(game)
  local _,_,text=rootContext(game)
  local name=(game.save.player or{}).name or''
  return(text('Text_BootUpPC'):gsub('{PLAYER}',function()return name end))
end
function M.new(game,opts)
  assert(M.available(game));opts=opts or{}
  local self=setmetatable({game=game,opts=opts},M)
  self.tx=require('src.inventory.Gen3RsItemPcTransaction').new(game)
  assert(self.tx.valid,'Unsupported native item PC contents')
  self.session=self.tx.session
  if require('src.ui.Gen3RsMailView').available(game)then
    self.mail=require('src.inventory.Gen3RsMail').new(game)
  end
  local items={}
  function items.info(n)return game.data.items[self.tx:id(n)]or{}end
  function items.displayName(n)local d=items.info(n);return d.name or self.tx:id(n)end
  function items.description(n)local d=items.info(n);return d.description or d.desc or''end
  function items.toNumericId(id)return type(id)=='number'and id or self.tx:number(id)end
  function items.pocketOf(n)local p=items.info(n).pocket
    return({ITEM='ITEMS',BALL='POKE_BALLS',TM_HM='TM_CASE',BERRY='BERRY_POUCH',KEY_ITEM='KEY_ITEMS'})[p]or p
  end
  function items.isHm(n)local d=items.info(n);return d.machine and d.machine.kind=='HM'end
  local bindings={
    ['src.core.game3.items_data']=items,
    ['src.core.game3.storage']={ensure=function(s)assert(s==self.session);return self.tx.store end},
    ['src.core.game3.bag']={
      canAdd=function(token,n,q)assert(token==self.tx.token);return self.tx:canWithdraw(n,q)end,
      add=function(token,n,q)assert(token==self.tx.token);return self.tx:withdraw(n,q)end,
    },
    ['src.core.game3.mail']={MAIL_COUNT=16,pool=function()
      if self.mail and self.mail:refresh()then return self.mail.session.mail end
      return{}
    end,isEmpty=function(record)return not record or(record.itemId or 0)==0 end},
    ['src.ui.game3.rse.mailbox']={show=function(options)
      game.stack:push(require('src.ui.Gen3RsMailbox').new(game,{onDone=options.onClose}))
    end},
    ['src.ui.game3.stack']={
      push=function(id,ui)assert(id=='rse_item_storage');self:pushStorage(ui)end,
      pop=function(id)assert(id=='rse_item_storage');self:popStorage()end,
    },
    ['src.ui.game3.bag_menu']={show=function(token,options)
      assert(token==self.tx.token and options.location=='itempc')
      local bag=require('src.ui.Gen3BagMenu').new(game,{store='deposit',onCancel=function()
        self.tx:refresh();options.onClose()
      end})
      bag.rsPcTransaction=self.tx
      bag.rsPcChrome=self.load('src.ui.game3.chrome');game.stack:push(bag)
    end},
    ['src.core.game3.rse.init']={system=function(system,name)
      assert(system=='decorationMenu'and name=='DoPlayerRoomDecorationMenu')
      return{open=function(options)
        require('src.script.Gen3Commands').decorationPC(
          {game=game,save=game.save,overworld=game.overworld},options.onClose)
      end}
    end},
  }
  local context=require('src.ui.Gen3RsSceneContext').new(game,{bindings=bindings,
    textIR=game.data.constants.gen3RsItemPc.textIR})
  self.load,self.canvas=context.load,context.canvas
  local text=self.load('src.core.game3.rom_text')
  text.key=function(name,index)return name..':'..index end
  self.ui=self.load('src.ui.game3.rse.player_pc')
  self.pc={_session=self.session,close=function()self:close()end}
  self.ui.enter(self.pc,{bedroom=opts.order~='player'})
  return self
end
function M:close()
  if self.closed then return end
  self.closed=true;assert(self.game.stack:top()==self);self.game.stack:pop()
  local done=self.opts.onDone;self.opts.onDone=nil;if done then done()end
end
function M:pushStorage(ui)
  assert(not self.child)
  local owner=self;local screen={screenId='Gen3RsItemStorage',isOpaque=false,holdsUIAnchors=true,
    ui=ui,owner=self,uiSize=M.uiSize,wantsFillScale=M.wantsFillScale,wantsEdgeBleed=M.wantsEdgeBleed,
    sgbPalettes=M.sgbPalettes}
  function screen:update()
    local before=ui.state
    ui.update();ui.handleInput(owner.game.input)
    if self.closed then return end
    if before~='remove'and ui.state=='remove'and ui._toss then
      local row=owner.tx.store.items[ui.scroll+ui.row+1]
      assert(row and owner.tx:toss(row.id,ui.quantity),'Stale native PC toss')
    elseif before=='remove'and ui.state=='list'then
      assert(owner.tx:refresh())
    elseif before=='swap'and ui.state=='list'then
      assert(owner.tx:reorder(),'Stale native PC reorder')
    end
  end
  function screen:draw()owner:render(function()ui.draw()end)end
  function screen:exit()
    self.closed=true
    if ui.open then ui.open=false;ui._onClose=nil end
    owner.child=nil
  end
  self.child=screen;self.game.stack:push(screen)
end
function M:popStorage()
  local screen=self.child;if not screen or screen.closed then return end
  assert(self.game.stack:top()==screen);self.game.stack:pop()
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update()if not self.closed then self.ui.handleInput(self.pc,self.game.input)end end
function M:render(draw)
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0);draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:draw()self:render(function()self.ui.draw(self.pc)end)end
function M:exit()
  self.closed=true
  if self.canvas then self.canvas:release()end
  self.canvas,self.load=nil,nil
end
return M
