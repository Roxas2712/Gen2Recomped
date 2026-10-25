-- The library shell shares the launcher's existing navigation and hit rects.
-- Cartridge illustrations are drawn locally, so an empty/offline library has
-- the same visual hierarchy as one with downloaded box art.
local Library = {}
local Versions = require('src.core.GameVersion')
local Strings = require('src.core.Strings')
local Sidebar = require('src.import.LauncherSidebar')
local IntroScore = require('src.import.LauncherIntroScore')

local EDITIONS = {
  red = {{242,100,94}, 'RED'}, blue = {{104,160,247}, 'BLUE'},
  yellow = {{245,207,89}, 'YELLOW'}, gold = {{224,181,96}, 'GOLD'},
  silver = {{184,201,216}, 'SILVER'}, crystal = {{126,211,225}, 'CRYSTAL'},
  prism = {{125,219,165}, 'PRISM'}, polishedcrystal = {{190,159,236}, 'POLISHED'},
  firered = {{245,147,89}, 'FIRE RED'}, emerald = {{102,210,158}, 'EMERALD'},
  platinum = {{175,181,211}, 'PLATINUM'}, heartgold = {{235,189,94}, 'HEART GOLD'},
  soulsilver = {{173,195,220}, 'SOUL SILVER'}, black = {{159,165,186}, 'BLACK'},
  white = {{223,221,211}, 'WHITE'},
}

function Library.edition(version)
  local e = EDITIONS[version]
  return e and e[1] or {164,190,204}, e and e[2] or tostring(version):upper()
end

-- Shared by the library overview and the console's game list.
function Library.grid(width, scale)
  local gap = 16 * scale
  local cols = math.max(1, math.floor((width + gap) / (196 * scale + gap)))
  return cols, (width - (cols - 1) * gap) / cols, 264 * scale, gap
end

function Library.install(RI)
  local U = RI._ui
  local col, ellipsize = U.col, U.ellipsize
  local function palette() return RI.palette() end
  local function label(self, text, x, y, color)
    love.graphics.setFont(self.labelFont)
    col(color or palette().warning)
    U.printSpaced(self.labelFont, Strings(text), x, y, 1.3 * self._s)
  end
  local function text(self, font, value, x, y, width, color)
    love.graphics.setFont(font)
    col(color or palette().ink)
    love.graphics.print(ellipsize(font, value, width), x, y)
  end
  local function surface(x, y, w, h, radius, accent, hot)
    local P, g = palette(), love.graphics
    col(P.slotBg, 0.97); g.rectangle('fill', x, y, w, h, radius, radius)
    U.fillGradRounded(x, y, w, h, radius, accent or P.cardBlue, P.cardBlue, hot and 0.16 or 0.08, 0.5)
    col(hot and (accent or P.link) or P.cardBorder, hot and 0.7 or 0.25)
    g.setLineWidth(1); g.rectangle('line', x, y, w, h, radius, radius)
  end

  -- A small, deliberately graphic cartridge, not a replacement for box art.
  local function cartridge(self,version,cx,cy,height)
    local Hardware=require('src.import.LauncherHardware')
    local w,h=Hardware.cartSize(version)
    Hardware.cartridge(self,version,cx,cy,height*w/h,height)
  end
  Library.drawCartridge=cartridge
  local function artwork(self,version,cx,cy,maxW,maxH)
    require('src.import.LauncherHardware').cartridge(self,version,cx,cy,maxW,maxH)
  end
  Library.paint={surface=surface,text=text,label=label,artwork=artwork}

  -- Open on the collection. Interrupted imports still open their recovery page.
  local new = RI.new
  RI.new = function(...)
    local self = new(...)
    for _,image in ipairs({self.gen2Logo,self.logo}) do
      if image and image.setFilter then image:setFilter('linear','linear') end
    end
    if self.launcher then
      local opts=self:_settings()
      if opts.launcherLayout=='classic' or opts.launcherClassic==true then
        opts.launcherLayout='sidebar';opts.launcherClassic=nil
        pcall(require('src.core.SaveData').saveOptions,opts)
      end
      self.sidebarMode=true
    end
    if self.sidebarMode and not self.interruptedImport then
      self.section = 'games'
      self._newsPending, self._newsDrawn = nil, nil
    end
    return self
  end

  function RI:_sbDrawTopBar(x, y, w, s)
    local P, g = palette(), love.graphics
    local h = 80 * s
    col(P.bgBot, 0.98); g.rectangle('fill', x, y, w, h)
    col(P.cardBorder, 0.22); g.rectangle('fill', x, y + h - 1, w, 1)
    local logo = self.gen2Logo or self.logo
    local intro=self._launcherSequence
    if intro and intro.kind=='intro' and intro.elapsed<IntroScore.place then logo=nil end
    if logo then
      local lw, lh = logo:getDimensions()
      local sc = math.min(218*s/lw, 62*s/lh, (w-40*s)/lw)
      g.setColor(1,1,1,1)
      g.draw(logo,x+20*s,y+(h-lh*sc)/2,0,sc,sc)
    end
    if w > 690*s then
      label(self, 'YOUR GAMES. YOUR JOURNEY STARTS NOW.', x+278*s, y+34*s)
      text(self,self.hintFont,'GB / GBC / GBA / DS',x+w-180*s,y+34*s,160*s,P.link)
    end
    return h
  end

  function RI:_sbDrawRail(x, y, w, h, s, compact)
    local P, g = palette(), love.graphics
    self._sb = {nav = {}}
    self._sbContentRect = {x=x+w, y=y, w=math.max(1,g.getWidth()-x-w), h=h}
    col(P.bgBot, 0.97); g.rectangle('fill', x,y,w,h)
    col(P.cardBorder,0.2); g.rectangle('fill',x+w-1,y,1,h)
    local cy = y + 16*s
    local rowH = 50*s
    local navigation = {Sidebar.SECTIONS[2], Sidebar.SECTIONS[3], Sidebar.SECTIONS[4],
      Sidebar.SECTIONS[5], Sidebar.SECTIONS[1], Sidebar.SECTIONS[6]}
    local groups = {[1]='PLAY', [3]='MAKE IT YOURS', [5]='SYSTEM'}
    for i, sec in ipairs(navigation) do
      if not compact and groups[i] then
        label(self,groups[i],x+22*s,cy+5*s)
        cy=cy+28*s
      end
      local r={x=x+12*s,y=cy,width=w-24*s,height=42*s,pinned=true,id=sec.id}
      local on, hot = self.section==sec.id, self:_hover(r)
      if on or hot then
        col(on and P.link or P.white, on and 0.13 or 0.04)
        g.rectangle('fill',r.x,r.y,r.width,r.height,8*s,8*s)
      end
      col(on and P.link or P.warning)
      Sidebar.icon(sec.id,compact and x+w/2 or x+32*s,cy+21*s,9*s,s)
      if not compact then
        local name = sec.id=='games' and 'Library' or sec.label
        text(self,self.tabLabelFont,Strings(name),x+54*s,cy+(42*s-self.tabLabelFont:getHeight())/2,w-72*s,on and P.link or P.detail)
        if on then col(P.link); g.circle('fill',x+w-25*s,cy+21*s,2.5*s) end
      end
      self._sb.nav[#self._sb.nav+1]=r
      cy=cy+rowH
    end
    self._sbRail={x=x,y=y,w=w,h=h,compact=compact,navBottom=cy}
    if not compact and h > 470*s then
      local n,total=0,0
      for _,v in ipairs(Versions.ORDER) do total=total+1; if self.ready[v] then n=n+1 end end
      local by=y+h-52*s
      col(P.link); g.circle('fill',x+25*s,by+8*s,3*s)
      text(self,self.readyFont,Strings('%d of %d games ready',n,total),x+36*s,by,w-50*s,P.detail)
      col(P.cardBorder,0.2); g.rectangle('fill',x+22*s,by+24*s,w-44*s,3*s,1,1)
      if n>0 then col(P.link,0.7);g.rectangle('fill',x+22*s,by+24*s,(w-44*s)*n/math.max(1,total),3*s,1,1) end
    end
  end

  function RI:_sbDrawRailFoot()
    -- The upstream sponsor code is not a RetroRecomped promotion.
    self.tiltRipsButton=nil
  end

  local function featured(self)
    for _,r in ipairs(Sidebar.recent(self:_settings())) do if self.ready[r.v] then return r.v end end
    return self:_sbLastSaved()
  end

  -- A resume hero that also has a useful first-run state.
  function RI:_sbContinueCard(x,y,w)
    local s,P,g=self._s,palette(),love.graphics
    local v=featured(self)
    local artVersion=v or 'crystal'
    local accent=Library.edition(artVersion)
    local wide=w>=540*s
    local artW=wide and math.min(w*0.31,220*s) or 0
    local tx,tw=x+24*s,w-artW-48*s
    local title=v and Sidebar.nameOf(v) or Strings('Small cartridges.\nBig adventures.')
    local _,lines=self.gameNameFont:getWrap(title,tw)
    local titleH=math.min(#lines,2)*self.gameNameFont:getHeight()
    local h=math.max((wide and 190 or 220)*s,57*s+titleH+self.hintFont:getHeight()+20*s+64*s)
    surface(x,y,w,h,16*s,accent,false)
    if wide then
      col(accent,0.09);g.circle('fill',x+w-artW/2,y+h/2,90*s)
      artwork(self,artVersion,x+w-artW/2-8*s,y+h/2,artW-24*s,h-38*s)
    end
    label(self,v and 'CONTINUE YOUR JOURNEY' or 'YOUR NEXT ADVENTURE',tx,y+24*s,accent)
    g.setFont(self.gameNameFont);col(P.ink)
    for i=1,math.min(#lines,2) do
      g.print(ellipsize(self.gameNameFont,lines[i],tw),tx,y+49*s+(i-1)*self.gameNameFont:getHeight())
    end
    local row=v and Sidebar.activeSlotRow(v)
    local detail=row and (tostring(row.label or row.name or Strings('NEW GAME'))..(row.meta and ('  /  '..Sidebar.metaText(row.meta)) or ''))
      or (v and Strings('Ready when you are.') or Strings('Bring your games. Make yourself at home.'))
    text(self,self.hintFont,detail,tx,y+57*s+titleH,tw,P.detail)
    local by=y+h-64*s
    local bw=math.min(tw,186*s)
    if v then
      local r={x=tx,y=by,width=bw,height=42*s,version=v}
      local hot=self:_hover(r)
      col(hot and P.playBot or P.playTop); g.rectangle('fill',tx,by,bw,42*s,8*s,8*s)
      text(self,self.stateFont,Strings('CONTINUE') .. '  >',tx+18*s,by+(42*s-self.stateFont:getHeight())/2,bw-36*s,P.playInk)
      self._sb.continue=r
    else
      local r=self:_chipButton(tx,by,'IMPORT ROMS',{w=bw,h=42*s,kind='accent'})
      if r then self._sb.importButtons[#self._sb.importButtons+1]=r end
    end
    return h+26*s
  end

  local originalTile = RI._sbGameTile
  function RI:_sbGameTile(version,x,y,w,h)
    if h < 190 * self._s then return originalTile(self,version,x,y,w,h) end
    local s,P,g=self._s,palette(),love.graphics
    local info=Versions.info(version)
    local locked=not info or (info.importable==false and not (U.unlockedByEnv and U.unlockedByEnv(version)))
    local ready=not locked and self.ready[version]
    local accent=Library.edition(version)
    local r={x=x,y=y,width=w,height=h,version=version}
    local hot=self:_hover(r)
    surface(x,y,w,h,12*s,accent,hot)
    local stageH=math.max(40*s,h-88*s)
    artwork(self,version,x+w/2,y+stageH/2+4*s,w-42*s,stageH-28*s)
    col(P.cardBorder,0.18);g.line(x+16*s,y+stageH,x+w-16*s,y+stageH)
    local short=Sidebar.consoleOf(version):upper()
    label(self,short,x+16*s,y+stageH+10*s,accent)
    text(self,self.stateFont,Sidebar.nameOf(version),x+16*s,y+stageH+29*s,w-32*s)
    local status=locked and 'COMING SOON' or ready and 'READY TO PLAY' or 'ROM REQUIRED'
    if info and info.experimental and not locked then status=ready and 'BETA / READY' or 'BETA / ROM REQUIRED' end
    col(ready and P.green or P.warning);g.circle('fill',x+19*s,y+h-17*s,2.5*s)
    text(self,self.warningFont,Strings(status),x+27*s,y+h-23*s,w-42*s,ready and P.green or P.warning)
    local st={x=x+w-38*s,y=y+8*s,width=30*s,height=30*s,version=version,star=true}
    local fav=Sidebar.isFavorite(self:_settings(),version)
    col(P.bgBot,0.85);g.rectangle('fill',st.x,st.y,st.width,st.height,8*s,8*s)
    col(fav and P.gold or P.detail,fav and 1 or 0.7)
    Sidebar.icon(fav and 'star' or 'starOff',st.x+15*s,st.y+15*s,8*s,s)
    self._sb.stars[#self._sb.stars+1]=st
    return r
  end

  local mouse = RI._sbMousepressed
  RI._sbMousepressed = function(self,x,y)
    if self.section=='games' and self.gamesView=='consoles' then
      if U.inside(self._sb.logoCards,x,y) then
        local SaveData=require('src.core.SaveData')
        local opts=SaveData.loadOptions();opts.launcherLogoCards=not opts.launcherLogoCards
        SaveData.saveOptions(opts);self._settingsCache=nil;return true
      end
      for _,r in ipairs(self._sb.consoles or {}) do
        if U.inside(r,x,y) then
          self.libraryConsole=r.console
          self.pageScroll=0
          return true
        end
      end
      for _,r in ipairs(self._sb.libraryFilters or {}) do
        if U.inside(r,x,y) then self.libraryFilter=r.filter;self.pageScroll=0;return true end
      end
    end
    return mouse(self,x,y)
  end
  local back = RI._sbBack
  RI._sbBack = function(self,...)
    if self.section=='games' and self.gamesView~='consoles' then
      self.gamesView='consoles';self.pageScroll=0;return true
    end
    return back(self,...)
  end

  local originalGames=RI._sbGames
  function RI:_sbGames(x,y,w,h)
    if self.gamesView~='consoles' and self.gamesView~='list' then return originalGames(self,x,y,w,h) end
    local s,P,g=self._s,palette(),love.graphics
    local top=y
    local list
    if self.gamesView=='consoles' then
      y=y+self:_sbContinueCard(x,y,w)
      label(self,'BROWSE BY SYSTEM',x,y)
      y=y+28*s
      local cols=w>=620*s and 5 or 2
      local gap=10*s
      local cw=(w-gap*(cols-1))/cols
      local systems={{id=false,short='ALL GAMES'}}
      for _,c in ipairs(Sidebar.CONSOLES) do systems[#systems+1]=c end
      for i,c in ipairs(systems) do
        local cx=x+((i-1)%cols)*(cw+gap)
        local cy=y+math.floor((i-1)/cols)*(70*s+gap)
        local r={x=cx,y=cy,width=cw,height=70*s,console=c.id}
        local selected=(self.libraryConsole or false)==c.id
        surface(cx,cy,cw,70*s,10*s,P.link,selected or self:_hover(r))
        text(self,self.stateFont,c.short,cx+14*s,cy+12*s,cw-(c.id and 77 or 28)*s,P.ink)
        if c.id then
          local iconH=(c.id=='gba' and 28 or 46)*s
          require('src.import.LauncherHardware').symbol(self,c.id,cx+cw-35*s,cy+35*s,iconH)
        end
        local n,total=0,0
        for _,v in ipairs(Sidebar.gamesFor(c.id or nil)) do total=total+1;if self.ready[v] then n=n+1 end end
        text(self,self.warningFont,Strings('%d / %d ready',n,total),cx+14*s,cy+40*s,cw-(c.id and 70 or 28)*s,P.warning)
        self._sb.consoles[#self._sb.consoles+1]=r
      end
      y=y+math.ceil(#systems/cols)*(70*s+gap)+22*s
      label(self,'THE COLLECTION',x,y)
      local caption=Strings('LOGO LABELS')
      local toggleW=self.hintFont:getWidth(caption)+30*s
      local toggle={x=x+w-toggleW,y=y-4*s,width=toggleW,height=24*s}
      local checked=self:_settings().launcherLogoCards
      col(checked and P.link or P.cardBorder,0.8);g.setLineWidth(1)
      g.rectangle('line',toggle.x,toggle.y+3*s,16*s,16*s,3*s,3*s)
      if checked then g.line(toggle.x+3*s,toggle.y+11*s,toggle.x+7*s,toggle.y+15*s,toggle.x+13*s,toggle.y+7*s) end
      text(self,self.hintFont,caption,toggle.x+24*s,toggle.y+4*s,toggleW-24*s,checked and P.link or P.detail)
      self._sb.logoCards=toggle
      y=y+26*s
      self._sb.libraryFilters={}
      local fx=x
      for _,f in ipairs({{'all','All cartridges'},{'ready','Ready to play'},{'favorites','Favorites'}}) do
        local title=Strings(f[2])
        local fw=self.hintFont:getWidth(title)+24*s
        if fx+fw>x+w then fx=x;y=y+38*s end
        local r=self:_chipButton(fx,y,title,{w=fw,h=30*s,kind=(self.libraryFilter or 'all')==f[1] and 'accent' or 'neutral'})
        r.filter=f[1];self._sb.libraryFilters[#self._sb.libraryFilters+1]=r
        fx=fx+fw+8*s
      end
      y=y+46*s
      -- Stable groups: favourites, imported games, then the rest of the registry.
      list={}
      local opts=self:_settings()
      for group=1,3 do
        for _,v in ipairs(Sidebar.gamesFor(self.libraryConsole or nil)) do
          local fav=Sidebar.isFavorite(opts,v)
          local rank=fav and 1 or self.ready[v] and 2 or 3
          local show=self.libraryFilter=='ready' and self.ready[v]
            or self.libraryFilter=='favorites' and fav
            or (self.libraryFilter~='ready' and self.libraryFilter~='favorites')
          if rank==group and show then list[#list+1]=v end
        end
      end
    else list=Sidebar.gamesFor(self.browseConsole,self.browseSeries) end
    if #list==0 then
      text(self,self.stateFont,Strings('No cartridges in this view.'),x,y,w,P.detail)
      return y-top+64*s
    end
    local cols,cw,ch,gap=Library.grid(w,s)
    for i,v in ipairs(list) do
      local cx=x+((i-1)%cols)*(cw+gap)
      local cy=y+math.floor((i-1)/cols)*(ch+gap)
      self._sb.tiles[#self._sb.tiles+1]=self:_sbGameTile(v,cx,cy,cw,ch)
    end
    return y-top+math.ceil(#list/cols)*(ch+gap)
  end
end

return Library
