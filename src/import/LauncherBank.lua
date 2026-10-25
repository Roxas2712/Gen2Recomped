local M={TOOL={id='bank',label='Pokémon Bank',note='Keep copies across save slots and devices. Originals stay intact.'}}
local B=require('src.storage.PokemonBank')
local Saves=require('src.core.SaveData')
local Versions=require('src.core.GameVersion')
local PAGE=18
local function flow(self)
  local f=self.section=='tools' and self.toolFlow
  return f and type(f.tool)=='table' and f.tool.id=='bank' and f or nil
end
local function selected(f)
  local rows={}
  for _,entry in ipairs(f.entries or {}) do if f.selected and f.selected[entry.id] then rows[#rows+1]=entry end end
  return rows
end
local function reset(self,f,step)
  f.step=step;f.page=1;f.notice=nil;self.pageScroll=0
end
local function saveRows(self)
  local rows={}
  for _,version in ipairs(Versions.ORDER) do
    if self.ready[version] then
      for _,slot in ipairs(Saves.listSlots(version)) do
        if slot.exists and not slot.unreadable then
          rows[#rows+1]={version=version,slot=slot.id,title=Versions.info(version).label..' · '..(slot.label or slot.name or slot.id)}
        end
      end
    end
  end
  return rows
end
function M.press(self,f,r)
  local action=r.action
  if action=='page' then f.page=r.page;self.pageScroll=0;return end
  if action=='select' then f.selected=f.selected or {};f.selected[r.id]=not f.selected[r.id];return end
  if action=='adapt' then f.adapt=not f.adapt;return end
  if action=='source' then reset(self,f,'source');f.saveRows=saveRows(self);return end
  if action=='target' then reset(self,f,'target');f.saveRows=saveRows(self);return end
  if action=='openSource' then
    local save,why=B.readSave(r.version,r.slot)
    if not save then f.notice=why;return end
    local data,err=B.data(r.version);if not data then f.notice=err;return end
    f.source={version=r.version,slot=r.slot,data=data};f.mons=B.scan(save,r.version);f.chosen={}
    reset(self,f,'sourceMons');return
  end
  if action=='mon' then f.chosen[r.index]=not f.chosen[r.index];return end
  if action=='deposit' then
    local count=0
    for i,row in ipairs(f.mons) do
      if f.chosen[i] then
        local id,why=B.deposit(row.mon,f.source.version,f.source.slot,row.place,f.source.data)
        if not id then f.notice='Bank copy stopped: '..tostring(why);return end
        count=count+1
      end
    end
    reset(self,f,'home');f.entries=B.list();f.selected={};f.notice=count..' copies kept in your Bank. Source save unchanged.'
    return
  end
  if action=='openTarget' then
    local data,why=B.data(r.version);if not data then f.notice=why;return end
    f.target={version=r.version,slot=r.slot,data=data};f.adapt=false;reset(self,f,'confirm');return
  end
  if action=='deliver' then
    local target=f.target
    local id,why=B.deliver(selected(f),target.version,target.slot,f.adapt,target.data)
    if not id then f.notice=tostring(why);return end
    reset(self,f,'home');f.notice='Created '..Versions.info(target.version).label..' / '..id..'. Select that new save slot to play. Originals unchanged.'
    if self._refreshSlots then self:_refreshSlots(target.version) end
    self._settingsCache=nil;return
  end
end
function M.install(RI)
  local Sidebar=require('src.import.LauncherSidebar')
  table.insert(Sidebar.TOOLS,6,M.TOOL)
  local draw=RI._sbTools
  RI._sbTools=function(self,x,y,w,h,...)
    local f=flow(self);if not f then return draw(self,x,y,w,h,...) end
    f.step=f.step or 'home';f.selected=f.selected or {};f.entries=f.entries or B.list()
    local g,s,p=love.graphics,self._s,RI.palette()
    local U=RI._ui;local start=y
    self._bankRects={}
    local function text(value,color)
      g.setFont(self.hintFont);U.col(color or p.detail)
      local _,lines=self.hintFont:getWrap(value,w);g.printf(value,x,y,w,'left');y=y+#lines*self.hintFont:getHeight()+12*s
    end
    local function row(title,sub,pill,action,fields)
      local height=math.max(58*s,self.hintFont:getHeight()*2+24*s)
      local r=fields or {};r.x=x;r.y=y;r.width=w;r.height=height;r.action=action
      U.col(p.slotBg or p.cardBlue,.8);g.rectangle('fill',x,y,w,height,8*s,8*s)
      local buttonW=math.min(w*.35,170*s)
      local font=self.stateFont or self.hintFont
      g.setFont(font);U.col(p.ink);g.print(U.ellipsize(font,title,math.max(20,w-buttonW-35*s)),x+12*s,y+9*s)
      g.setFont(self.hintFont);U.col(p.detail)
      g.print(U.ellipsize(self.hintFont,sub or '',math.max(20,w-buttonW-35*s)),x+12*s,y+height-self.hintFont:getHeight()-9*s)
      self:_chipButton(x+w-buttonW-10*s,y+(height-34*s)/2,pill,{w=buttonW,h=34*s,kind='accent'})
      self._bankRects[#self._bankRects+1]=r;y=y+height+9*s
    end
    local function page(rows,paint)
      f.page=math.max(1,math.min(f.page or 1,math.max(1,math.ceil(#rows/PAGE))))
      local from=(f.page-1)*PAGE+1
      for i=from,math.min(#rows,from+PAGE-1) do paint(rows[i],i) end
      if f.page>1 then row('Previous page','','←','page',{page=f.page-1}) end
      if from+PAGE<=#rows then row('Next page',f.page..' / '..math.ceil(#rows/PAGE),'→','page',{page=f.page+1}) end
    end
    if f.notice then text(f.notice,p.link) end
    text('POKÉMON BANK · Copies stay in the Bank and in their original save. Cloud sync uses your connected account.')
    if f.step=='home' then
      row('Copy from a save','Party and PC boxes from your imported games.','CHOOSE SAVE','source')
      if #selected(f)>0 then row('Copy '..#selected(f)..' selected Pokémon to a save','Creates a new save slot; review compatibility first.','CHOOSE TARGET','target') end
      if #f.entries==0 then text('Your Bank is empty. Copy Pokémon from one of your saves to begin.') end
      page(f.entries,function(entry)
        local mon=entry.mon
        row((mon.nickname or tostring(mon.species))..' · Lv. '..mon.level,
          Versions.info(entry.source.version).label..' / '..tostring(entry.source.slot)..' / '..tostring(entry.source.place),
          f.selected[entry.id] and '✓ SELECTED' or 'SELECT','select',{id=entry.id})
      end)
    elseif f.step=='source' or f.step=='target' then
      text(f.step=='source' and 'Choose the source save. No Pokémon will be removed.' or 'Choose a base save. Your copies will appear in a new save slot.')
      if #f.saveRows==0 then text('No readable saves found. Import a save or save your game first.') end
      page(f.saveRows,function(r) row(r.title,r.slot,'CHOOSE',f.step=='source' and 'openSource' or 'openTarget',{version=r.version,slot=r.slot}) end)
    elseif f.step=='sourceMons' then
      local n=0;for _,chosen in pairs(f.chosen) do if chosen then n=n+1 end end
      if n>0 then row('Keep '..n..' copies in the Bank','Your source save remains unchanged.','COPY TO BANK','deposit') end
      page(f.mons,function(r,i) row((r.mon.nickname or tostring(r.mon.species))..' · Lv. '..r.mon.level,r.place,f.chosen[i] and '✓ SELECTED' or 'SELECT','mon',{index=i}) end)
    elseif f.step=='confirm' then
      local entries=selected(f);local blocked=false;local adaptation=false
      text('Destination: '..Versions.info(f.target.version).label..' / '..f.target.slot..'. Copies go into empty PC slots in a NEW save.')
      for _,entry in ipairs(entries) do
        local mon,why=B.convert(entry,f.target.version,f.target.data,true)
        if not mon then blocked=true;text(tostring(entry.mon.species)..': '..tostring(why),p.warning)
        elseif why then adaptation=true end
      end
      if adaptation then
        text('Generation adaptation changes IV/DV and training values and assigns destination nature/ability. Gender and shininess may change. The Bank retains the exact original.',p.warning)
        row('Allow generation adaptation','Required for different stat models.',f.adapt and '✓ ALLOWED' or 'OFF','adapt')
      end
      if not blocked and (not adaptation or f.adapt) then row('Create new save with '..#entries..' copies','Source, base save and Bank entries are preserved.','CREATE COPY','deliver') end
    end
    return y-start
  end
  local press=RI._sbMousepressed
  RI._sbMousepressed=function(self,x,y,...)
    local f=flow(self)
    if f and not (self._sb and self._sb.back and RI._ui.inside(self._sb.back,x,y)) then
      for _,r in ipairs(self._bankRects or {}) do
        if RI._ui.inside(r,x,y) then
          local ok,why=pcall(M.press,self,f,r)
          if not ok then f.notice='Bank copy stopped: '..tostring(why) end
          return true
        end
      end
    end
    return press(self,x,y,...)
  end
  local back=RI._sbBack
  RI._sbBack=function(self,...)
    local f=flow(self)
    if f and f.step and f.step~='home' then reset(self,f,'home');return true end
    return back(self,...)
  end
end
return M
