local function L(value) return require('src.translation.Service').launcherLookup(value) end
-- Native-resolution Bank workspace. Dragging stages copies; only Save copy
-- writes a new target slot. Neither source files nor occupied cells are replaced.
local W={}
local B=require('src.storage.PokemonBank')
local Saves=require('src.core.SaveData')
local Versions=require('src.core.GameVersion')
local Serializer=require('src.core.SaveSerializer')
local Auth=require('src.cloud.RetroCloud')
local Storage=require('src.storage.AccountStorage')
local function registered() if Storage.enabled then return Storage.check() end;return Auth.signedIn() end
local ACCOUNT_REQUIRED='Register and confirm your email to use the Pokémon Bank, Item Bank and global Pokédex.'
local function clone(t) return Serializer.decode(Serializer.encode(t)) end
local function inside(r,x,y) return r and x>=r.x and y>=r.y and x<=r.x+r.width and y<=r.y+r.height end
function W.slots(self)
  local out={}
  for _,v in ipairs(Versions.ORDER) do
    if self.ready[v] then
      for _,slot in ipairs(Saves.listSlots(v)) do
        if slot.exists and not slot.unreadable then out[#out+1]={version=v,slot=slot.id,label=Versions.info(v).label..' / '..(slot.label or slot.name or slot.id)} end
      end
    end
  end
  return out
end
function W.open(self,mode)
  if not registered() then
    self:_openAccount(mode=='dex' and 'bankDex' or 'bank')
    if self._accountOverlay then self._accountOverlay.notice=ACCOUNT_REQUIRED end
    return false
  end
  -- Re-authentication keeps any staged save copies intact.
  local id=Storage.scope()
  self._bankOverlay=self._bankOverlay or self._profileBankDrafts and self._profileBankDrafts[id] or {bank=B.list(),left={box=0},right={box=1},page=1,slots=W.slots(self),sprites={},mode='bank',accountId=id}
  if mode then W.mode(self,mode) end
  return true
end
function W.mode(self,mode)
  local f=self._bankOverlay;if not f then return end
  if not registered() then f.notice=ACCOUNT_REQUIRED;return end
  f.mode=mode;f.modePage=0;f.tradeConsent=false;f.tradeFocus=nil;f.tradeChoose=nil
  f.subScroll=0;f.subMax=0
  if self._disarmTextInput then self:_disarmTextInput() end
  if mode=='items' then f.items,f.notice=require('src.storage.BankItems').list()
  elseif mode=='dex' then
    local dex,why=require('src.storage.GlobalPokedex').collect(self.ready,f.bank)
    if dex then f.dex=dex;f.dexRows,f.dexOwned=require('src.storage.GlobalPokedex').rows(dex)
    else f.notice=why end
  elseif mode=='trade' or mode=='wonder' then W.trade(self,'profile') end
end
function W.trade(self,action,exchange)
  local f=self._bankOverlay;if not f or f.tradeJob then return end
  if not require('src.cloud.RetroCloud').signedIn() then f.notice='Register and verify your account to use direct trade or Wonder Trade.';return end
  if self._storageTask or self._profileApplying then f.notice='Finish the current cloud or mod transfer first.';return end
  local client=require('src.cloud.BankExchange')
  if action=='submit' and (not f.tradeSelected or not f.tradeConsent) then f.notice='Choose a Bank copy and confirm what will be shared first.';return end
  local selected,mode,recipient,reply=f.tradeSelected,f.mode,f.recipient,f.replying
  f.tradeNext=os.time()+10
  f.tradeAction=action
  f.tradeJob=require('src.cloud.Task').new(function()
    if action=='profile' then return client.profile()
    elseif action=='submit' then return client.submit(selected,reply and 'reply' or mode=='wonder' and 'wonder' or 'direct',recipient,reply)
    elseif action=='receive' then return client.receive(exchange)
    else return client.change(exchange,action) end
  end)
  f.notice=f.tradeJob and 'Connecting to the Bank exchange service...' or 'Background networking is unavailable.'
end
function W.close(self)
  if self._bankOverlay and self._bankOverlay.bankCheckJob then self._bankOverlay.bankCheckJob:cancel()end
  local f=self._bankOverlay
  if f and f.tradeJob then f.tradeJob:cancel() end
  self._bankOverlay=nil
  if self._disarmTextInput then self:_disarmTextInput() end
end
function W.select(self,panel,choice)
  if not registered() then return nil,ACCOUNT_REQUIRED end
  local save,why=B.readSave(choice.version,choice.slot);if not save then return nil,why end
  local data,err=B.data(choice.version);if not data then return nil,err end
  local previous=panel.box or 1
  for k in pairs(panel) do panel[k]=nil end
  panel.version=choice.version;panel.slot=choice.slot;panel.label=choice.label;panel.save=save;panel.data=data;panel.box=previous
  return true
end
function W.place(self,payload,target,allow)
  if not registered() then return nil,ACCOUNT_REQUIRED end
  local f=self._bankOverlay
  if target.bank then
    local e=payload.entry
    local id,why
    if B.keep then id,why=B.keep(e) else id,why=B.deposit(e.mon,e.source.version,e.source.slot,e.source.place,payload.data or B.data(e.source.version)) end
    if not id then return nil,why end
    f.bank=B.list();f.notice='Copy kept in the Bank. Source unchanged.';return true
  end
  local panel=f[target.panel]
  if not panel or not panel.save then return nil,'Choose a target save first.' end
  if panel.box==0 then return nil,'Choose a PC box as the destination.' end
  panel.save.boxes=panel.save.boxes or clone(B.boxes(panel.save));panel.save.box=nil
  local box=panel.save.boxes[panel.box]
  if not box then box={};panel.save.boxes[panel.box]=box end
  if box.mons then box=box.mons end
  if box[target.slot] then return nil,'That cell is occupied. Choose an empty cell.' end
  local mon,why=B.convert(payload.entry,panel.version,panel.data,allow)
  if not mon then
    if not allow and why and why:find('adaptation',1,true) then f.adapt={payload=payload,target=target};return nil,why end
    return nil,why
  end
  box[target.slot]=mon;panel.dirty=true;f.adapt=nil
  f.notice=L('Copy staged. Save a new slot to keep it; originals stay intact.')..(why and (' '..why) or '')
  return true
end
function W.save(self,panelName)
  if not registered() then return nil,ACCOUNT_REQUIRED end
  local f=self._bankOverlay;local panel=f[panelName]
  local id,why=B.commitDraft(panel.version,panel.slot,panel.save)
  if not id then return nil,why end
  panel.slot=id;panel.label=Versions.info(panel.version).label..' / '..id;panel.dirty=nil
  f.slots=W.slots(self);self:_refreshSlots(panel.version);self._settingsCache=nil
  f.notice=L('Saved as ')..panel.label..'. The base save and Bank originals are unchanged.'
  return true
end
local function sprite(self,entry,data)
  local f=self._bankOverlay;local version=entry.source.version
  local k=version..':'..tostring(entry.mon.species)
  if f.sprites[k]~=nil then return f.sprites[k] or nil end
  data=data or B.data(version)
  local def=data and data.pokemon[entry.mon.species]
  local path=def and def.spriteFront
  if not path then f.sprites[k]=false;return end
  local Cache=require('src.import.CacheFs');local previous=Cache.prefix
  Cache.prefix=Versions.info(version).cachePrefix;local ok,bytes=pcall(Cache.read,path);Cache.prefix=previous
  if ok and bytes then
    local good,image=pcall(function() return love.graphics.newImage(love.filesystem.newFileData(bytes,path)) end)
    if good then image:setFilter('nearest','nearest');f.sprites[k]=image;return image end
  end
  f.sprites[k]=false
end
function W.draw(self)
  local f=self._bankOverlay;if not f then return end
  local g=love.graphics;local ww,hh=g.getDimensions()
  local portrait=ww<700 and hh>ww*1.1
  local s=portrait and 1 or math.max(.45,math.min(ww/1050,hh/720,1.2))
  local buttonH=portrait and 44 or 34*s
  local U=self._ui;local font=self.hintFont;local large=self.stateFont or font
  local x,y=16*s,22*s;local w,h=ww-32*s,hh-44*s
  f.rects={};f.cells={}
  local function col(r,b,c,a) g.setColor(r/255,b/255,c/255,a or 1) end
  local function text(value,tx,ty,width,big,ink)
    local fn=big and large or font;g.setFont(fn);if ink then col(ink[1],ink[2],ink[3]) else col(37,68,79) end
    g.print(U.ellipsize(fn,L(tostring(value)),width),tx,ty)
  end
  local function button(label,bx,by,bw,action,fields)
    local r=fields or {};r.x=bx;r.y=by;r.width=bw;r.height=buttonH;r.action=action;f.rects[#f.rects+1]=r
    col(34,113,132);g.rectangle('fill',bx,by,bw,r.height,6*s,6*s)
    text(label,bx+9*s,by+(r.height-font:getHeight())/2,bw-18*s,false,{244,252,250});return r
  end
  g.push('all');g.setCanvas();g.origin();g.setScissor();g.setShader();g.setBlendMode('alpha')
  col(4,12,22,.82);g.rectangle('fill',0,0,ww,hh)
  col(224,239,253);g.rectangle('fill',x,y,w,h,16*s,16*s)
  for i=0,15 do col(26+i,96+i*2,155+i*3);g.rectangle('fill',x,y+i*4*s,w,5*s) end
  col(41,145,201);g.rectangle('fill',x,y+62*s,w,3*s)
  text(portrait and 'POKÉMON BANK' or 'RETRORECOMPED · POKÉMON BANK',x+18*s,y+15*s,w-160*s,true,{245,255,252})
  button('CLOSE',x+w-110*s,y+15*s,92*s,'close')
  if not registered() then
    text('A VERIFIED ACCOUNT IS REQUIRED',x+24*s,y+100*s,w-48*s,true)
    text('Register or sign in and confirm your email. Existing records and staged copies are preserved.',x+24*s,y+144*s,w-48*s)
    button('REGISTER / SIGN IN',x+24*s,y+195*s,math.min(300*s,w-48*s),'bankLogin')
    g.pop();return
  end
  local tabCols=w<650*s and 3 or 6;local tabW=(w-36*s)/tabCols
  for i,mode in ipairs({{'bank','BANK BOXES'},{'items','ITEMS'},{'dex','POKÉDEX'},{'trade','LINK TRADE'},{'wonder','WONDER'},{'interop','LEGACY / LUA'}}) do
    local r=button(mode[2],x+18*s+((i-1)%tabCols)*tabW,y+77*s+math.floor((i-1)/tabCols)*(buttonH+8*s),tabW-7*s,'mode',{mode=mode[1]});r.pinned=true
  end
  local top=y+77*s+math.ceil(6/tabCols)*(buttonH+8*s)+6*s
  text(f.notice or (portrait and 'Select a Pokémon, switch Save / Bank, then tap an empty cell.' or 'Drag to copy between saves and the Bank. Save copy creates a new slot.'),x+18*s,top,w-36*s)
  top=top+34*s
  local Pages=require('src.import.BankPages')
  local pageView={x=x+18*s,y=top,width=w-36*s,height=math.max(60*s,h-(top-y)-18*s)}
  f.pageView=pageView
  if f.mode and f.mode~='bank' then
    local contentH=math.max(pageView.height,f.mode=='interop' and 1100*s or f.mode=='details' and 800*s or (f.mode=='trade' or f.mode=='wonder') and 660*s or 290*s)
    f.subMax=math.max(0,contentH-pageView.height);f.subScroll=math.min(f.subScroll or 0,f.subMax)
    g.setScissor(pageView.x,pageView.y,pageView.width,pageView.height)
    Pages.draw(self,f,pageView.x,pageView.y-f.subScroll,pageView.width,contentH,s,button,text,col)
    g.setScissor();Pages.animation(self,f,x+18*s,top,w-36*s,pageView.height,s)
    g.pop();return
  end
  local infoH=not portrait and hh>=520 and 132*s or 0
  local gap=12*s;local cw=(w-36*s-2*gap)/3;local ph=math.max(190*s,h-(top-y)-76*s-infoH)
  local panels={{name='left',title='GAME SAVE A'},{name='bank',title='YOUR BANK'},{name='right',title='GAME SAVE B'}}
  if portrait then
    local view=f.mobileView or 'bank';local viewW=(w-36*s)/3
    for i,row in ipairs({{'left','SAVE A'},{'bank','BANK'},{'right','SAVE B'}}) do
      button((row[1]==view and '● ' or '')..row[2],x+18*s+(i-1)*viewW,top,viewW-6*s,'mobileView',{view=row[1]})
    end
    top=top+buttonH+10*s
    panels={{name=view,title=view=='bank' and 'YOUR BANK' or view=='left' and 'GAME SAVE A' or 'GAME SAVE B'}}
    cw=w-36*s;ph=math.max(220,h-(top-y)-buttonH-40*s)
  elseif cw<230*s then
    panels={{name=f.mobilePanel or 'left',title='GAME SAVE'},{name='bank',title='BANK'}};cw=(w-36*s-gap)/2
  end
  local function monCell(entry,data,cx,cy,size,target)
    col(242,250,255,.96);g.rectangle('fill',cx,cy,size-4*s,size-4*s,7*s,7*s)
    col(129,178,218,.75);g.rectangle('line',cx,cy,size-4*s,size-4*s,7*s,7*s)
    col(152,198,228,.3);g.line(cx+size*.2,cy+size*.5,cx+size*.8,cy+size*.5)
    g.line(cx+size*.5,cy+size*.2,cx+size*.5,cy+size*.8)
    local r={x=cx,y=cy,width=size-4*s,height=size-4*s,target=target,entry=entry,data=data};f.cells[#f.cells+1]=r
    if entry then
      local image=sprite(self,entry,data)
      if image then
        local iw,ih=image:getDimensions();local edge=math.min(iw,ih);local scale=(size-14*s)/edge
        col(255,255,255);g.draw(image,g.newQuad(0,0,edge,edge,iw,ih),cx+(size-4*s-edge*scale)/2,cy+2*s,0,scale,scale)
      else text(tostring(entry.mon.species):sub(1,7),cx+3*s,cy+size*.3,size-10*s) end
      text(L('Lv.')..tostring(entry.mon.level or '?'),cx+4*s,cy+size-18*s,size-10*s,false,{62,100,104})
    end
  end
  for pi,kind in ipairs(panels) do
    local px=x+18*s+(pi-1)*(cw+gap)
    col(185,215,242);g.rectangle('fill',px,top,cw,ph,11*s,11*s)
    col(134,184,225,.55);g.rectangle('line',px+1,top+1,cw-2,ph-2,11*s,11*s)
    local compact=portrait and kind.name~='bank' and ph<310
    if not compact then text(kind.title,px+10*s,top+12*s,cw-20*s,true) end
    local gy=top+(compact and 12 or 48)*s
    local navW=portrait and 44 or 32*s;local navText=portrait and 64 or 50*s
    if kind.name=='bank' then
      local pages=math.max(1,math.ceil(#f.bank/30));f.page=math.max(1,math.min(pages,f.page))
      local gridTop=gy+buttonH+14*s
      local cols=portrait and ww<400 and 5 or 6
      local cell=(cw-20*s)/cols
      local available=ph-(gridTop-top)-30*s
      local perPage=portrait and (available<cell*math.ceil(30/cols) and cols*math.max(1,math.min(3,math.floor(available/cell))) or 30) or 30
      f.bankSlices=math.ceil(30/perPage);f.bankSlice=math.min(f.bankSlice or 0,f.bankSlices-1)
      button('<',px+10*s,gy,navW,'bankPage',{delta=-1})
      text(L('Box ')..f.page..' / '..pages..(f.bankSlices>1 and (' · '..(f.bankSlice+1)..'/'..f.bankSlices) or ''),px+navText,gy+8*s,cw-2*navText)
      button('>',px+cw-10*s-navW,gy,navW,'bankPage',{delta=1});gy=gridTop
      local size=math.min(cell,(ph-(gy-top)-30*s)/math.ceil(perPage/cols))
      local first=f.bankSlice*perPage+1
      for pos=first,math.min(30,first+perPage-1) do local entry=f.bank[(f.page-1)*30+pos];local n=pos-first
        monCell(entry,nil,px+10*s+(n%cols)*size,gy+math.floor(n/cols)*size,size,{bank=true}) end
      text(#f.bank..L(' Pokémon · originals preserved'),px+10*s,top+ph-24*s,cw-20*s)
    else
      local panel=f[kind.name]
      button(panel.label or 'CHOOSE SAVE',px+10*s,gy,cw-20*s,'choose',{panel=kind.name});gy=gy+(portrait and buttonH+8*s or 44*s)
      if panel.save then
        local count,capacity=B.shape(panel.version,panel.data)
        if panel.box>count then panel.box=1 end
        local cols=portrait and ww<400 and 5 or capacity==20 and 5 or 6
        local rows=panel.box==0 and 1 or math.ceil(capacity/cols)
        local firstGrid=gy+buttonH+10*s
        local cell=(cw-20*s)/cols
        local available=ph-(firstGrid-top)-buttonH-20*s
        local visibleRows=math.max(1,math.min(2,math.floor(available/cell)))
        local partyCompact=portrait and panel.box==0 and available<88
        local perPage=partyCompact and 3 or portrait and (available<cell*rows and cols*visibleRows or capacity) or capacity
        local slices=panel.box==0 and (partyCompact and 2 or 1) or math.ceil(capacity/perPage);panel.slice=math.min(panel.slice or 0,slices-1)
        button('<',px+10*s,gy,navW,'box',{panel=kind.name,delta=-1,slices=portrait and slices,perPage=perPage,partySlices=portrait and available<88 and 2 or 1})
        text((panel.box==0 and 'PARTY' or L('BOX ')..panel.box)..(slices>1 and (' · '..(panel.slice+1)..'/'..slices) or ''),px+navText,gy+8*s,cw-2*navText)
        button('>',px+cw-10*s-navW,gy,navW,'box',{panel=kind.name,delta=1,slices=portrait and slices,perPage=perPage,partySlices=portrait and available<88 and 2 or 1});gy=portrait and firstGrid or gy+44*s
        local box=panel.box==0 and panel.save.party or B.boxMons(B.boxes(panel.save)[panel.box])
        local size=math.min((cw-20*s)/cols,(ph-174*s)/math.max(4,rows))
        local n=panel.box==0 and 6 or capacity
        if portrait then size=math.min(cell,(ph-(gy-top)-buttonH-20*s)/math.ceil(perPage/cols)) end
        if panel.box==0 then
          cols=3;rows=partyCompact and 1 or 2
          size=math.min((cw-20*s)/cols,(ph-(gy-top)-buttonH-20*s)/rows)
        end
        local first=portrait and panel.slice*perPage+1 or 1
        for pos=first,math.min(n,first+perPage-1) do
          local mon=box and box[pos]
          local entry=mon and B.makeEntry(mon,panel.version,panel.slot,panel.box==0 and ('Party '..pos) or (L('Box ')..panel.box..' / '..pos),panel.data,panel.save)
          monCell(entry,panel.data,px+10*s+((pos-first)%cols)*size,gy+math.floor((pos-first)/cols)*size,size,{panel=kind.name,slot=pos})
        end
        if panel.dirty then button('SAVE AS NEW SLOT',px+10*s,top+ph-buttonH-8*s,cw-20*s,'save',{panel=kind.name}) end
      else
        text('Choose a save to show its boxes.',px+10*s,gy+14*s,cw-20*s)
        require('src.import.LauncherHardware').symbol(self,'gbc',px+cw/2,gy+math.max(74*s,(ph-110*s)/2),math.min(120*s,ph-130*s))
      end
    end
  end
  if infoH>0 then
    local iy=top+ph+12*s;col(246,252,255);g.rectangle('fill',x+18*s,iy,w-36*s,infoH-10*s,10*s,10*s)
    local payload=f.inspected or f.selected
    if payload then
      local entry=payload.entry;local origin=entry.origin or entry.mon.retroBankOrigin or entry.source
      local image=sprite(self,entry,payload.data)
      if image then local iw,ih=image:getDimensions();local edge=math.min(iw,ih);local sc=(infoH-26*s)/edge
        col(255,255,255);g.draw(image,g.newQuad(0,0,edge,edge,iw,ih),x+26*s,iy+8*s,0,sc,sc) end
      local tx=x+infoH+24*s;local tw=w-infoH-70*s
      text((entry.mon.nickname or tostring(entry.mon.species))..L(' · Lv.')..entry.mon.level,tx,iy+10*s,math.max(1,tw-100*s),true)
      button('COPY ID',x+w-120*s,iy+8*s,100*s,'copyPokemonId')
      text(L('ORIGIN · ')..((Versions.info(origin.version or entry.source.version) or {}).label or 'Universal Bank')..' / '..tostring(origin.slot or '?')..' / '..tostring(origin.place or '?'),tx,iy+39*s,tw)
      text(L('SAVE ID · ')..tostring(origin.saveId or entry.source.saveId or 'Legacy save')..L(' · TRAINER ID · ')..tostring(origin.trainerId or entry.mon.otId or type(entry.mon.ot)=='table' and entry.mon.ot.id or 'Unknown'),tx,iy+61*s,tw)
      text(L('POKÉMON ID · ')..tostring(origin.recordId or entry.id or 'Available after deposit'),tx,iy+83*s,tw)
      text(L('HELD ITEM · ')..tostring(entry.mon.item or entry.mon.heldItem or entry.mon.retroBankHeld and (L('In Item Bank: ')..entry.mon.retroBankHeld.canonical) or 'None'),tx,iy+104*s,tw)
    else text('Select a Pokémon to inspect its origin, trainer, save identity and held item.',x+34*s,iy+26*s,w-68*s,true) end
  end
  if #panels==2 then button('SAVE A / SAVE B',x+18*s,y+h-56*s,180*s,'mobilePanel') end
  if portrait then
    button('POKÉMON INFO',x+18*s,y+h-buttonH-23*s,w-36*s,'mode',{mode='details'})
  end
  text('Your Pokémon · Your adventures · Bank copies sync through your own account.',x+18*s,y+h-24*s,w-36*s)
  if f.picker then
    col(17,38,49,.96);g.rectangle('fill',x+30*s,top,w-60*s,ph,10*s,10*s)
    text('CHOOSE GAME / SAVE SLOT',x+45*s,top+12*s,w-90*s,true,{236,252,246})
    local step=portrait and buttonH+8*s or 42*s
    f.pickerSize=math.max(1,math.min(6,math.floor((ph-112*s)/step)))
    local from=(f.pickerPage or 0)*f.pickerSize+1
    for i=from,math.min(#f.slots,from+f.pickerSize-1) do local row=f.slots[i];button(row.label,x+45*s,top+52*s+(i-from)*step,w-90*s,'pick',{choice=row,panel=f.picker}) end
    if #f.slots==0 then text('No readable saves yet. Import a save or save your game first.',x+45*s,top+60*s,w-90*s,false,{236,252,246}) end
    button('PREVIOUS',x+45*s,top+ph-45*s,120*s,'pickerPage',{delta=-1})
    button('NEXT',x+175*s,top+ph-45*s,120*s,'pickerPage',{delta=1})
    button('CANCEL',x+w-165*s,top+ph-45*s,120*s,'cancelPicker')
  end
  if f.adapt then
    col(17,38,49,.97);g.rectangle('fill',x+30*s,top+50*s,w-60*s,180*s,10*s,10*s)
    text('GENERATION ADAPTATION',x+45*s,top+65*s,w-90*s,true,{244,252,246})
    g.setFont(font);col(236,250,244)
    g.printf('This copy changes IV/DV and training values and uses the destination nature/ability. Gender and shininess may change. The Bank original stays intact.',x+45*s,top+100*s,w-90*s,'left')
    button('ADAPT THIS COPY',x+45*s,top+180*s,190*s,'adapt')
    button('CANCEL',x+w-165*s,top+180*s,120*s,'cancelAdapt')
  end
  if f.drag then
    local mx,my=f.drag.x,f.drag.y
    col(25,104,124,.94);g.rectangle('fill',mx-36*s,my-28*s,140*s,52*s,8*s,8*s)
    text(f.drag.payload.entry.mon.nickname or tostring(f.drag.payload.entry.mon.species),mx-28*s,my-18*s,125*s,false,{255,255,255})
  end
  Pages.animation(self,f,x+18*s,top,w-36*s,ph,s)
  g.pop()
end
function W.press(self,x,y)
  local f=self._bankOverlay
  if f.animation and registered() then return end
  for i=#(f.rects or {}),1,-1 do local r=f.rects[i]
    if inside(r,x,y) then
      if r.action=='bankLogin' then self:_openAccount('bank');return end
      if r.action~='close' and not registered() then f.notice=ACCOUNT_REQUIRED;return end
      if f.mode and f.mode~='bank' and not r.pinned and r.action~='close' and not inside(f.pageView,x,y) then return end
      if registered() and f.picker and r.action~='pick' and r.action~='pickerPage' and r.action~='cancelPicker' then return end
      if registered() and f.adapt and r.action~='adapt' and r.action~='cancelAdapt' then return end
      if r.action=='close' then
        if (f.left.dirty or f.right.dirty) and not f.closeArmed then f.closeArmed=true;f.notice='Unsaved staged copies. Save them first, or press Close again to discard the draft.'
        else W.close(self) end
      elseif require('src.import.BankPages').press(self,W,r) then return
      elseif r.action=='choose' then
        local panel=f[r.panel]
        if panel.dirty then f.notice='Save this draft as a new slot before changing the target.'
        else f.picker=r.panel;f.pickerPage=0 end
      elseif r.action=='pick' then local ok,why=W.select(self,f[r.panel],r.choice);if ok then f.picker=nil else f.notice=why end
      elseif r.action=='cancelPicker' then f.picker=nil
      elseif r.action=='pickerPage' then f.pickerPage=math.max(0,math.min(math.ceil(#f.slots/(f.pickerSize or 6))-1,(f.pickerPage or 0)+r.delta))
      elseif r.action=='bankPage' then
        local slices=f.bankSlices or 1;local pages=math.max(1,math.ceil(#f.bank/30))
        local cursor=math.max(0,math.min(pages*slices-1,(f.page-1)*slices+(f.bankSlice or 0)+r.delta))
        f.page=math.floor(cursor/slices)+1;f.bankSlice=cursor%slices
      elseif r.action=='mobileView' then f.mobileView=r.view;f.drag=nil
      elseif r.action=='mobilePanel' then f.mobilePanel=f.mobilePanel=='right' and 'left' or 'right'
      elseif r.action=='box' then
        local panel=f[r.panel];local count,capacity=B.shape(panel.version,panel.data)
        if r.slices then
          panel.slice=(panel.slice or 0)+r.delta
          if panel.slice<0 then panel.box=(panel.box-1)%(count+1);panel.slice=panel.box==0 and (r.partySlices or 1)-1 or math.ceil(capacity/r.perPage)-1
          elseif panel.slice>=r.slices then panel.box=(panel.box+1)%(count+1);panel.slice=0 end
        else panel.box=(panel.box+r.delta)%(count+1);panel.slice=0 end
      elseif r.action=='save' then local ok,why=W.save(self,r.panel);if not ok then f.notice=why end
      elseif r.action=='adapt' then local a=f.adapt;local ok,why=W.place(self,a.payload,a.target,true);if not ok then f.notice=why;f.adapt=nil end
      elseif r.action=='cancelAdapt' then f.adapt=nil end
      return
    end
  end
  if not registered() then f.notice=ACCOUNT_REQUIRED;return end
  if f.picker or f.adapt then return end
  for _,cell in ipairs(f.cells or {}) do
    if inside(cell,x,y) then
      if f.selected and not cell.entry then
        local ok,why=W.place(self,f.selected,cell.target,false);if not ok then f.notice=why end;f.selected=nil
      elseif cell.entry then
        f.selected={entry=cell.entry,data=cell.data};f.inspected=f.selected;f.drag={payload=f.selected,x=x,y=y,startX=x,startY=y}
      end
      return
    end
  end
end
function W.release(self,x,y)
  local f=self._bankOverlay;local drag=f and f.drag;if not drag then return end
  f.drag=nil
  if math.abs(x-drag.startX)+math.abs(y-drag.startY)<8 then return end
  for _,cell in ipairs(f.cells or {}) do
    if inside(cell,x,y) then
      local ok,why=W.place(self,drag.payload,cell.target,false);if not ok then f.notice=why end
      f.selected=nil;return
    end
  end
end
function W.install(RI)
  local U=RI._ui
  local tool=require('src.import.LauncherBank').TOOL;tool.noGame=true
  local run=RI._sbRunTool
  RI._sbRunTool=function(self,t,...) if t.id=='bank' then return W.open(self) end;return run(self,t,...) end
  local drop=RI.filedropped
  RI.filedropped=function(self,file,...)
    if self._bankOverlay then
      local f=self._bankOverlay
      if f.mode~='interop' then f.notice='Open Legacy / Lua to review a Bank package.';return end
      local permitted,why=registered();if not permitted then f.notice=why or ACCOUNT_REQUIRED;return end
      local ok,bytes=pcall(function() assert(file:open('r'));local value=file:read(require('src.storage.BankInterop').MAX_BYTES+1);file:close();return value end)
      if ok then require('src.import.BankInterchangeWorkspace').load(self,bytes) else f.notice='The dropped package could not be read.' end
      return
    end
    if drop then return drop(self,file,...) end
  end
  local games=RI._sbGames
  RI._sbGames=function(self,x,y,w,h,...)
    local s=self._s
    local half=(w-20*s)/3
    local r=self:_chipButton(x,y,'POKÉMON BANK',{w=half,h=44*s,kind='accent'})
    self._bankLibraryButton=r
    self._bankDexLibraryButton=self:_chipButton(x+half+10*s,y,'GLOBAL POKÉDEX',{w=half,h=44*s,kind='accent'})
    self._saveHistoryLibraryButton=self:_chipButton(x+2*(half+10*s),y,'SAVE HISTORY',{w=half,h=44*s,kind='accent'})
    return 56*s+games(self,x,y+56*s,w,h-56*s,...)
  end
  local press=RI.mousepressed
  RI.mousepressed=function(self,x,y,button,...)
    if self._bankOverlay then if button==1 then local f=self._bankOverlay;local ok,why=pcall(W.press,self,x,y);if not ok then f.notice=tostring(why) end end;return end
    if self.section=='games' and U.inside(self._bankLibraryButton,x,y) then W.open(self);return end
    if self.section=='games' and U.inside(self._bankDexLibraryButton,x,y) then W.open(self,'dex');return end
    return press(self,x,y,button,...)
  end
  local release=RI.mousereleased
  RI.mousereleased=function(self,x,y,button,...)
    if self._bankOverlay then if button==1 then W.release(self,x,y) end;return end
    if release then return release(self,x,y,button,...) end
  end
  local draw=RI.draw
  RI.draw=function(self,...) draw(self,...);W.draw(self) end
  local update=RI.update
  RI.update=function(self,dt,...)
    local f=self._bankOverlay
    if f and not registered() then
      if f.bankCheckJob then f.bankCheckJob:cancel();f.bankCheckJob=nil;f.bankCheck=nil end
      if f.tradeJob then f.tradeJob:cancel();f.tradeJob=nil end
      f.drag=nil;f.selected=nil
      return update(self,dt,...)
    end
    if f and f.drag and not f.drag.touch and love.mouse then f.drag.x,f.drag.y=love.mouse.getPosition() end
    if f then
      require('src.import.BankPages').tick(f)
      if f.animation then f.animation.elapsed=f.animation.elapsed+dt;if f.animation.elapsed>=3.6 then f.animation=nil end end
      if f.tradeJob then
        local result=f.tradeJob:poll()
        if result then
          f.tradeJob=nil;local action=f.tradeAction;f.tradeAction=nil
          local value=result.kind=='done' and result.first
          if not value then f.notice=tostring(result.error or result.second or 'Exchange unavailable. Original copies are preserved.');f.tradeNext=os.time()+30
          elseif action=='profile' then
            if type(value.recompiler_id)=='string' and value.recompiler_id:match('^RRC%-%x%x%x%x%x%x%-%x%x%x%x%x%x$') and type(value.exchanges)=='table' then
              f.tradeProfile=value;f.tradeNext=os.time()+10;f.notice='Your device IDs and exchanges are up to date.'
            else f.notice='The exchange profile could not be read.' end
          elseif action=='receive' then
            f.bank=B.list();f.notice='Received a new Bank companion. Original game saves are preserved.'
            if not value.alreadyReceived then f.animation={elapsed=0,partner=value.partner,entry=value.entry} end
            f.tradeNext=0
          else
            f.tradeConsent=false;f.replying=nil;f.tradeFocus=nil
            if self._disarmTextInput then self:_disarmTextInput() end
            if value.status=='completed' then W.trade(self,'receive',value.id)
            else f.notice=value.status=='prepared' and 'Reply ready. The sender reviews and confirms both Pokémon.' or value.status=='cancelled' and 'Exchange cancelled. All originals are preserved.' or 'Offer queued. It can be cancelled until the exchange completes.';f.tradeNext=0 end
          end
        end
      elseif (f.mode=='trade' or f.mode=='wonder') and not f.animation and os.time()>=(f.tradeNext or 0) and require('src.cloud.RetroCloud').signedIn() then
        f.tradeNext=os.time()+10;W.trade(self,'profile')
      end
    end
    return update(self,dt,...)
  end
  local textInput=RI.textinput
  RI.textinput=function(self,value,...)
    local f=self._bankOverlay
    if f and f.tradeFocus then f.recipient=((f.recipient or '')..value:upper():gsub('[^A-F0-9RC%-]','')):sub(1,17);return end
    if f then return end
    return textInput(self,value,...)
  end
  local key=RI.keypressed
  RI.keypressed=function(self,k,...)
    if self._bankOverlay then
      if k=='escape' then
        local f=self._bankOverlay
        if f.tradeFocus then f.tradeFocus=nil;if self._disarmTextInput then self:_disarmTextInput() end
        elseif f.tradeChoose then f.tradeChoose=nil
        elseif f.picker then f.picker=nil elseif f.adapt then f.adapt=nil elseif f.left.dirty or f.right.dirty then f.notice='Save staged copies before closing, or use Close twice to discard.' else W.close(self) end
      elseif self._bankOverlay.tradeFocus then
        local f=self._bankOverlay
        if k=='backspace' then f.recipient=(f.recipient or ''):sub(1,-2)
        elseif k=='return' then f.tradeFocus=nil;if self._disarmTextInput then self:_disarmTextInput() end end
      elseif self._bankOverlay.mode~='bank' then
        local f=self._bankOverlay
        if k=='down' or k=='pagedown' then f.subScroll=math.min(f.subMax or 0,(f.subScroll or 0)+60)
        elseif k=='up' or k=='pageup' then f.subScroll=math.max(0,(f.subScroll or 0)-60) end
      end
      return
    end
    return key(self,k,...)
  end
  for _,method in ipairs({'touchpressed','touchmoved','touchreleased'}) do
    local original=RI[method]
    RI[method]=function(self,id,x,y,...)
      if self._bankOverlay then
        local f=self._bankOverlay
        if f.mode and f.mode~='bank' then
          if method=='touchpressed' then if not f.pageTouch then f.pageTouch={id=id,y=y,startY=y,startX=x} end
          elseif method=='touchmoved' then local t=f.pageTouch;if t and t.id==id then
            t.moved=t.moved or math.abs(y-t.startY)>8 or math.abs(x-t.startX)>8
            if t.moved then f.subScroll=math.max(0,math.min(f.subMax or 0,(f.subScroll or 0)+t.y-y)) end;t.y=y
          end
          else local t=f.pageTouch;if t and t.id==id then f.pageTouch=nil;if not t.moved then W.press(self,x,y) end end end
          return
        end
        if method=='touchpressed' then
          if not self._bankOverlay.drag then W.press(self,x,y) end
          if self._bankOverlay and self._bankOverlay.drag then self._bankOverlay.drag.touch=id end
        elseif method=='touchreleased' then
          local drag=self._bankOverlay.drag
          if not drag or not drag.touch or drag.touch==id then W.release(self,x,y) end
        elseif self._bankOverlay.drag and self._bankOverlay.drag.touch==id then self._bankOverlay.drag.x,self._bankOverlay.drag.y=x,y end
        return
      end
      return original(self,id,x,y,...)
    end
  end
  local wheel=RI.wheelmoved
  RI.wheelmoved=function(self,dx,dy,...)
    if self._bankOverlay then
      local f=self._bankOverlay
      if f.mode~='bank' then f.subScroll=math.max(0,math.min(f.subMax or 0,(f.subScroll or 0)-dy*45)) end
      return
    end
    return wheel(self,dx,dy,...)
  end
end
return W
