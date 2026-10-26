-- Category hubs and quiet controls for the rest of the library shell.
-- All actions still go through RomImporter's existing persistence/validation.
local Workspace = {}
local Strings = require('src.core.Strings')
local Sidebar = require('src.import.LauncherSidebar')
local Library = require('src.import.LauncherLibrary')

Workspace.CATEGORIES = {
  {id="setup",name="Setup & guide",note="Language, your look and a guided introduction.",icon="news"},
  {id='launcher',name='RetroRecomped',note='Intro seasons, cartridge labels, appearance and game storage.',icon='games'},
  {id='game',name='Picture & sound',note='Display, audio and defaults for every generation.',icon='speaker'},
  {id='controls',name='Controls',note='Configure the on-screen pad and its layout.',icon='games'},
  {id='cloud',name='Saves & Pokémon Bank',note='One ModCompass account. Your adventures across devices.',icon='news'},
  {id='language',name='Game language',note='Translation language and progress for your games.',icon='news'},
  {id='mods',name='Mod preferences',note='Settings provided by your installed mods.',icon='mods'},
  {id='all',name='All settings',note='Every available setting in one list.',icon='settings'},
}

function Workspace.filterRows(rows, category)
  if category=='all' then return rows end
  local result, section, currentSection = {}, nil, nil
  for _,entry in ipairs(rows) do
    if entry.kind=='section' then section=entry;currentSection=entry end
    local action=entry.action or ''
    local selected = category=='game' and (entry.scope=='game' or entry.scope=='settingsGen' or action=='clearGenOverrides')
      or category=='controls' and (entry.scope=='touch' or action=='touchLayout')
      or category=='mods' and entry.scope=='mod'
      or category=='cloud' and (currentSection and (currentSection.cloud or currentSection.label=='CLOUD SAVES' or currentSection.label=='YOUR STORAGE'))
      or category=='language' and (entry.scope=='translation' or action=='translateGame' or entry.kind=='progress')
    if selected and entry.kind~='section' then
      if section then result[#result+1]=section;section=nil end
      result[#result+1]=entry
    end
  end
  return result
end

function Workspace.install(RI)
  local U = RI._ui
  local paint = Library.paint
  local function P() return RI.palette() end

  -- Flat, consistent controls: cartridge colour and the logo own the spectacle.
  local glass=RI._glassyButton
  RI._glassyButton=function(self,x,y,w,h,value,font,enabled)
    if not self.sidebarMode then return glass(self,x,y,w,h,value,font,enabled) end
    local g,s=love.graphics,self._s
    local r={x=x,y=y,width=w,height=h}
    local hot=enabled~=false and self:_hover(r)
    paint.surface(x,y,w,h,7*s,P().link,hot)
    local label=U.ellipsize(font,Strings(value),w-20*s)
    g.setFont(font);U.col(enabled==false and P().disabledInk or P().ink)
    g.print(label,x+(w-font:getWidth(label))/2,y+(h-font:getHeight())/2)
    return enabled~=false and r or nil
  end

  local chip=RI._chipButton
  RI._chipButton=function(self,x,y,value,opts)
    if not self.sidebarMode then return chip(self,x,y,value,opts) end
    opts=opts or {}
    local s,g,p=self._s,love.graphics,P()
    local font=opts.font or self.hintFont
    local label=Strings(value)
    local w=opts.w or (font:getWidth(label)+2*(opts.padX or 12*s))
    local h=opts.h or (font:getHeight()+10*s)
    local r={x=x,y=y,width=w,height=h,id=opts.id,pinned=opts.pinned}
    local hot=self:_hover(r)
    local danger=opts.kind=='danger' or opts.kind=='dangerArmed'
    local accent=danger and p.chooseTop or opts.kind=='accent' and p.link or p.cardBorder
    local filled=opts.kind=='dangerArmed'
    U.col(accent,filled and 0.9 or hot and 0.2 or 0.09)
    g.rectangle('fill',x,y,w,h,7*s,7*s)
    U.col(accent,hot and 0.85 or 0.4);g.setLineWidth(1)
    g.rectangle('line',x,y,w,h,7*s,7*s)
    local ink=filled and p.white or opts.kind=='accent' and p.link or danger and p.chooseTop or p.detail
    label=U.ellipsize(font,label,w-12*s)
    g.setFont(font);U.col(ink)
    g.print(label,x+(w-font:getWidth(label))/2,y+(h-font:getHeight())/2)
    return r
  end

  local play=RI._playButton
  RI._playButton=function(self,x,y,w,h,name,ready,locked)
    if not self.sidebarMode then return play(self,x,y,w,h,name,ready,locked) end
    if self._libraryDetailsBody then self.playButtonRect=nil;return end
    local s,g,p=self._s,love.graphics,P()
    local r={x=x,y=y,width=w,height=h}
    local hot=ready and self:_hover(r)
    U.col(ready and (hot and p.playBot or p.playTop) or p.cardBlue)
    g.rectangle('fill',x,y,w,h,9*s,9*s)
    local value=ready and Strings('PLAY CARTRIDGE') or Strings(locked and 'COMING SOON' or 'IMPORT A ROM TO PLAY')
    local font=self.stateFont
    value=U.ellipsize(font,value,w-32*s)
    g.setFont(font);U.col(ready and p.playInk or p.disabledInk)
    g.print(value,x+(w-font:getWidth(value))/2,y+(h-font:getHeight())/2)
    self.playButtonRect=ready and r or nil
  end

  -- The tools hub is grouped by the thing the player wants to do.
  local tools=RI._sbTools
  RI._sbTools=function(self,x,y,w,h)
    if self.toolFlow then return tools(self,x,y,w,h) end
    local top,s,g=y,self._s,love.graphics
    local groups={
      {name='YOUR SAVES',ids={save=true,saveImport=true,saveExport=true,restore=true,cloud=true,bank=true},icon='news'},
      {name='CREATE & CUSTOMIZE',ids={map=true,translate=true,touch=true,scrape=true,cartDesign=true},icon='tools'},
      {name='YOUR LIBRARY',ids={roms=true},icon='games'},
    }
    local used={}
    for _,group in ipairs(groups) do
      paint.label(self,group.name,x,y);y=y+30*s
      local cols=w>=630*s and 2 or 1
      local gap=14*s
      local cw=(w-gap*(cols-1))/cols
      local i=0
      for _,tool in ipairs(Sidebar.TOOLS) do
        if group.ids[tool.id] then
          local cx=x+(i%cols)*(cw+gap)
          local cy=y+math.floor(i/cols)*112*s
          local r={x=cx,y=cy,width=cw,height=98*s,tool=tool}
          paint.surface(cx,cy,cw,98*s,12*s,P().link,self:_hover(r))
          U.col(P().link);Sidebar.icon(group.icon,cx+25*s,cy+25*s,9*s,s)
          paint.text(self,self.stateFont,Strings(tool.label),cx+46*s,cy+15*s,cw-62*s)
          g.setFont(self.hintFont);U.col(P().detail)
          g.printf(Strings(tool.note),cx+18*s,cy+47*s,cw-36*s,'left')
          self._sb.tools[#self._sb.tools+1]=r
          used[tool.id]=true;i=i+1
        end
      end
      y=y+math.ceil(i/cols)*112*s+18*s
    end
    -- Any future upstream tool remains reachable even before it is grouped.
    for _,tool in ipairs(Sidebar.TOOLS) do
      if not used[tool.id] then
        local r={x=x,y=y,width=w,height=64*s,tool=tool}
        paint.surface(x,y,w,64*s,10*s,P().link,self:_hover(r))
        paint.text(self,self.stateFont,Strings(tool.label),x+18*s,y+20*s,w-36*s)
        self._sb.tools[#self._sb.tools+1]=r;y=y+76*s
      end
    end
    return y-top
  end

  local cycle=RI._cycleTab
  RI._cycleTab=function(self,delta,...)
    if not self.sidebarMode then return cycle(self,delta,...) end
    local order={'games','walker','mods','tools','news','settings'}
    if require('src.cloud.RetroCloud').signedIn() then table.insert(order,3,'tournaments') end
    local index=1
    for i,id in ipairs(order) do if id==self.section then index=i end end
    self:_sbGo(order[((index-1+delta)%#order)+1])
  end

  local go=RI._sbGo
  RI._sbGo=function(self,section,...)
    if section=='settings' then
      self._workspaceCategory=nil;self.settingsPage=nil;self.settingsScroll=0;self._settingsRowCache=nil
    end
    return go(self,section,...)
  end
  function RI:_workspaceOpenCategory(id)
    self._workspaceCategory=id
    self.settingsPage=id=='launcher' and 'launcher' or nil
    self.settingsScroll=0;self.settingsNotice=nil;self._settingsRowCache=nil
    self._workspaceCards=nil
  end

  local rows=RI._settingsRows
  RI._settingsRows=function(self,...)
    local result=rows(self,...)
    local category=self._workspaceCategory
    if not self.sidebarMode or not category or self.settingsPage then return result end
    local filtered=Workspace.filterRows(result,category)
    table.insert(filtered,1,{kind='action',label='BACK TO SETTINGS',value='BACK',action='workspaceBack'})
    if #filtered==1 then filtered[#filtered+1]={kind='section',label='',note='No options are available in this category yet.'} end
    return filtered
  end

  local action=RI._settingsAction
  RI._settingsAction=function(self,entry,...)
    if entry and (entry.action=='workspaceBack' or entry.action=='settingsBack') and self.sidebarMode then
      self._workspaceCategory=nil;self.settingsPage=nil;self.settingsScroll=0
      self._settingsRowCache=nil;return
    end
    return action(self,entry,...)
  end
  local back=RI._sbBack
  RI._sbBack=function(self,...)
    if self.section=='settings' and (self._workspaceCategory or self.settingsPage) then
      self:_settingsAction({action='workspaceBack'});return true
    end
    return back(self,...)
  end

  -- Settings starts with a map of the choices, not a hundred-row list.
  local settings=RI._drawSettingsPanel
  RI._drawSettingsPanel=function(self,x,y,w,h,paged)
    self._workspaceCards=nil
    self._workspaceIntro=nil
    if not self.sidebarMode or self._workspaceCategory or self.settingsPage then
      return settings(self,x,y,w,h,paged)
    end
    local s,g,top=self._s,love.graphics,y
    self.settingsRowRects={};self._workspaceCards={}
    paint.text(self,self.gameNameFont,Strings('Make it yours.'),x,y,w)
    y=y+48*s
    paint.text(self,self.hintFont,Strings('Your RetroRecomped preferences.'),x,y,w,P().detail)
    y=y+38*s
    local replay={x=x,y=y,width=w,height=58*s,pinned=true}
    paint.surface(x,y,w,replay.height,9*s,P().link,self:_hover(replay))
    U.col(P().link);g.polygon('fill',x+20*s,y+17*s,x+20*s,y+41*s,x+38*s,y+29*s)
    paint.text(self,self.stateFont,Strings('PLAY STARTUP INTRO'),x+54*s,y+13*s,w-70*s,P().ink)
    self._workspaceIntro=replay
    self.settingsRowRects[#self.settingsRowRects+1]={entry={kind='action',action='launcherPreviewIntro'},value=replay}
    y=y+78*s
    local seasons={{'lightning','LIGHTNING'},{'spring','SPRING'},{'summer','SUMMER'},{'autumn','HALLOWEEN'},{'winter','WINTER BELLS'}}
    local seasonCols=w>=620*s and 5 or 3
    local seasonW=(w-8*s*(seasonCols-1))/seasonCols
    for i,item in ipairs(seasons) do
      local sx=x+((i-1)%seasonCols)*(seasonW+8*s)
      local sy=y+math.floor((i-1)/seasonCols)*46*s
      local r=self:_chipButton(sx,sy,item[2],{w=seasonW,h=36*s,font=self.hintFont})
      self.settingsRowRects[#self.settingsRowRects+1]={entry={kind='action',action='launcherPreviewSeason',season=item[1]},value=r}
    end
    y=y+math.ceil(#seasons/seasonCols)*46*s+10*s
    local cols=w>=620*s and 2 or 1
    local gap=16*s
    local cw=(w-gap*(cols-1))/cols
    for i,category in ipairs(Workspace.CATEGORIES) do
      local cx=x+((i-1)%cols)*(cw+gap)
      local cy=y+math.floor((i-1)/cols)*132*s
      local r={x=cx,y=cy,width=cw,height=116*s,id=category.id,pinned=true,
        clipY=self.settingsDrawerRect and {self.settingsDrawerRect.y,self.settingsDrawerRect.y+self.settingsDrawerRect.height}}
      paint.surface(cx,cy,cw,116*s,12*s,P().link,self:_hover(r))
      U.col(P().link);Sidebar.icon(category.icon,cx+26*s,cy+26*s,10*s,s)
      paint.text(self,self.stateFont,Strings(category.name),cx+48*s,cy+17*s,cw-66*s)
      g.setFont(self.hintFont);U.col(P().detail)
      g.printf(Strings(category.note),cx+18*s,cy+54*s,cw-36*s,'left')
      self._workspaceCards[#self._workspaceCards+1]=r
    end
    return y-top+math.ceil(#Workspace.CATEGORIES/cols)*132*s
  end

  local mouse=RI._sbMousepressed
  RI._sbMousepressed=function(self,x,y)
    if self.section=='settings' then
      for _,r in ipairs(self._workspaceCards or {}) do
        if U.inside(r,x,y) then self:_workspaceOpenCategory(r.id);return true end
      end
    end
    return mouse(self,x,y)
  end
end

return Workspace
