local function L(value) return require('src.translation.Service').launcherLookup(value) end
-- Catalogue presentation uses publisher previews when available, and local
-- category illustrations otherwise. Illustrations never imply gameplay proof.
local M={}
local Targets=require('src.mods.ModTargets')
local Version=require('src.core.GameVersion')
local Index=require('src.mods.ModIndex')
local Search=require('src.mods.ModSearch')
function M.scope(entry)
  local seen,out={},{}
  for _,id in ipairs(Targets.normalize(entry.games or {})) do seen[Version.generation(id)]=true end
  for _,n in ipairs(entry.supportedGens or entry.gens or {}) do if type(n)=='number' then seen[n]=true end end
  for n=1,5 do if seen[n] then out[#out+1]='GEN '..n end end
  if #out>0 then return table.concat(out,' / ') end
  for _,claim in ipairs(entry.compatibility or {}) do
    if type(claim)=='table' and claim.engine=='g1r' then return 'GEN 1 · DECLARED FOR GEN1RECOMP' end
  end
  return 'GENERATION NOT DECLARED'
end
function M.sections(mods,rows,filters)
  local installed,available,byId,byRepo={},{},{},{}
  for _,mod in ipairs(mods or {}) do
    byId[mod.id]=mod
    if mod.github then byRepo[mod.github:lower()]=mod end
  end
  local emitted={}
  for _,entry in ipairs(rows or {}) do
    local mod=byId[entry.id] or (entry.github and byRepo[entry.github:lower()])
    if mod then
      if not emitted[mod.id] then installed[#installed+1]={entry=entry,mod=mod};emitted[mod.id]=true end
      byId[mod.id]=nil
    else available[#available+1]={entry=entry} end
  end
  -- Locally imported mods remain visible even without a catalogue listing.
  local leftovers={};for _,mod in pairs(byId) do leftovers[#leftovers+1]=mod end
  table.sort(leftovers,function(a,b)return (a.name or a.id)<(b.name or b.id) end)
  for _,mod in ipairs(leftovers) do local entry={id=mod.id,title=mod.name or mod.id,
    version=mod.version,summary=mod.description or '',games=mod.games,supportedGens=mod.supportedGens,
    categories=mod.tags or {}}
    if #Search.filter({entry},filters or {})>0 then installed[#installed+1]={mod=mod,entry=entry} end
  end
  return installed,available
end
local styles={
  {key='audio',color={.95,.50,.67},icon='wave',label='SOUND & MUSIC'},
  {key='grafik',color={.60,.56,1},icon='cube',label='GRAPHICS & 3D'},
  {key='oberfl',color={.32,.76,1},icon='dex',label='INTERFACE'},
  {key='inhalte',color={.46,.88,.68},icon='map',label='NEW ADVENTURES'},
  {key='erkund',color={.41,.83,.73},icon='map',label='EXPLORATION'},
  {key='schwierig',color={1,.57,.31},icon='battle',label='CHALLENGE'},
  {key='balance',color={1,.74,.35},icon='battle',label='BALANCE'},
  {key='komfort',color={.35,.83,.91},icon='pad',label='QUALITY OF LIFE'},
}
function M.style(entry)
  local category=table.concat(entry.categories or {},' '):lower()
  for _,style in ipairs(styles) do if category:find(style.key,1,true) then return style end end
  return {color={.46,.68,1},icon='pad',label='GAMEPLAY & TOOLS'}
end
-- Resolution independent cover art, deliberately distinct from screenshots.
function M.cover(self,entry,x,y,w,h,opacity)
  local g,s=love.graphics,M.style(entry)
  local c=s.color;opacity=opacity or 1
  g.push('all')
  if g.intersectScissor then g.intersectScissor(x,y,w,h) end
  for i=0,23 do
    local t=i/23;g.setColor(c[1]*(.15+.2*t),c[2]*(.15+.2*t),c[3]*(.15+.2*t),opacity)
    g.rectangle('fill',x,y+h*i/24,w,h/24+1)
  end
  g.setColor(c[1],c[2],c[3],.15*opacity);g.setLineWidth(1)
  for i=-3,10 do g.line(x+i*w/8,y+h,x+i*w/8+w*.4,y) end
  for i=1,5 do g.line(x,y+h*i/6,x+w,y+h*i/6) end
  local image=self:_findThumb(entry)
  if image then
    local iw,ih=image:getDimensions();local fit=math.min(w/iw,h/ih)
    g.setColor(1,1,1,opacity);g.draw(image,x+(w-iw*fit)/2,y+(h-ih*fit)/2,0,fit,fit)
  else
    g.push();g.translate(x+w*.72,y+h*.48);local u=math.min(w*.24,h*.38);g.scale(u,u)
    g.setColor(c[1],c[2],c[3],.9*opacity);g.setLineWidth(.045)
    if s.icon=='wave' then
      for i=-6,6 do local a=.18+.62*math.abs(math.sin(i*1.8));g.rectangle('fill',i*.13,-a/2,.065,a,.03,.03) end
    elseif s.icon=='cube' then
      g.polygon('line',0,-.8,.75,-.4,.75,.45,0,.85,-.75,.45,-.75,-.4)
      g.line(-.75,-.4,0,0,.75,-.4);g.line(0,0,0,.85);g.line(0,-.8,0,0)
    elseif s.icon=='dex' then
      g.rectangle('line',-.65,-.78,1.3,1.56,.12,.12);g.circle('line',-.32,-.46,.14)
      g.rectangle('line',-.42,-.15,.84,.55,.04,.04);g.line(-.4,.59,.1,.59)
    elseif s.icon=='map' then
      g.polygon('line',-.85,-.6,-.27,-.8,.28,-.56,.86,-.76,.86,.6,.28,.8,-.27,.56,-.85,.76)
      g.line(-.27,-.8,-.27,.56);g.line(.28,-.56,.28,.8);g.circle('fill',.35,-.1,.11)
    elseif s.icon=='battle' then
      g.polygon('fill',.14,-.9,-.6,.15,-.12,.15,-.25,.9,.65,-.25,.13,-.25)
    else
      g.rectangle('line',-.85,-.5,1.7,1,.3,.3);g.line(-.6,0,-.14,0);g.line(-.37,-.23,-.37,.23)
      g.circle('fill',.36,.14,.09);g.circle('fill',.59,-.11,.09)
    end
    g.pop()
    if w>180*self._s then
      g.setFont(self.hintFont);g.setColor(c[1],c[2],c[3],opacity)
      g.print('RETRO / COMMUNITY',x+14*self._s,y+14*self._s)
      g.setFont(self.stateFont);g.printf(L(s.label),x+14*self._s,y+h-self.stateFont:getHeight()-16*self._s,w*.58,'left')
    end
  end
  g.pop()
end
function M.install(RI)
  local U=RI._ui
  local legacy=RI._drawModsPanel
  local toolbar=RI._sbModToolbar
  function RI:_findRows()
    local revision=require('src.import.LauncherCommunity').catalogueRevision
    local cached=self._catalogSearch
    if cached and cached.index==self.findIndex and cached.query==self.findQuery and cached.category==self.findCategory
      and cached.generation==self.catalogGeneration and cached.revision==revision then return cached.rows,cached.approximate end
    local rows,approximate=Search.filter(self.findIndex and self.findIndex.mods or {},{query=self.findQuery,category=self.findCategory,generation=self.catalogGeneration})
    self._catalogSearch={index=self.findIndex,query=self.findQuery,category=self.findCategory,generation=self.catalogGeneration,revision=revision,rows=rows,approximate=approximate}
    return rows,approximate
  end
  RI._sbModToolbar=function(self,...) if self._catalogManage then return toolbar(self,...) end;return 0 end
  local selectTab=RI._selectTab
  RI._selectTab=function(self,tab,...)
    self._catalogActions={};self._catalogViewport=nil;self._communityLinks={};self._communityWeekRect=nil
    if tab=='mods' and not require('src.cloud.RetroCloud').signedIn() then self._catalogManage=true
    elseif tab=='mods' and not self._catalogManage then tab='find' end
    return selectTab(self,tab,...)
  end
  local function draw(self,x,y,w,h,paged)
    if self._catalogManage and self.tab=='mods' then return legacy(self,x,y,w,h,paged) end
    local cx,cy,cw,ch=love.graphics.getScissor()
    self._catalogViewport={x=cx or x,y=cy or y,width=cw or w,height=ch or h}
    if not require('src.cloud.RetroCloud').signedIn() then
      local s,P,g=self._s,RI.palette(),love.graphics
      self._catalogActions={};self._communityLinks={};self._communityWeekRect=nil
      self.findInstallRects={};self.findDetailRects={};self.findRepoRects={};self.findSearchRect=nil
      self._findDetails=nil;self._findSearchFocus=false
      local top=y;g.setFont(self.stateFont or self.hintFont);U.col(P.ink)
      g.printf('YOUR LOCAL MODS. YOUR CHOICE.',x,y,w,'left');y=y+46*s
      g.setFont(self.hintFont);U.col(P.detail)
      local message='Play and manually import compatible mod ZIPs without an account. Existing mods can receive updates from their saved GitHub repositories. Sign in or register to browse and install new mods online; this links this device to your ModCompass account.'
      local _,lines=self.hintFont:getWrap(message,w);g.printf(message,x,y,w,'left');y=y+math.max(1,#lines)*self.hintFont:getHeight()+20*s
      for _,row in ipairs({{'account','SIGN IN / REGISTER · OPEN MOD BROWSER'},{'manage','INSTALLED MODS · IMPORT ZIP / FOLDER'}}) do
        local r=self:_chipButton(x,y,row[2],{w=w,h=44*s,kind='accent'});r.action=row[1];self._catalogActions[#self._catalogActions+1]=r;y=y+54*s
      end
      return y-top
    end
    self:_ensureMods();self:_ensureFind()
    self._catalogActions={};self._communityLinks={};self._communityWeekRect=nil
    self.findInstallRects={};self.findDetailRects={};self.findRepoRects={};self.findSourceRemoveRects={};self.findCatRects={}
    self.modRows={};self.modImportRect=nil;self.findAddRect=nil;self.findRefreshRect=nil
    local g,s,P=love.graphics,self._s,RI.palette();local top=y
    local fh=self.hintFont:getHeight()
    local _,clipY,_,clipH=g.getScissor()
    local visibleTop,visibleBottom=clipY or y,clipY and (clipY+clipH) or (y+h)
    local function text(value,xx,yy,width,font,color)
      g.setFont(font or self.hintFont);U.col(color or P.detail)
      g.print(U.ellipsize(g.getFont(),L(value),width),xx,yy)
    end
    local function action(id,label,xx,yy,ww,entry)
      local r=self:_chipButton(xx,yy,label,{w=ww,h=36*s,kind=id=='install' and 'accent' or 'neutral'})
      r.action=id;r.entry=entry;self._catalogActions[#self._catalogActions+1]=r;return r
    end
    local fieldH=38*s
    U.col(P.bgBot,.9);g.rectangle('fill',x,y,w,fieldH,8*s,8*s)
    U.col(P.cardBorder,.6);g.rectangle('line',x,y,w,fieldH,8*s,8*s)
    text((self.findQuery or '')..(self._findSearchFocus and '|' or ''),x+12*s,y+9*s,w-24*s)
    if (self.findQuery or '')=='' and not self._findSearchFocus then text('Search mods, descriptions and tags…',x+12*s,y+9*s,w-24*s) end
    self.findSearchRect={x=x,y=y,width=w-44*s,height=fieldH}
    action('clear','×',x+w-38*s,y+1*s,36*s)
    y=y+fieldH+10*s
    local compact=w<600*s
    local gx=x
    if compact and not self._catalogGenerations then
      action('generations',self.catalogGeneration and ('Generation · '..self.catalogGeneration) or 'All generations',x,y,math.min(w,164*s))
      y=y+44*s
    else
    for gen=0,5 do
      local label=gen==0 and 'All generations' or ('Gen '..gen)
      local bw=self.hintFont:getWidth(L(label))+22*s
      if gx+bw>x+w then gx=x;y=y+40*s end
      local r=action('generation',label,gx,y,bw)
      r.generation=gen>0 and gen or nil
      if self.catalogGeneration==r.generation then U.col(P.link,.65);g.rectangle('line',r.x,r.y,r.width,r.height,8*s,8*s) end
      gx=gx+bw+6*s
    end
    y=y+48*s
    end
    local bx=x
    local actions={{'categories','Categories',120},{'account','Account',100},{'developer','Developer',120},{'manage','Manage installed',164},{'refresh','Refresh',100}}
    if compact then
      if self._catalogOptions then table.insert(actions,1,{'options','Less options',120})
      else actions={{'categories','Categories',120},{'options','More…',92}} end
    end
    for _,a in ipairs(actions) do
      local bw=math.min(w,math.max(a[3]*s,self.hintFont:getWidth(L(a[2]))+28*s));if bx+bw>x+w then bx=x;y=y+44*s end
      action(a[1],a[2],bx,y,bw);bx=bx+bw+8*s
    end
    y=y+48*s
    local Presentation=require('src.import.LauncherPresentation')
    local week=Presentation.week(self)
    local weeklyEntry
    if week then for _,entry in ipairs(self.findIndex.mods or {}) do if entry.catalogueId==week.catalogue_id then
      self:_findThumb(entry)
      if require('src.import.LauncherCommunity').weekCompatible(entry) then
        weeklyEntry=entry
      end;break
    end end end
    local cx=x;local chipH=30*s
    if self._catalogCategories then
    local cats={''};for _,cat in ipairs(self.findIndex and self.findIndex.categories or {}) do cats[#cats+1]=cat end
    for _,cat in ipairs(cats) do
      local label=cat=='' and 'All' or cat;local bw=math.min(w,self.hintFont:getWidth(label)+20*s)
      if cx+bw>x+w then cx=x;y=y+chipH+6*s end
      local r=self:_chipButton(cx,y,label,{w=bw,h=chipH,kind=(self.findCategory or '')==cat and 'accent' or 'neutral'})
      r.id=cat;self.findCatRects[#self.findCatRects+1]=r;cx=cx+bw+6*s
    end
    y=y+chipH+20*s
    end
    local filtered,approximate=self:_findRows();approximate=approximate or 0
    text(L('%d results'):format(#filtered)..(approximate>0 and (' · '..L('%d similar spelling'):format(approximate)) or ''),x,y,w,self.hintFont,P.warning);y=y+fh+12*s
    local installed,available=M.sections(self.mods,filtered,{query=self.findQuery,category=self.findCategory,generation=self.catalogGeneration})
    -- Placement buttons only open their disclosed destination when clicked.
    -- They cannot install mods, inject code or change the catalogue search.
    for _,item in ipairs(Presentation.items(self)) do
      local ph=110*s
      if y+ph>=visibleTop and y<visibleBottom then
        U.roundedCard(x,y,w,ph,12*s)
        local image=item.thumbnail and self:_findThumb(item)
        local offset=14*s
        if image and w>=520*s then
          local iw,ih=image:getDimensions();local scale=math.min(145*s/iw,82*s/ih)
          U.col(P.ink);g.draw(image,x+14*s+(145*s-iw*scale)/2,y+14*s+(82*s-ih*scale)/2,0,scale,scale)
          offset=174*s
        end
        local tw=math.max(40*s,w-offset-110*s)
        text(item.kind=='promotion' and 'PROMOTION · MODCOMPASS' or 'MODCOMPASS ANNOUNCEMENT',x+offset,y+12*s,tw,self.hintFont,P.link)
        text(item.title,x+offset,y+36*s,tw,self.stateFont,P.ink)
        text(item.description,x+offset,y+70*s,tw)
        local r=action('placement','Open ↗',x+w-96*s,y+37*s,82*s,item)
        r.url=item.url
      end
      y=y+ph+14*s
    end
    for i,row in ipairs(available) do if row.entry==weeklyEntry then table.remove(available,i);table.insert(available,1,row);break end end
    local cols=math.max(1,math.floor((w+16*s)/(280*s+16*s)))
    local gap=16*s;local cw=(w-(cols-1)*gap)/cols
    local coverH=cw*.49
    local cardH=coverH+170*s+fh*2
    local function section(title,rows,owned)
      text(L(title)..'  /  '..#rows,x,y,w,self.stateFont,owned and P.green or P.ink);y=y+self.stateFont:getHeight()+14*s
      if #rows==0 then
        text(owned and 'Your installed mods appear here. Discover your next one below.' or (self._communityFindJob and 'Loading the public catalogue…' or self.findNotice and not self.findNotice.ok and 'Catalogue unavailable. Retry to load the mod cards.' or 'No matching mods. Try another search or refresh.'),x,y,w)
        y=y+fh+18*s;return
      end
      if owned then
        local ncols=math.max(1,math.floor((w+gap)/(420*s+gap)))
        local iw=(w-(ncols-1)*gap)/ncols;local ih=112*s
        for i,row in ipairs(rows) do
          local xx=x+((i-1)%ncols)*(iw+gap);local yy=y+math.floor((i-1)/ncols)*(ih+gap)
          if yy+ih>=visibleTop and yy<visibleBottom then
            U.roundedCard(xx,yy,iw,ih,12*s)
            local aw=math.min(112*s,iw*.28)
            M.cover(self,row.entry,xx,yy,aw,ih,1)
            U.col(P.green,.9);g.rectangle('fill',xx,yy+ih-3*s,iw,3*s)
            text(row.entry.title or row.entry.id,xx+aw+12*s,yy+12*s,iw-aw-26*s,self.stateFont,P.ink)
            text(M.scope(row.entry),xx+aw+12*s,yy+40*s,iw-aw-26*s,self.hintFont,P.link)
            local update=self.modUpdateInfo and self.modUpdateInfo[row.mod.id]
            if update and update.status=='available' then
              local pulse=.45+.35*(.5+.5*math.sin((self.pulse or 0)*4))
              U.col(P.red,pulse);g.setLineWidth(2*s);g.rectangle('line',xx,yy,iw,ih,12*s,12*s)
              g.setLineWidth(1)
              text('UPDATE '..tostring(update.latest or ''),xx+aw+12*s,yy+76*s,iw-aw-126*s,self.hintFont,P.red)
            elseif update and update.status=='error' then text('CHECK FAILED',xx+aw+12*s,yy+76*s,iw-aw-126*s,self.hintFont,P.gold)
            else text(row.mod.enabled and 'ENABLED' or 'DISABLED',xx+aw+12*s,yy+76*s,iw-aw-126*s,self.hintFont,P.green) end
            action('manage','Manage',xx+iw-102*s,yy+ih-44*s,90*s,row.entry)
            self._catalogActions[#self._catalogActions+1]={x=xx,y=yy,width=aw,height=ih,entry=row.entry,action='preview'}
          end
        end
        y=y+math.ceil(#rows/ncols)*(ih+gap)+12*s;return
      end
      for i,row in ipairs(rows) do
        local e=row.entry;local xx=x+((i-1)%cols)*(cw+gap);local yy=y+math.floor((i-1)/cols)*(cardH+gap)
        -- Only visible cards start preview/release jobs. Page band clips hits.
        if yy+cardH>=visibleTop and yy<visibleBottom then
          local c=M.style(e).color
          U.roundedCard(xx,yy,cw,cardH,12*s)
          M.cover(self,e,xx,yy,cw,coverH,owned and 1 or .66)
          U.col(owned and P.green or c,owned and .9 or .5);g.rectangle('fill',xx,yy+coverH,cw,3*s)
          text(e==weeklyEntry and 'MOD OF THE WEEK' or 'DISCOVER',xx+14*s,yy+coverH+12*s,cw-28*s,self.hintFont,e==weeklyEntry and P.gold or P.link)
          text(e.title or e.id,xx+14*s,yy+coverH+34*s,cw-28*s,self.stateFont,P.ink)
          text(M.scope(e),xx+14*s,yy+coverH+64*s,cw-28*s,self.hintFont,P.link)
          local summary=(e.summary or ''):gsub('\n',' ');g.setFont(self.hintFont)
          local _,lines=self.hintFont:getWrap(summary,cw-28*s)
          for n=1,math.min(2,#lines) do text(lines[n],xx+14*s,yy+coverH+90*s+(n-1)*fh,cw-28*s) end
          text('v'..tostring(Index.displayVersion(e))..' · '..(e.author or 'Community'),xx+14*s,yy+cardH-78*s,cw-28*s,self.hintFont,P.warning)
          local status=require('src.import.LauncherCommunity').compatibility(e)
          text(status,xx+14*s,yy+cardH-57*s,cw-28*s,self.warningFont,status=='INCOMPATIBLE' and P.red or P.warning)
          local cover={x=xx,y=yy,width=cw,height=coverH,entry=e,action='preview'}
          self._catalogActions[#self._catalogActions+1]=cover
          local bw=(cw-36*s)/2
          action('details','Details',xx+14*s,yy+cardH-40*s,bw,e)
          local unavailable=status=='INCOMPATIBLE' or e.update_check=='off' or e.update_check=='no installable release'
          local id=owned and 'manage' or unavailable and 'source' or 'install'
          action(id,owned and 'Manage' or unavailable and 'Source ↗' or 'Install',xx+22*s+bw,yy+cardH-40*s,bw,e)
        end
      end
      y=y+math.ceil(#rows/cols)*(cardH+gap)+12*s
    end
    section('Installed',installed,true);section('Discover mods',available,false)
    if self.findNotice then
      g.setFont(self.hintFont);U.col(self.findNotice.ok and P.detail or P.red)
      local message=L(self.findNotice.text);local _,lines=self.hintFont:getWrap(message,w);g.printf(message,x,y,w,'left');y=y+#lines*fh+16*s
      if not self.findNotice.ok then action('refresh','RETRY CATALOGUE',x,y,math.min(w,260*s));y=y+48*s end
    end
    self._findMax=0;return y-top
  end
  RI._drawFindPanel=draw;RI._drawModsPanel=draw
  local update=RI.update
  RI.update=function(self,dt,...)
    if not M.startupChecked then
      self:_ensureMods();self:_syncModUpdateInfo(true)
      M.startupChecked=true;M.startupUpdates=self.modUpdateInfo
    elseif M.startupUpdates and not self.modUpdateInfo then self.modUpdateInfo=M.startupUpdates end
    return update(self,dt,...)
  end
  local play=RI.play
  RI.play=function(self,version,...)
    local ok,report=pcall(require('src.mods.LauncherMods').preflight,version)
    if not ok then report={ok=false,log='STATIC MOD CHECK FAILED\n'..tostring(report)..'\nNo game was started.'} end
    self._lastModPreflight=report
    local approved=self._preflightApproval==report.log;self._preflightApproval=nil
    if not report.ok or #(report.warnings or {})>0 and not approved then
      self._findDetails={title=report.ok and 'MOD CHECK · REVIEW NOTICES' or 'MOD CHECK · FIX BEFORE PLAY',body=report.log,scroll=0,preflight=true,continueVersion=report.ok and version or nil}
      self.modNotice={ok=false,text='The selected mod setup has problems. Open Manage installed to fix them.'}
      return
    end
    return play(self,version,...)
  end
  local press=RI._sbMousepressed
  RI._sbMousepressed=function(self,x,y,...)
    if self.section=='mods' then
      if self._sb and U.inside(self._sb.modsFind,x,y) then self._catalogManage=false;self:_selectTab('find');self.pageScroll=0;return true end
      if self._sb and U.inside(self._sb.modsInstalled,x,y) then self._catalogManage=true;self:_selectTab('mods');self.pageScroll=0;return true end
      if not self._catalogManage and self._catalogViewport and U.inside(self._catalogViewport,x,y) then
        for _,r in ipairs(self._catalogActions or {}) do if U.inside(r,x,y) then
          if r.action=='account' then self:_openAccount('browse')
          elseif r.action=='developer' then self:_openDeveloper('developer')
          elseif r.action=='manage' then self._catalogManage=true;self:_selectTab('mods');self.pageScroll=0
          elseif r.action=='refresh' then self:_refreshFind(true);self:_syncModUpdateInfo(true)
          elseif r.action=='placement' then love.system.openURL(r.url)
          elseif r.action=='details' then self:_findShowDetails(r.entry)
          elseif r.action=='generation' then self.catalogGeneration=r.generation;self._catalogGenerations=false;self.pageScroll=0
          elseif r.action=='generations' then self._catalogGenerations=not self._catalogGenerations
          elseif r.action=='options' then self._catalogOptions=not self._catalogOptions
          elseif r.action=='clear' then self.findQuery='';self.findCategory=nil;self.catalogGeneration=nil;self.pageScroll=0
          elseif r.action=='categories' then self._catalogCategories=not self._catalogCategories
          elseif r.action=='source' then if r.entry.repo then love.system.openURL(r.entry.repo) else self:_findShowDetails(r.entry) end
          elseif r.action=='preview' then self:_findShowDetails(r.entry);if self._findDetails then self._findDetails.previewExpanded=true end
          elseif r.action=='install' then self:_findConfirmInstall(r.entry) end
          return true
        end end
      end
    end
    return press(self,x,y,...)
  end
end
return M
