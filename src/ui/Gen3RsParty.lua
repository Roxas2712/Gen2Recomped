-- Native RS party presentation/policy with authoritative host callbacks.
local Loader=require('compat.gen1-rs.Loader')
local Assets=require('src.render.Assets')
local Font=require('src.render.Font')
local Pokemon=require('src.pokemon.Pokemon')
local M={};M.__index=M
function M.available(game)
  local v=require('src.core.GameVersion').get()
  local s=game and game.data and game.data.constants and game.data.constants.gen3RsParty
  return (v=='ruby' or v=='sapphire') and type(s)=='table' and s.format==1 and s.version==v
end
local function rgb(w)return w%32/31,math.floor(w/32)%32/31,math.floor(w/1024)%32/31 end
local function drawText(value,x,y,opts)
  opts=opts or {};local colors=assert(opts.colors)
  Font.pushStyle({text=colors.fg,shadow=colors.shadow})
  local ok,why=pcall(function()
    for line in (tostring(value or '')..'\n'):gmatch('(.-)\n')do
      local width=0
      for _,code in ipairs(Font.encode(line))do
        local advance=Font.advanceOf(code)
        if width+advance<=(opts.maxWidth or 240) or width==0 then Font.drawCode(code,x+width,y);width=width+advance end
      end
      y=y+(opts.linePitch or 16)
    end
  end)
  Font.popStyle();if not ok then error(why,0)end
end
function M.new(host)
  local self=setmetatable({host=host,manifests={},images={},quads={},views=setmetatable({},{__mode='k'})},M)
  local game,data=host.game,host.game.data
  local spec=assert(data.constants.gen3RsParty)
  local function isMail(id)
    local row=(data.items or {})[id];local number=tonumber(id)or row and row.index
    return number and number>=121 and number<=132 or false -- native RS ITEM_ORANGE_MAIL..RETRO_MAIL
  end
  local species,moves={},{},{}
  for id,def in pairs(data.pokemon or {})do if def.index then species[def.index]={id=id,def=def}end end
  for id,def in pairs(data.moves or {})do if def.index then moves[def.index]={id=id,def=def}end end
  local function manifest(sub)
    if not self.manifests[sub]then
      local chunk=assert(love.filesystem.load('data/generated/gba/'..sub..'/manifest.lua'))
      setfenv(chunk,{});local man=chunk()
      assert(man.game==spec.version and man.layout=='rs','Mixed native RS party cache')
      self.manifests[sub]=man
    end
    return self.manifests[sub]
  end
  local function image(path)assert(Assets.exists(path),'Missing native RS party image '..tostring(path));return Assets.image(path)end
  local function font4()
    if self.font4 then return self.font4 end
    local spec=assert(manifest('rse/party_extras').font4,'Native RS font 4 missing')
    local f={widths=spec.widths,quads={}}
    for _,key in ipairs({'fg','shadow','fixed'})do
      local bytes=assert(love.filesystem.read(Assets.resolve(spec[key])))
      assert(#bytes==spec.w*spec.h*4,'Native RS font layer dimensions')
      f[key]=love.graphics.newImage(love.image.newImageData(spec.w,spec.h,'rgba8',bytes));f[key]:setFilter('nearest','nearest')
    end
    for code=0,spec.count-1 do
      f.quads[code]=love.graphics.newQuad(code%16*16,math.floor(code/16)*16,math.min(spec.widths[code],8),16,spec.w,spec.h)
    end
    self.font4=f;return f
  end
  local function measure(str,opts)
    if not(opts and opts.font=='native_4')then return Font.width(str)end
    local f=font4();local maximum=0
    for line in (tostring(str or '')..'\n'):gmatch('(.-)\n')do
      local n=0;for _,code in ipairs(Font.encode(line))do n=n+(f.widths[code]or 0)end;maximum=math.max(maximum,n)
    end
    return maximum
  end
  local function fontDraw(str,x,y,opts)
    if not(opts and opts.font=='native_4')then return drawText(str,x,y,opts)end
    local f=font4();local colors=assert(opts.colors)
    local maxWidth=self:labelWidth(x,y,opts.maxWidth or 240)
    for line in (tostring(str or '')..'\n'):gmatch('(.-)\n')do
      local pen=0
      for _,code in ipairs(Font.encode(line))do
        local q=f.quads[code];local width=f.widths[code]or 0
        if q and pen+width<=maxWidth then
          if colors.shadow then love.graphics.setColor(colors.shadow);love.graphics.draw(f.shadow,q,x+pen,y)end
          love.graphics.setColor(colors.fg);love.graphics.draw(f.fg,q,x+pen,y)
          love.graphics.setColor(1,1,1,1);love.graphics.draw(f.fixed,q,x+pen,y)
        end
        pen=pen+width
      end
      y=y+(opts.linePitch or 16)
    end
  end
  -- The native party message is a separate 22x4 window at (4,15), using
  -- font 4. Keep TextBox's input/callback state and render its revealed codes
  -- through the same ROM font layers as the party's own prompt.
  self.machineWidths=function()return font4().widths end
  self.machineCodes=function(codes,x,y,opts)
    local f=font4();local colors=opts.colors;local pen=0
    for _,code in ipairs(codes)do
      local q=f.quads[code];local width=f.widths[code]or 0
      if q and pen+width<=176 then
        if colors.shadow then love.graphics.setColor(colors.shadow);love.graphics.draw(f.shadow,q,x+pen,y)end
        love.graphics.setColor(colors.fg);love.graphics.draw(f.fg,q,x+pen,y)
        love.graphics.setColor(1,1,1,1);love.graphics.draw(f.fixed,q,x+pen,y)
      end
      pen=pen+width
    end
  end
  local function text(key,opts)
    local id=tostring(key):match('^PartyMenuPromptTexts:(%d+)$')
    local value=id and manifest('rse/party').prompts[tonumber(id)+1] or spec.text[key]
    value=assert(value,'Missing native RS party text '..tostring(key))
    local vars=opts and opts.stringVars
    if vars then value=value:gsub('{VAR(%d)}',function(i)return tostring(vars[tonumber(i)] or '')end)end
    return value
  end
  local function frame(tx,ty,tw,th)
    local frames=manifest('rse/bag_chrome').frames
    local n=math.max(1,math.min(#frames,math.floor(tonumber((game.save.options or {}).gen3Frame) or 1)))
    local img=image(frames[n]);local q=self.frameQuads
    if not q then q={};self.frameQuads=q;local w,h=img:getDimensions()
      for i=0,8 do q[i]=love.graphics.newQuad(i%3*8,math.floor(i/3)*8,8,8,w,h)end
    end
    love.graphics.setColor(1,1,1,1);love.graphics.rectangle('fill',tx*8,ty*8,tw*8,th*8)
    for row=-1,th do for col=-1,tw do
      local tile
      if row==-1 then tile=col==-1 and 0 or col==tw and 2 or 1
      elseif row==th then tile=col==-1 and 6 or col==tw and 8 or 7
      elseif col==-1 then tile=3 elseif col==tw then tile=5 end
      if tile then love.graphics.draw(img,q[tile],(tx+col)*8,(ty+row)*8)end
    end end
  end
  local function view(raw)
    local v=self.views[raw] or {};self.views[raw]=v
    for k in pairs(v)do v[k]=nil end;for k,x in pairs(raw)do v[k]=x end
    v._host=raw;v.maxHp=raw.maxHp or raw.maxHP or raw.stats and raw.stats.hp or 1
    v.isEgg=raw.isEgg==true or raw.egg==true
    v.status=raw.status or raw.statusWord;v.pokerus=raw.pokerus or raw.gen3Pokerus
    v.item=raw.item or raw.heldItem
    local g=Pokemon.genderOf(data,raw);v.gender=g=='male' and 'M' or g=='female' and 'F' or ''
    return v
  end
  self.view=view
  local function icon(v)
    local raw=v._host;local index=data.pokemon[raw.species].index
    if v.isEgg then index=412
    elseif index==201 then
      local p=(tonumber(raw.personality) or 0)%4294967296
      local function bits(s)return math.floor(p/2^s)%4 end
      local letter=(bits(24)*64+bits(16)*16+bits(8)*4+bits(0))%28
      if letter>0 then index=412+letter end
    end
    local img,height
    if index>=412 then
      local path=assert(manifest('rse/party_extras').icons[index])
      path=require('src.pokemon.Sprites').iconPath(data,raw,path,{kind='party'}) or path
      img,height=image(path),32
    else img,height=host:iconFor(raw)end
    assert(img,'Missing native RS Pokemon icon '..tostring(raw.species))
    local q=self.quads[img]
    if not q then local w,h=img:getDimensions();q={};self.quads[img]=q
      for i=0,math.floor(h/height)-1 do q[i]=love.graphics.newQuad(0,i*height,w,height,w,h)end
    end
    return {image=img,quads=q,w=img:getWidth(),h=height}
  end
  -- The authored party message uses native word wrapping as well as its
  -- native face. Reuse that algorithm with this adapter's exact ROM metrics.
  local fontPolicy=Loader.new(spec.version,{
    ['src.ui.game3.font_mods']={},['src.import.CacheBlob']={},
  })('src.ui.game3.frlg_font')
  fontPolicy.measure=measure
  self.load=Loader.new(spec.version,{
    ['src.core.Strings']=require('src.core.Strings'),
    ['src.ui.game3.rse.scene_kit']={manifest=manifest,image=image,rgb555=rgb,drawFade=function(pal)
      local s=pal.slots[0]
      if s and s.y>0 then love.graphics.setColor(s.color[1]/31,s.color[2]/31,s.color[3]/31,s.y/16);love.graphics.rectangle('fill',0,0,240,160)end
    end},
    ['src.ui.game3.frlg_font']={draw=fontDraw,measure=measure,wrap=fontPolicy.wrap},
    ['src.ui.game3.chrome']={stdFrame=frame},
    ['src.core.game3.rom_text']={plain=text,box=text,has=function(key)return spec.text[key]~=nil or tostring(key):match('^PartyMenuPromptTexts:%d+$')~=nil end,
      key=function(key,id)return key..':'..id end},
    ['src.core.game3.pokemon']={isEgg=function(v)return v.isEgg==true end,displayName=function(v)
      return v.isEgg and data.constants.gen3RsSummary.eggName or v.nickname or data.pokemon[v.species].name end,
      speciesOf=function(v)return data.pokemon[v.species].index end,
      name=function(id)return assert(species[id]).def.name end,monIcon=icon,
      moveName=function(id)return assert(moves[id]).def.name end},
    ['src.core.game3.field_moves']={normalizeMoveId=function(slot)
      local id=type(slot)=='table' and slot.id or slot;return tonumber(id) or id and data.moves[id] and data.moves[id].index
    end},
    ['src.core.game3.items_data']={toNumericId=function(id)return tonumber(id) or id and data.items[id] and data.items[id].index end,
      isTm=function()return host.tmhm~=nil and host.tmhm.kind~='TUTOR' end},
    ['src.core.game3.mail']={isMailItem=isMail},
    ['src.core.game3.gba_fx']={active=function(fx)return fx and fx.y>0 end,draw=function(fn)fn()end},
    ['src.ui.LevelDisplay']={visible=function(v,where)return require('src.ui.LevelDisplay').visible(v._host or v,where,game)end},
  })
  self.chrome=self.load('src.ui.game3.rs.party_chrome')
  self.policy=self.load('src.ui.game3.rs.party_menu_data')
  host.words={spec.text.OtherText_Shift,spec.text.OtherText_SendOut,spec.text.OtherText_Switch2,
    spec.text.OtherText_Summary,'',spec.text.OtherText_Enter2,spec.text.OtherText_NoEntry,
    spec.text.OtherText_Take2,spec.text.OtherText_Read2}
  local labels=manifest('rse/menus').party.cursorOptions
  self.fields={index={},byMove={},moves={}}
  local fieldMoves=manifest('rse/menus').party.fieldMoves
  for i,id in ipairs(fieldMoves)do
    local label=labels[#labels-#fieldMoves+i]
    self.fields.index[label]=i-1;self.fields.byMove[id]=label;self.fields.moves[i]=id
  end
  self.ui={_session={game=game},heldItemFrame=function(v)
    local id=v.item;if not id or id==0 then return nil end
    return isMail(id) and 1 or 0
  end,slotDescription=function(i)return self:description(i)end,
    _actionTextsFor=function(rows)local out={};for i,row in ipairs(rows)do out[i]=row.label end;return out end}
  self.chrome.install();self:sync()
  return self
end
function M:sync()
  local h,ui=self.host,self.ui
  ui._party={};for i,raw in pairs(h:party())do ui._party[i]=self.view(raw)end
  ui.cursor=h.index>#h:party() and (h.chooseOrder and h.index-#h:party()+6 or 7) or h.index;ui.switchFrom=h.switchFrom
  ui._nativeLayout=h.rsLayout or 0;ui._layout=ui._nativeLayout==1 and 'double' or 'single'
  ui._hpAnim=nil
  if h.heal then
    for i,raw in ipairs(h:party())do if raw==h.heal.mon then ui._hpAnim={slot=i,current=h.heal.shown}end end
  end
  ui.mode=h.switchFrom and 'switch' or h.tmhm and (h.tmhm.kind=='TUTOR' and 'move_tutor' or 'use')
    or h.hpTransferFrom and 'use' or h.rsMailGive and'give'or'list'
  ui.ACTIONS=h.submenu;ui.ITEM_ACTIONS=h.submenu
  ui.actionCursor=h.subIndex;ui.itemActionCursor=h.subIndex;ui._submenuKind=self.mailSubmenu and'MAIL'or'ITEM'
end
function M:description(i)
  local h=self.host;local mon=h:party()[i];if not mon then return nil end
  local key
  if h.chooseOrder then key=not self:eligible(i) and 'NOT_ABLE' or ({'FIRST','SECOND','THIRD'})[h:orderOf(i)] or 'ABLE_3'
  elseif h.tmhm then
    key='NOT_ABLE_2'
    if not (mon.isEgg or mon.egg) then
      if h:canLearn(mon)then key='ABLE_2'end
      for _,slot in ipairs(mon.moves or {})do if slot.id==h.tmhm.move then key='LEARNED'end end
    end
  end
  return key and self.policy.description(key) or nil
end
function M:eligible(slot)
  local mon=self.host:party()[slot]
  if not mon or mon.isEgg or mon.egg or (tonumber(mon.hp)or 0)<=0 then return false end
  local rule=self.host.rsEligibility
  if type(rule)=='function'then return rule(slot,mon) and true or false end
  if type(rule)=='table'then
    for _,index in ipairs(rule)do if tonumber(index)and tonumber(index)+1==slot then return true end end
    return false
  end
  return true
end
function M:labelWidth(x,y,width)
  local m=self.manifests['rse/party'];local ui=self.ui
  if not(m and m.textSettings and m.coordinates and ui)then return width end
  local layout=ui._nativeLayout or 0
  for slot in pairs(ui._party)do
    if self:description(slot)then
      local text=m.textSettings[layout+1][slot];local name=text.oam[1]
      if x==text.x+name[2]%512 and y==text.y+name[1]%256 then
        local point=m.coordinates.descriptors[layout==0 and 1 or 2][slot]
        local dx,dy=point[1]*8,point[2]*8
        -- The reference's generic 64px name clip overlaps native descriptors
        -- on long nicknames. Limit only that temporary run to its ROM field.
        if dx>x and dy<y+16 and dy+16>y then width=math.min(width,dx-x)end
      end
    end
  end
  return width
end
function M:actionLabel(key)
  local keys={summary='SUMMARY',switch='SWITCH',item='ITEM',mail='MAIL',cancel='CANCEL',give='GIVE',takeItem='TAKE'}
  local name=keys[key];if name then return self.policy.actionText(name,self.fields)end
end
function M:fieldActions(mon)
  local party={};for i,raw in ipairs(self.host:party())do party[i]=self.view(raw)end
  local actions=self.policy.buildActions(self.view(mon),party,self.fields)
  local keys={SUMMARY='summary',SWITCH='switchOrder',ITEM='item',MAIL='mail',CANCEL='cancel'}
  local rows={}
  for _,action in ipairs(actions)do
    local move=self.fields.index[action];local native=move and self.fields.moves[move+1]
    local id=native and self.host.game.data.moves
    if id then for k,d in pairs(id)do if d.index==native then id=k;break end end end
    rows[#rows+1]={action=keys[action] or 'field',label=self.policy.actionText(action,self.fields),move=id}
  end
  local Runtime=require('src.mods.Runtime')
  local hooked=Runtime.call('ui.party.submenu',function(_,v)return v end,self.host.game,rows,mon,
    {battle=self.host.battle,overworld=self.host.game.overworld})
  return type(hooked)=='table' and hooked or rows
end
function M:beforeAction(action)
  if action=='item'or action=='mail'then
    self.parentRows,self.parentIndex=self.host.submenu,self.host.subIndex;self.itemSubmenu=true
    self.mailSubmenu=action=='mail'
  elseif action=='cancel' and self.itemSubmenu then
    self.restoreParent=true
  else self.itemSubmenu=false;self.mailSubmenu=false end
end
function M:update()
  self:sync();self.chrome.update(self.ui)
end
function M:input()
  local h=self.host;local input=h.game.input
  if not self.chrome.inputAllowed()then return true end
  if h.heal or h.script or h.noInput then return false end
  if h.submenu then
    if #h.submenu==0 then h.submenu=nil;self.itemSubmenu=false;return true end
    local nextIndex=h.subIndex
    if self.itemSubmenu then
      local kind=self.mailSubmenu and'MAIL'or'ITEM'
      local dir=self.policy.submenuDirection(input,kind)
      if dir then nextIndex=self.policy.submenuStep(nextIndex,dir,#h.submenu,kind)end
    elseif input:wasPressed('up')then nextIndex=(nextIndex-2)%#h.submenu+1
    elseif input:wasPressed('down')then nextIndex=nextIndex%#h.submenu+1 end
    if nextIndex~=h.subIndex or input:wasPressed('a')or input:wasPressed('b')then require('src.core.Sound').play(h.game.data,'SE_SELECT')end
    h.subIndex=nextIndex
    if not self.itemSubmenu and (input:wasPressed('up')or input:wasPressed('down'))then return true end
    if input:wasPressed('a')then
      local row=h.submenu[h.subIndex];h:runAction(row.action,h:party()[h.index],row)
      if self.restoreParent then h.submenu=self.parentRows;h.subIndex=self.parentIndex;self.restoreParent=nil;self.itemSubmenu=false;self.mailSubmenu=false end
    elseif input:wasPressed('b')then
      if self.itemSubmenu then h.submenu=self.parentRows;h.subIndex=self.parentIndex;self.itemSubmenu=false;self.mailSubmenu=false
      else h.submenu=nil end
    end
    return true
  end
  if h:gridNavigation()then return false end
  local n=#h:party();local cur=h.index>n and (h.chooseOrder and h.index-n+6 or 7) or h.index
  if n==0 then
    h.index=1
    if input:wasPressed('a')or input:wasPressed('b')or input:wasPressed('start')then h:close()end
    return true
  end
  if h.chooseOrder then
    if input:wasPressed('up')then cur=cur==1 and 8 or cur==8 and 7 or cur==7 and n or cur-1
    elseif input:wasPressed('down')then cur=cur==7 and 8 or cur==8 and 1 or cur==n and 7 or cur+1
    elseif input:wasPressed('left')and cur>1 and cur<7 then h.lastSelectedSlot=cur;cur=1
    elseif input:wasPressed('right')and cur==1 and n>1 then cur=math.max(2,math.min(n,h.lastSelectedSlot or 2))
    elseif input:wasPressed('start')then cur=7 end
  elseif self.ui._nativeLayout==1 then
    if input:wasPressed('up')then cur=cur==1 and 7 or cur==7 and n or cur-1
    elseif input:wasPressed('down')then cur=cur==7 and 1 or cur==n and 7 or cur+1
    elseif input:wasPressed('right')then
      local want=cur==1 and (h.lastSelectedSlot==4 and 4 or 3) or cur==2 and (h.lastSelectedSlot==6 and 6 or 5)
      if want and h:party()[want]then cur=want end
    elseif input:wasPressed('left')then
      if cur==3 or cur==4 then h.lastSelectedSlot=cur;cur=1
      elseif cur==5 or cur==6 then h.lastSelectedSlot=cur;cur=2 end
    end
  elseif input:wasPressed('up')then cur=cur==1 and 7 or cur==7 and n or cur-1
  elseif input:wasPressed('down')then cur=cur==7 and 1 or cur==n and 7 or cur+1
  elseif input:wasPressed('left')and cur~=1 and cur~=7 then h.lastSelectedSlot=cur;cur=1
  elseif input:wasPressed('right')and cur==1 and n>1 then cur=math.max(2,math.min(n,h.lastSelectedSlot or 2))end
  local nextIndex=cur>=7 and (h.chooseOrder and n+cur-6 or n+1) or cur
  if nextIndex~=h.index or input:wasPressed('a')or input:wasPressed('b')or input:wasPressed('start')then require('src.core.Sound').play(h.game.data,'SE_SELECT')end
  h.index=nextIndex
  if h.chooseOrder and input:wasPressed('a')and cur==8 then h:handOrder(nil)
  elseif input:wasPressed('a')and h.switchFrom and nextIndex>n then h.switchFrom=nil
  elseif input:wasPressed('a')then h:confirm()
  elseif input:wasPressed('b')or (not h.chooseOrder and input:wasPressed('start'))then h:cancel()end
  return true
end
function M:draw()
  self:sync();love.graphics.push('all')
  local ok,why=pcall(function()
    self.chrome.drawParty(self.ui)
    local message=false
    for _,state in ipairs(self.host.game.stack.states)do
      if state.rsMachineParty==self.host then message=true;break end
    end
    if self.host.rsMailPrompt then self.policy.drawMessage(self.host.rsMailPrompt)
    elseif not message then
      if self.host.chooseOrder then
        self.chrome.drawConfirmButton(nil,nil,self.ui.cursor==7)
        self.chrome.drawCancelButton(nil,nil,self.ui.cursor==8)
      else self.chrome.drawCancelButton(nil,nil,self.ui.cursor==7)end
      if self.host.submenu and #self.host.submenu>0 then self.policy.drawActions(self.ui,self.itemSubmenu)
      else self.policy.drawPrompt(self.ui)end
    end
    self.chrome.drawFade()
  end)
  love.graphics.pop();if not ok then error(why,0)end
end
function M:machinePages(pages)
  local widths=self.machineWidths();local result={contBefore={}}
  for p,lines in ipairs(pages)do
    local out,conts={},{}
    for i,line in ipairs(lines)do
      local wait=pages.contBefore and pages.contBefore[p]and pages.contBefore[p][i]or false
      while true do
        local spans=Font.split(line);local used,fit=0,0
        for n,span in ipairs(spans)do
          used=used+(widths[span.code]or 0);if used>176 then break end;fit=n
        end
        if fit>=#spans then out[#out+1]=line;conts[#out]=wait;break end
        fit=math.max(1,fit);local cut=spans[fit].to
        for n=fit,1,-1 do
          if line:sub(spans[n].from,spans[n].to)==' 'then cut=spans[n].to;break end
        end
        out[#out+1]=line:sub(1,cut);conts[#out]=wait;wait=false;line=line:sub(cut+1)
      end
    end
    result[p],result.contBefore[p]=out,conts
  end
  return result
end
function M:drawMachineMessage(box)
  love.graphics.push('all')
  local ok,why=pcall(function()
    local renderer=self.host.game.renderer
    if renderer and renderer.setUIAnchor then renderer:setUIAnchor(24,112,192,48,'bottom')end
    self.policy.drawMessage(nil)
    if box.scrollPx and box.scrollPx>0 then
      box.scrollPx=box.scrollPx-(box.scrollStep or 2)
      if box.scrollPx<=0 then box.scrollPx=nil end
    end
    local off=box.scrollPx or 0
    local opts=self.chrome.textOptions('menu')
    love.graphics.setScissor(32,120,176,32)
    for i,codes in ipairs(box.shown)do
      self.machineCodes(codes,32,120+(i-1)*16+(i==1 and off or 0),opts)
    end
  end)
  love.graphics.pop();if not ok then error(why,0)end
end
return M
