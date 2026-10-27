-- Native RS storage controller in a private module/font/cache scope.
-- Host save tables and stable Pokemon references remain authoritative.
local M={};M.__index=M;M.screenId='Gen3RsStorage';M.holdsUIAnchors=true
function M.available(game)
  local v=require('src.core.GameVersion').get()
  local s=game and game.data and game.data.constants and game.data.constants.gen3RsStorage
  return (v=='ruby'or v=='sapphire')and type(s)=='table'and s.version==v and s.format==1
end
function M.new(game,opts,menu)
  opts=opts or {};assert(M.available(game))
  local self=setmetatable({game=game,opts=opts,menu=menu,index=1,isOpaque=not menu},M)
  local data=game.data;local spec=data.constants.gen3RsStorage
  local mapKit=require('src.ui.Gen3RsMapKit').new(game);local C=mapKit.constants
  local enums=require('compat.gen1-rs.Loader').new(spec.version)
  for _,family in ipairs({'species','moves'})do C[family]=enums('src.core.game3.constants.ruby.'..family)end
  local session
  if menu then session={party=game.save.party or {}}
  else self.transaction=require('src.pokemon.Gen3RsStorageTransaction').new(game);session=self.transaction.session end
  session.version=spec.version;session.playerName=(game.save.player or {}).name
  self.session=session
  local hostPokemon=require('src.pokemon.Pokemon');local Assets=require('src.render.Assets')
  local species,moves,items={},{},{}
  for key,def in pairs(data.pokemon)do species[def.index]={id=key,def=def}end
  for key,def in pairs(data.moves)do moves[def.index]={id=key,def=def}end
  for key,def in pairs(data.items)do items[def.index]={id=key,def=def}end
  local function raw(mon)return mon and (mon._host or mon)end
  local function speciesOf(mon)local r=raw(mon);return r and data.pokemon[r.species].index or 0 end
  local function isEgg(mon)local r=raw(mon);return r and(r.isEgg==true or r.egg==true)or false end
  local function name(mon)local r=raw(mon);return r.nickname or r.name or data.pokemon[r.species].name end
  local function moveIdAt(mon,slot)
    local m=raw(mon).moves and raw(mon).moves[slot];local id=type(m)=='table'and m.id or m
    return type(id)=='number'and id or id and data.moves[id]and data.moves[id].index or 0
  end
  local manifests={};local function manifest(sub)
    if not manifests[sub]then
      local f=assert(love.filesystem.load('data/generated/gba/'..sub..'/manifest.lua'));setfenv(f,{})
      manifests[sub]=f();assert(manifests[sub].game==spec.version)
    end
    return manifests[sub]
  end
  local quads={}
  local function icon(mon)
    local r=raw(mon);local index=speciesOf(mon);local path,height
    if isEgg(mon)then index=412
    elseif index==201 then
      local p=(tonumber(r.personality)or 0)%4294967296
      local function bits(s)return math.floor(p/2^s)%4 end
      local letter=(bits(24)*64+bits(16)*16+bits(8)*4+bits(0))%28
      if letter>0 then index=412+letter end
    end
    local img
    if index>=412 then
      path=assert(manifest('rse/party_extras').icons[index]);img=Assets.image(path);height=32
    else img,height=require('src.ui.Gen3PartyMenu').iconFor({game=game},r)end
    assert(img and img:getWidth()==32 and height==32,'Missing native RS storage 32x32 icon')
    if not quads[img]then local w,h=img:getDimensions();quads[img]={}
      for i=0,math.floor(h/32)-1 do quads[img][i]=love.graphics.newQuad(0,i*32,32,32,w,h)end
    end
    return {image=img,quads=quads[img]}
  end
  local function read(path)
    if path:find('pokenav__gPokenavConditionMenuMisc_Gfx.rom',1,true)then return love.filesystem.read(manifest('rse/pokenav_markings').tiles)end
    if path:find('unknown__gUnknown_08E966B8.rom',1,true)then return love.filesystem.read(manifest('rse/pokenav_markings').palette)end
    return love.filesystem.read(path)
  end
  local bindings={
    ['src.render.Assets']={image=function(path)
      local at=path:find('data/generated/gba/',1,true);if at then path=path:sub(at)end
      assert(Assets.exists(path),'Missing native RS storage texture '..path);return Assets.image(path)
    end},
    ['src.core.Strings']=require('src.core.Strings'),
    ['src.core.game3.display']={W=240,H=160,TILE=8,COLS=30,ROWS=20},
    ['src.core.game3.constants']={of=function()return C end},
    ['src.core.game3.scripting.flags']={
      getFlag=function(_,_,id)return mapKit.session.flags[id]end,
      getVar=function(_,_,id)return mapKit.session.vars[id]end,
      setFlag=function()error('RS storage unexpectedly requested a flag write')end,
      setVar=function()error('RS storage unexpectedly requested a variable write')end},
    ['src.core.game3.dataset']={cache=function()return {read=function(_,path)return read(path)end}end},
    ['src.core.game3.items_data']={displayName=function(id)return assert(items[id]).def.name end},
    ['src.core.game3.bag']={}, -- RS storage has no MOVE ITEMS action.
    ['src.core.game3.quest_log_recorder']={event=function()end}, -- No FRLG quest log in RS.
    ['src.core.game3.mail']={isMailItem=function(id)
      local row=items[tonumber(id)];return row and tostring(row.id):match('_MAIL$')~=nil or false
    end},
    ['src.core.game3.pokemon']={speciesOf=speciesOf,speciesOrEgg=function(mon)return isEgg(mon)and 412 or speciesOf(mon)end,
      isEgg=isEgg,displayMonName=name,displayName=name,name=function(id)return assert(species[id]).def.name end,
      monIcon=icon,moveIdAt=moveIdAt,movePp=function(id)return assert(moves[id]).def.pp end,
      knowsMove=function(mon,id)for i=1,4 do if moveIdAt(mon,i)==id then return true end end;return false end,
      gender=function(id,pid)
        local g=hostPokemon.genderOf(data,{species=assert(species[id]).id,personality=pid})
        return g=='male'and 'M'or g=='female'and 'F'or 'U'
      end,
      monFrontPic=function(mon)
        local r=raw(mon);local path=isEgg(mon)and manifest('rse/summary_extras').egg
          or require('src.pokemon.Sprites').path(data,r.species,'front',{mon=r,kind='box'})
        return path and {image=Assets.image(path)}or nil
      end},
    ['src.ui.game3.summary_menu']={openMenu=function(mons,index,options)
      local list,indices,at={},{},1
      for i=1,options.context=='box'and 30 or 6 do if mons[i]then
        list[#list+1]=raw(mons[i]);indices[#list]=i;if i==index then at=#list end
      end end
      local screen
      screen=require('src.ui.Gen3SummaryMenu').new(game,{mon=list[at],party=list,partyIndex=at,
        onCancel=function()options.onClose(indices[screen.partyIndex or at])end})
      game.stack:push(screen)
    end},
    ['src.ui.game3.stack']={push=function(id,scene)
      if id=='naming'then self.naming=scene end
    end,pop=function(id)if id=='naming'then self.naming=nil end end},
    ['src.ui.game3.fade']={clear=function()end},
  }
  local context=require('src.ui.Gen3RsSceneContext').new(game,{bindings=bindings,textIR=spec.textIR,
    packageLoaded={['src.core.game3.scripting.space']=false}})
  self.load,self.canvas=context.load,context.canvas
  local profile=self.load('src.core.game3.profile').forSession(session)
  profile.save={storage={pcOwnerFlag='FLAG_SYS_PC_LANETTE'}};profile.bag={pcItems=50}
  self.policy=self.load('src.ui.game3.rs.storage_policy');self.window=self.load('src.ui.game3.window')
  if menu then self.rows=self.policy.options()
  else
    local release=self.load('src.ui.game3.release_seq');local start=release.start
    release.start=function(options)
      local callback=options.onComplete
      options.onComplete=function(released)
        if released and not release.returns then self.transaction:confirmRelease(options.mon)end
        if callback then callback(released)end
      end
      return start(options)
    end
    self.scene=self.load('src.ui.game3.box_storage_ui')
    self.scene.show({session=session,subMode=opts.mode or 'move',onClose=function()
      self.transaction:commit();game.stack:pop();if opts.onCancel then opts.onCancel()end
    end})
  end
  return self
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return {require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:closeMenu()
  if self.closed then return end
  self.game.stack:pop()
  if self.opts.onCancel then self.opts.onCancel()end
  if self.opts.onDone then self.opts.onDone()end
end
function M:update(dt)
  if self.closed then return end
  local input=self.game.input
  if self.menu then
    if input:wasPressed('a')and not self.message then self.load('src.core.game3.audio').playSe(5)end
    if input:wasPressed('up')or input:wasPressed('down')then
      self.index=(self.index+(input:wasPressed('up')and -2 or 0))%4+1;self.message=nil
      self.load('src.core.game3.audio').playSe(5)
    elseif self.message then
      if input:wasPressed('a')or input:wasPressed('b')then self.message=nil end
    elseif input:wasPressed('b')or input:wasPressed('a')and self.index==4 then self:closeMenu()
    elseif input:wasPressed('a')then
      local size=#(self.game.save.party or {})
      if self.index==1 and size>=6 then self.message='gPCText_PartyFull2'
      elseif self.index==2 and size<=1 then self.message='gPCText_OnlyOne'
      else require('src.ui.Screens').push(self.game,'BoxMenu',{mode=self.rows[self.index].id})end
    end
  elseif self.naming then
    local scene=self.naming;scene.handleInput(input);if self.naming==scene then scene.update(dt or 1/60)end
  else self.scene.handleInput(input);if not self.closed then self.scene.update(dt or 1/60)end end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
    if self.menu then
      local W=self.window;W.stdFrame(W.template(1,1,12,8))
      for i,row in ipairs(self.rows)do W.printPx(row.label,8,8+(i-1)*16)end
      self.load('src.ui.game3.rs.menu_cursor').draw(8,8+(self.index-1)*16,96);W.dialogueFrame()
      local text=self.message and self.load('src.core.game3.rom_text').plain(self.message)or self.rows[self.index].desc
      W.printPx(text,16,120,{maxWidth=208})
    elseif self.naming then self.naming.draw()else self.scene.draw()end
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  self.closed=true
  if self.naming then self.naming.dismiss()end
  if self.scene then self.scene.reset()end
  if self.canvas then self.canvas:release()end
  self.scene,self.load,self.canvas=nil,nil,nil
end
return M
