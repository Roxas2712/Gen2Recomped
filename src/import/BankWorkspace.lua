-- Native-resolution Bank workspace. Dragging stages copies; only Save copy
-- writes a new target slot. Neither source files nor occupied cells are replaced.
local W={}
local B=require('src.storage.PokemonBank')
local Saves=require('src.core.SaveData')
local Versions=require('src.core.GameVersion')
local Serializer=require('src.core.SaveSerializer')
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
function W.open(self)
  self._bankOverlay={bank=B.list(),left={box=0},right={box=1},page=1,slots=W.slots(self),sprites={}}
end
function W.select(self,panel,choice)
  local save,why=B.readSave(choice.version,choice.slot);if not save then return nil,why end
  local data,err=B.data(choice.version);if not data then return nil,err end
  local previous=panel.box or 1
  for k in pairs(panel) do panel[k]=nil end
  panel.version=choice.version;panel.slot=choice.slot;panel.label=choice.label;panel.save=save;panel.data=data;panel.box=previous
  return true
end
function W.place(self,payload,target,allow)
  local f=self._bankOverlay
  if target.bank then
    local e=payload.entry
    local id,why=B.deposit(e.mon,e.source.version,e.source.slot,e.source.place,payload.data or B.data(e.source.version))
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
  f.notice='Copy staged. Save a new slot to keep it; originals stay intact.'
  return true
end
function W.save(self,panelName)
  local f=self._bankOverlay;local panel=f[panelName]
  local id,why=B.commitDraft(panel.version,panel.slot,panel.save)
  if not id then return nil,why end
  panel.slot=id;panel.label=Versions.info(panel.version).label..' / '..id;panel.dirty=nil
  f.slots=W.slots(self);self:_refreshSlots(panel.version);self._settingsCache=nil
  f.notice='Saved as '..panel.label..'. The base save and Bank originals are unchanged.'
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
  local g=love.graphics;local ww,hh=g.getDimensions();local s=math.max(.65,math.min(ww/1050,hh/720,1.2))
  local U=self._ui;local font=self.hintFont;local large=self.stateFont or font
  local x,y=16*s,22*s;local w,h=ww-32*s,hh-44*s
  f.rects={};f.cells={}
  local function col(r,b,c,a) g.setColor(r/255,b/255,c/255,a or 1) end
  local function text(value,tx,ty,width,big,ink)
    local fn=big and large or font;g.setFont(fn);if ink then col(ink[1],ink[2],ink[3]) else col(37,68,79) end
    g.print(U.ellipsize(fn,tostring(value),width),tx,ty)
  end
  local function button(label,bx,by,bw,action,fields)
    local r=fields or {};r.x=bx;r.y=by;r.width=bw;r.height=34*s;r.action=action;f.rects[#f.rects+1]=r
    col(34,113,132);g.rectangle('fill',bx,by,bw,r.height,6*s,6*s)
    text(label,bx+9*s,by+(r.height-font:getHeight())/2,bw-18*s,false,{244,252,250});return r
  end
  g.push('all');g.setCanvas();g.origin();g.setScissor();g.setShader();g.setBlendMode('alpha')
  col(4,12,22,.82);g.rectangle('fill',0,0,ww,hh)
  col(228,244,240);g.rectangle('fill',x,y,w,h,16*s,16*s)
  col(27,92,111);g.rectangle('fill',x,y,w,65*s,16*s,16*s);g.rectangle('fill',x,y+32*s,w,33*s)
  text('RETRORECOMPED · POKÉMON BANK',x+18*s,y+15*s,w-160*s,true,{245,255,252})
  button('CLOSE',x+w-110*s,y+15*s,92*s,'close')
  local top=y+78*s
  text(f.notice or 'Drag to copy between saves and the Bank. Save copy creates a new slot.',x+18*s,top,w-36*s)
  top=top+34*s
  local gap=12*s;local cw=(w-36*s-2*gap)/3;local ph=h-(top-y)-76*s
  local panels={{name='left',title='GAME SAVE A'},{name='bank',title='YOUR BANK'},{name='right',title='GAME SAVE B'}}
  if cw<230*s then
    panels={{name=f.mobilePanel or 'left',title='GAME SAVE'},{name='bank',title='BANK'}};cw=(w-36*s-gap)/2
  end
  local function monCell(entry,data,cx,cy,size,target)
    col(255,255,255,.88);g.rectangle('fill',cx,cy,size-4*s,size-4*s,5*s,5*s)
    col(149,189,187,.65);g.rectangle('line',cx,cy,size-4*s,size-4*s,5*s,5*s)
    local r={x=cx,y=cy,width=size-4*s,height=size-4*s,target=target,entry=entry,data=data};f.cells[#f.cells+1]=r
    if entry then
      local image=sprite(self,entry,data)
      if image then
        local iw,ih=image:getDimensions();local edge=math.min(iw,ih);local scale=(size-14*s)/edge
        col(255,255,255);g.draw(image,g.newQuad(0,0,edge,edge,iw,ih),cx+(size-4*s-edge*scale)/2,cy+2*s,0,scale,scale)
      else text(tostring(entry.mon.species):sub(1,7),cx+3*s,cy+size*.3,size-10*s) end
      text('Lv.'..tostring(entry.mon.level or '?'),cx+4*s,cy+size-18*s,size-10*s,false,{62,100,104})
    end
  end
  for pi,kind in ipairs(panels) do
    local px=x+18*s+(pi-1)*(cw+gap)
    col(205,231,225);g.rectangle('fill',px,top,cw,ph,10*s,10*s)
    text(kind.title,px+10*s,top+12*s,cw-20*s,true)
    local gy=top+48*s
    if kind.name=='bank' then
      local pages=math.max(1,math.ceil(#f.bank/30));f.page=math.max(1,math.min(pages,f.page))
      button('<',px+10*s,gy,32*s,'bankPage',{delta=-1})
      text('Box '..f.page..' / '..pages,px+50*s,gy+8*s,cw-100*s)
      button('>',px+cw-42*s,gy,32*s,'bankPage',{delta=1});gy=gy+48*s
      local size=math.min((cw-20*s)/6,(ph-116*s)/5)
      for pos=1,30 do local entry=f.bank[(f.page-1)*30+pos];monCell(entry,nil,px+10*s+((pos-1)%6)*size,gy+math.floor((pos-1)/6)*size,size,{bank=true}) end
      text(#f.bank..' immutable copies',px+10*s,top+ph-24*s,cw-20*s)
    else
      local panel=f[kind.name]
      button(panel.label or 'CHOOSE SAVE',px+10*s,gy,cw-20*s,'choose',{panel=kind.name});gy=gy+44*s
      if panel.save then
        local count,capacity=B.shape(panel.version,panel.data)
        if panel.box>count then panel.box=1 end
        button('<',px+10*s,gy,32*s,'box',{panel=kind.name,delta=-1})
        text(panel.box==0 and 'PARTY' or 'BOX '..panel.box,px+50*s,gy+8*s,cw-100*s)
        button('>',px+cw-42*s,gy,32*s,'box',{panel=kind.name,delta=1});gy=gy+44*s
        local cols=capacity==20 and 5 or 6;local rows=panel.box==0 and 1 or capacity==20 and 4 or 5
        local box=panel.box==0 and panel.save.party or B.boxMons(B.boxes(panel.save)[panel.box])
        local size=math.min((cw-20*s)/cols,(ph-174*s)/math.max(4,rows))
        local n=panel.box==0 and 6 or capacity
        if panel.box==0 then cols=3;rows=2;size=math.min((cw-20*s)/cols,(ph-174*s)/4) end
        for pos=1,n do
          local mon=box and box[pos]
          local entry=mon and B.makeEntry(mon,panel.version,panel.slot,panel.box==0 and ('Party '..pos) or ('Box '..panel.box..' / '..pos),panel.data)
          monCell(entry,panel.data,px+10*s+((pos-1)%cols)*size,gy+math.floor((pos-1)/cols)*size,size,{panel=kind.name,slot=pos})
        end
        if panel.dirty then button('SAVE AS NEW SLOT',px+10*s,top+ph-42*s,cw-20*s,'save',{panel=kind.name}) end
      else text('Choose a save to show its boxes.',px+10*s,gy+14*s,cw-20*s) end
    end
  end
  if #panels==2 then button('SAVE A / SAVE B',x+18*s,y+h-56*s,180*s,'mobilePanel') end
  text('Copies remain local until save sync. Original cartridge images stay on this device.',x+18*s,y+h-24*s,w-36*s)
  if f.picker then
    col(17,38,49,.96);g.rectangle('fill',x+30*s,top,w-60*s,ph,10*s,10*s)
    text('CHOOSE GAME / SAVE SLOT',x+45*s,top+12*s,w-90*s,true,{236,252,246})
    local from=(f.pickerPage or 0)*6+1
    for i=from,math.min(#f.slots,from+5) do local row=f.slots[i];button(row.label,x+45*s,top+52*s+(i-from)*42*s,w-90*s,'pick',{choice=row,panel=f.picker}) end
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
  g.pop()
end
function W.press(self,x,y)
  local f=self._bankOverlay
  for i=#(f.rects or {}),1,-1 do local r=f.rects[i]
    if inside(r,x,y) then
      if f.picker and r.action~='pick' and r.action~='pickerPage' and r.action~='cancelPicker' then return end
      if f.adapt and r.action~='adapt' and r.action~='cancelAdapt' then return end
      if r.action=='close' then
        if (f.left.dirty or f.right.dirty) and not f.closeArmed then f.closeArmed=true;f.notice='Unsaved staged copies. Save them first, or press Close again to discard the draft.'
        else self._bankOverlay=nil end
      elseif r.action=='choose' then
        local panel=f[r.panel]
        if panel.dirty then f.notice='Save this draft as a new slot before changing the target.'
        else f.picker=r.panel;f.pickerPage=0 end
      elseif r.action=='pick' then local ok,why=W.select(self,f[r.panel],r.choice);if ok then f.picker=nil else f.notice=why end
      elseif r.action=='cancelPicker' then f.picker=nil
      elseif r.action=='pickerPage' then f.pickerPage=math.max(0,math.min(math.ceil(#f.slots/6)-1,(f.pickerPage or 0)+r.delta))
      elseif r.action=='bankPage' then f.page=math.max(1,f.page+r.delta)
      elseif r.action=='mobilePanel' then f.mobilePanel=f.mobilePanel=='right' and 'left' or 'right'
      elseif r.action=='box' then local panel=f[r.panel];local count=B.shape(panel.version,panel.data);panel.box=(panel.box+r.delta)%(count+1)
      elseif r.action=='save' then local ok,why=W.save(self,r.panel);if not ok then f.notice=why end
      elseif r.action=='adapt' then local a=f.adapt;local ok,why=W.place(self,a.payload,a.target,true);if not ok then f.notice=why;f.adapt=nil end
      elseif r.action=='cancelAdapt' then f.adapt=nil end
      return
    end
  end
  if f.picker or f.adapt then return end
  for _,cell in ipairs(f.cells or {}) do
    if inside(cell,x,y) then
      if f.selected and not cell.entry then
        local ok,why=W.place(self,f.selected,cell.target,false);if not ok then f.notice=why end;f.selected=nil
      elseif cell.entry then
        f.selected={entry=cell.entry,data=cell.data};f.drag={payload=f.selected,x=x,y=y,startX=x,startY=y}
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
  local games=RI._sbGames
  RI._sbGames=function(self,x,y,w,h,...)
    local s=self._s
    local r=self:_chipButton(x,y,'POKÉMON BANK · OPEN BOX WORKSPACE',{w=w,h=44*s,kind='accent'})
    self._bankLibraryButton=r
    return 56*s+games(self,x,y+56*s,w,h-56*s,...)
  end
  local press=RI.mousepressed
  RI.mousepressed=function(self,x,y,button,...)
    if self._bankOverlay then if button==1 then local ok,why=pcall(W.press,self,x,y);if not ok then self._bankOverlay.notice=tostring(why) end end;return end
    if self.section=='games' and U.inside(self._bankLibraryButton,x,y) then W.open(self);return end
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
    if f and f.drag and not f.drag.touch and love.mouse then f.drag.x,f.drag.y=love.mouse.getPosition() end
    return update(self,dt,...)
  end
  local key=RI.keypressed
  RI.keypressed=function(self,k,...)
    if self._bankOverlay then
      if k=='escape' then
        local f=self._bankOverlay
        if f.picker then f.picker=nil elseif f.adapt then f.adapt=nil elseif f.left.dirty or f.right.dirty then f.notice='Save staged copies before closing, or use Close twice to discard.' else self._bankOverlay=nil end
      end
      return
    end
    return key(self,k,...)
  end
  for _,method in ipairs({'touchpressed','touchmoved','touchreleased'}) do
    local original=RI[method]
    RI[method]=function(self,id,x,y,...)
      if self._bankOverlay then
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
  RI.wheelmoved=function(self,...)
    if self._bankOverlay then return end
    return wheel(self,...)
  end
end
return W
