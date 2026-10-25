-- Native save recovery. Every recovery creates a new slot; the selected
-- source, its backups, active slot and cloud link are never replaced here.
local W={}
local Saves=require('src.core.SaveData')
local Versions=require('src.core.GameVersion')
local function busy(self)
  return self._storageTask or self._profileApplying or self._communityDownload or self._resumeRestore
end
local function reset(f)
  f.scroll=0;f.rects={};f.padIndex=2;f.padActive=false;f.touch=nil;f.notice=nil;f.chosen=nil
end
function W.open(self)
  if busy(self) then self.settingsNotice='Finish the current transfer before opening save history.';return end
  self._saveHistoryOverlay={step='games',scroll=0,rects={},padIndex=2}
end
function W.close(self) self._saveHistoryOverlay=nil end
function W.action(self,id)
  local f=self._saveHistoryOverlay;if not f then return end
  if id=='close' then W.close(self);return end
  if id=='back' then
    reset(f)
    if f.step=='copies' then f.step='slots';f.rows=nil
    else f.step='games';f.version=nil;f.slots=nil end
    return
  end
  if id:match('^game:') then
    local version=id:sub(6);local found=false
    for _,v in ipairs(Versions.ORDER) do if v==version then found=true;break end end
    if not found then return end
    local ok,slots=pcall(Saves.listSlots,version)
    local good,deleted=pcall(Saves.deletedSlots,version)
    if not ok or not good then f.notice='Save history could not be read. All files are preserved.';return end
    reset(f);f.step='slots';f.version=version;f.slots={}
    for _,slot in ipairs(slots) do
      f.slots[#f.slots+1]={id=slot.id,label=slot.label or slot.name or slot.id,unreadable=slot.unreadable,exists=slot.exists}
    end
    for _,row in ipairs(deleted) do
      f.slots[#f.slots+1]={id=row.slot,label='Deleted · '..tostring(row.name or row.slot),deleted=row}
    end
    return
  end
  local index=tonumber(id:match('^slot:(%d+)$'))
  if index and f.step=='slots' and f.slots[index] then
    local slot=f.slots[index];local rows
    if slot.deleted then rows={slot.deleted}
    else
      local ok,result=pcall(Saves.slotBackups,f.version,slot.id)
      if not ok then f.notice='The copies could not be read. All files are preserved.';return end
      rows=result
    end
    reset(f);f.step='copies';f.slot=slot.id;f.label=slot.label;f.rows=rows
    return
  end
  index=tonumber(id:match('^copy:(%d+)$'))
  if index and f.step=='copies' and f.rows[index] and f.rows[index].ok then
    f.chosen=index;f.notice='Selected copy: '..tostring(f.rows[index].label)..'. Create a new slot below to keep it.';return
  end
  if id=='recover' and f.step=='copies' and f.chosen then
    if busy(self) then f.notice='Finish the current transfer before creating a copy.';return end
    local row=f.rows[f.chosen]
    if not row or not row.ok then return end
    local ok,new,why=pcall(Saves.restoreAsNewSlot,f.version,row,tostring(f.label)..' (recovered)')
    if not ok or not new then
      f.notice='Could not create the recovery copy: '..tostring(ok and why or new);return
    end
    f.chosen=nil;f.recovered=new
    f.notice='Recovered as '..new..'. Select it in Save files to continue. Original, active save and cloud links are preserved.'
    self._settingsCache=nil
    if self._refreshSlots then pcall(self._refreshSlots,self,f.version) end
  end
end
function W.scroll(self,dy)
  local f=self._saveHistoryOverlay
  if f then f.scroll=math.max(0,math.min(f.maxScroll or 0,f.scroll-dy*45));f.padActive=false end
end
function W.navigate(self,step)
  local f=self._saveHistoryOverlay;if not f or #f.rects==0 then return end
  f.padIndex=((f.padIndex or 2)-1+step)%#f.rects+1;f.padActive=true
  local r=f.rects[f.padIndex];local v=f.viewport
  if not r.pinned then
    if r.y<v.y then f.scroll=math.max(0,f.scroll+r.y-v.y)
    elseif r.y+r.height>v.y+v.height then f.scroll=math.min(f.maxScroll or 0,f.scroll+r.y+r.height-v.y-v.height) end
  end
end
function W.draw(self)
  local f=self._saveHistoryOverlay;if not f then return end
  local g=love.graphics;local ww,hh=g.getDimensions();local s=math.max(.65,math.min(ww/1050,hh/720,1.25))
  local w,h=math.min(820*s,ww-28*s),math.min(670*s,hh-28*s);local x,y=(ww-w)/2,(hh-h)/2
  local U,p=self._ui,self.palette();f.rects={}
  g.push('all');g.setCanvas();g.origin();g.setShader();g.setScissor();g.setBlendMode('alpha')
  g.setColor(.015,.025,.05,.97);g.rectangle('fill',0,0,ww,hh)
  g.setColor(.06,.09,.14,1);g.rectangle('fill',x,y,w,h,14*s,14*s)
  g.setFont(self.stateFont);U.col(p.ink);g.printf('SAVE HISTORY',x+24*s,y+24*s,w-150*s,'left')
  local close=self:_chipButton(x+w-108*s,y+18*s,'CLOSE',{w=84*s,h=38*s,kind='accent'})
  close.id='close';close.pinned=true;f.rects[1]=close
  local v={x=x+18*s,y=y+76*s,width=w-36*s,height=h-94*s};f.viewport=v
  local top=v.y-f.scroll
  local function paragraph(value,big)
    local font=big and self.stateFont or self.hintFont;g.setFont(font);U.col(big and p.ink or p.detail)
    local _,lines=font:getWrap(value,w-48*s);g.printf(value,x+24*s,top,w-48*s,'left')
    top=top+math.max(1,#lines)*font:getHeight()+14*s
  end
  local function row(label,id)
    local _,lines=self.hintFont:getWrap(label,w-72*s);local height=math.max(44*s,#lines*self.hintFont:getHeight()+22*s)
    local r=self:_chipButton(x+24*s,top,'',{w=w-48*s,h=height,kind='accent'});r.id=id;f.rects[#f.rects+1]=r
    g.setFont(self.hintFont);U.col(p.link);g.printf(label,x+36*s,top+11*s,w-72*s,'left');top=top+height+10*s
  end
  g.setScissor(v.x,v.y,v.width,v.height)
  if f.step~='games' then row('‹ BACK','back') end
  if f.notice then paragraph(f.notice) end
  if f.step=='games' then
    paragraph('Keep every chapter of your adventure.',true)
    paragraph('Browse local snapshots, previous saves, deleted slots and downloaded cloud-sync backups. Recovery creates a separate save slot. Remote cloud revision browsing is not available here yet.')
    for _,version in ipairs(Versions.ORDER) do row(Versions.info(version).displayName,'game:'..version) end
  elseif f.step=='slots' then
    paragraph(Versions.info(f.version).displayName,true)
    if #f.slots==0 then paragraph('No save slots or deleted copies were found for this game.') end
    for i,slot in ipairs(f.slots) do
      row(slot.label..' · '..slot.id..(slot.deleted and ' · DELETED' or slot.unreadable and ' · NEEDS RECOVERY' or ''),'slot:'..i)
    end
  else
    paragraph(f.label..' · '..f.slot,true)
    paragraph('Choose a copy, then create a recovery slot. No game is launched and your active save stays selected.')
    if #f.rows==0 then paragraph('No saved copies were found for this slot.') end
    for i,copy in ipairs(f.rows) do
      local date=copy.when and os.date('%Y-%m-%d %H:%M',copy.when) or 'Date unknown'
      local meta=copy.meta or {}
      local detail=copy.ok and (tostring(copy.name or 'Trainer')..' · '..tostring(meta.badges or 0)..' badges · '..tostring(meta.timeText or '0:00')) or 'Unreadable · file kept'
      if copy.ok then row((f.chosen==i and '✓ ' or '')..tostring(copy.label)..' · '..date..'\n'..detail,'copy:'..i)
      else paragraph(tostring(copy.label)..' · '..date..' · '..detail) end
    end
    if f.chosen then row('CREATE NEW SLOT FROM SELECTED COPY','recover') end
  end
  f.maxScroll=math.max(0,top+f.scroll-v.y-v.height);f.scroll=math.min(f.scroll,f.maxScroll)
  local r=f.padActive and f.rects[f.padIndex]
  if r and not r.pinned then U.col(p.link);g.setLineWidth(2*s);g.rectangle('line',r.x-2*s,r.y-2*s,r.width+4*s,r.height+4*s,6*s,6*s) end
  g.setScissor()
  if f.maxScroll>0 then
    U.col(p.cardBlue);g.rectangle('fill',x+w-12*s,v.y,3*s,v.height)
    local thumb=math.max(20*s,v.height*v.height/(v.height+f.maxScroll));U.col(p.link)
    g.rectangle('fill',x+w-12*s,v.y+(v.height-thumb)*f.scroll/f.maxScroll,3*s,thumb)
  end
  g.pop()
end
function W.install(RI)
  local U=RI._ui
  RI._openSaveHistory=W.open
  local cloudRows=RI._sbCloudRows
  RI._sbCloudRows=function(self,add,...) cloudRows(self,add,...);add({kind='action',label='SAVE HISTORY & RECOVERY',value='OPEN',action='saveHistory'}) end
  local action=RI._settingsAction
  RI._settingsAction=function(self,entry,...) if entry and entry.action=='saveHistory' then W.open(self);return end;return action(self,entry,...) end
  local draw=RI.draw;RI.draw=function(self,...) draw(self,...);W.draw(self) end
  local play=RI.play;RI.play=function(self,...) if self._saveHistoryOverlay then return end;return play(self,...) end
  local press=RI.mousepressed
  RI.mousepressed=function(self,x,y,b,...)
    local f=self._saveHistoryOverlay
    if not f then
      if b==1 and self.section=='games' and U.inside(self._saveHistoryLibraryButton,x,y) then W.open(self);return end
      return press(self,x,y,b,...)
    end
    if b~=1 then return end;f.padActive=false
    for _,r in ipairs(f.rects) do if (r.pinned or U.inside(f.viewport,x,y)) and U.inside(r,x,y) then W.action(self,r.id);return end end
  end
  local key=RI.keypressed;RI.keypressed=function(self,k,...)
    local f=self._saveHistoryOverlay;if not f then return key(self,k,...) end
    if k=='escape' then if f.step=='games' then W.close(self) else W.action(self,'back') end
    elseif k=='down' or k=='tab' then W.navigate(self,1) elseif k=='up' then W.navigate(self,-1)
    elseif k=='return' or k=='space' then local r=f.rects[f.padIndex or 2];if r then W.action(self,r.id) end end
  end
  local pad=RI.gamepadpressed;RI.gamepadpressed=function(self,j,b,...)
    local f=self._saveHistoryOverlay;if not f then if pad then return pad(self,j,b,...) end;return end
    if b=='b' then if f.step=='games' then W.close(self) else W.action(self,'back') end
    elseif b=='dpdown' then W.navigate(self,1) elseif b=='dpup' then W.navigate(self,-1)
    elseif b=='a' then local r=f.rects[f.padIndex or 2];if r then W.action(self,r.id) end end
  end
  local wheel=RI.wheelmoved;RI.wheelmoved=function(self,dx,dy,...)
    if self._saveHistoryOverlay then W.scroll(self,dy);return end;if wheel then return wheel(self,dx,dy,...) end
  end
  local touch=RI.touchpressed;RI.touchpressed=function(self,id,x,y,...)
    local f=self._saveHistoryOverlay;if not f then return touch(self,id,x,y,...) end
    if not f.touch then f.touch={id=id,x=x,y=y,startX=x,startY=y} end
  end
  local move=RI.touchmoved;RI.touchmoved=function(self,id,x,y,...)
    local f=self._saveHistoryOverlay;if not f then if move then return move(self,id,x,y,...) end;return end
    local t=f.touch;if t and t.id==id then
      local delta=y-t.y;t.moved=t.moved or math.abs(y-t.startY)>8 or math.abs(x-t.startX)>8;t.y=y
      if t.moved then W.scroll(self,delta/45) end
    end
  end
  local release=RI.touchreleased;RI.touchreleased=function(self,id,x,y,...)
    local f=self._saveHistoryOverlay;if not f then if release then return release(self,id,x,y,...) end;return end
    local t=f.touch;if t and t.id==id then f.touch=nil;if not t.moved then self:mousepressed(x,y,1) end end
  end
  for _,name in ipairs({'textinput','mousereleased','mousemoved'}) do
    local original=RI[name];RI[name]=function(self,...) if self._saveHistoryOverlay then return end;if original then return original(self,...) end end
  end
end
return W
