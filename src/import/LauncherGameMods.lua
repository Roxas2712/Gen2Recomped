-- Mods on the cartridge page, using existing catalogue/install/auth services.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={}
local Recommendations=require('src.mods.GameRecommendations')
local Versions=require('src.core.GameVersion')
local Auth=require('src.cloud.RetroCloud')
local Community=require('src.import.LauncherCommunity')
local Strings=require('src.core.Strings')
local function L(value)return require('src.translation.Service').launcherLookup(value)end
function M.current(self)
 if self.section~='games'then return end
 if self._pinOpen then return 'pinballrs'end
 if self._xyOpen then return self._xyEdition end
 if self.gamesView=='game'then return self.tab end
end
function M.install(RI)
 local U=RI._ui
 local function notice(self,value)
  self.findNotice={ok=false,text=value};self.modNotice=self.findNotice
 end
 local function draw(self,version,x,y,w)
  local s,g,P=self._s,love.graphics,RI.palette();local top=y
  local info=Versions.info(version)
  self._gameModsActions={};self._gameModsDrawn=version
  self._gameModsTop=y
  local function text(value,xx,yy,ww,font,color,raw)
   g.setFont(font or self.hintFont);U.col(color or P.detail)
   g.print(U.ellipsize(font or self.hintFont,raw and value or L(value),ww),xx,yy)
  end
  local function paragraph(value,yy,color)
   g.setFont(self.hintFont);U.col(color or P.detail)
   local _,lines=self.hintFont:getWrap(L(value),w)
   g.printf(L(value),x,yy,w,'left')
   return math.max(1,#lines)*self.hintFont:getHeight()+12*s
  end
  local _,clipY,_,clipH=g.getScissor()
  local function visible(yy,hh)return not clipY or yy+hh>=clipY and yy<clipY+clipH end
  local function action(kind,value,xx,yy,ww,entry)
   if not visible(yy,34*s)then return end
   local r=self:_chipButton(xx,yy,value,{w=ww,h=34*s,kind=kind=='install'and'accent'or'neutral'})
   r.kind=kind;r.entry=entry;r.version=version
   if clipY then r.clipY={clipY,clipY+clipH}end
   self._gameModsActions[#self._gameModsActions+1]=r
  end
  text('MODS FOR THIS GAME',x,y,w,self.stateFont,P.ink);y=y+self.stateFont:getHeight()+10*s
  if not info or info.external then
   y=y+paragraph('This native game uses a separate mod format. RPG mod recommendations do not apply here.',y)
   return y-top+12*s
  end
  self:_ensureMods()
  local signed=Auth.signedIn()
  if signed then
   if self._findNeedsLogin then self:_refreshFind(false)else self:_ensureFind()end
  end
  local index=signed and self.findIndex or nil
  local week=signed and require('src.import.LauncherPresentation').week(self)or nil
  local cache=self._gameModsCache
  local revision=Community.catalogueRevision
  if not cache or cache.version~=version or cache.mods~=self.mods or cache.index~=index
   or cache.revision~=revision or cache.week~=(week and week.catalogue_id)then
   local installed,available=Recommendations.select(version,self.mods,index,week)
   cache={version=version,mods=self.mods,index=index,revision=revision,week=week and week.catalogue_id,installed=installed,available=available}
   self._gameModsCache=cache
  end
  local installed,available=cache.installed,cache.available
  self._gameModsShown=self._gameModsShown or {}
  local shown=self._gameModsShown[version]or 3
  text(Strings('Installed for this game · %d',#installed),x,y,w,self.stateFont,P.green,true)
  y=y+self.stateFont:getHeight()+10*s
  if #installed==0 then y=y+paragraph('No mods installed for this game yet.',y)
  else
   for i=1,math.min(#installed,shown)do
    local row=installed[i];local mod=row.mod;local hh=74*s
    if visible(y,hh)then
     U.roundedCard(x,y,w,hh,10*s)
     local toggleLabel=row.enabled and'DISABLE'or'ENABLE'
     local bw=math.min(w*.42,math.max(110*s,self.hintFont:getWidth(L(toggleLabel))+24*s));local tw=w-bw-38*s
     text(mod.name or mod.id,x+12*s,y+10*s,tw,self.stateFont,P.ink,true)
     text('v'..tostring(mod.version or '?')..' · '..L(row.enabled and 'ENABLED HERE'or'DISABLED HERE'),x+12*s,y+40*s,tw,self.hintFont,row.enabled and P.green or P.warning,true)
     action('toggle',toggleLabel,x+w-bw-12*s,y+20*s,bw,mod)
    end
    y=y+hh+8*s
   end
   if #installed>shown then action('more','SHOW MORE',x,y,math.min(w,190*s));y=y+44*s end
  end
  action('manage','MANAGE INSTALLED MODS',x,y,math.min(w,260*s));y=y+54*s
  text('RECOMMENDED BEFORE YOU PLAY',x,y,w,self.stateFont,P.link);y=y+self.stateFont:getHeight()+10*s
  if not signed then
   y=y+paragraph('Sign in to see recommendations and install new mods. Local play and manual ZIP imports stay available without an account.',y)
   action('login','SIGN IN / REGISTER',x,y,math.min(w,240*s));return y-top+48*s
  end
  y=y+paragraph('Mods that declare support for your edition. A matching Mod of the Week comes first. You choose what to install and enable.',y)
  local state=self._communityDownload
  if state then
   local value=Strings(state.phase=='install'and'Installing %s…'or'Downloading %s…',state.title or state.id)
   if state.phase~='install'then value=value..string.format(' · %.1f MB',(state.bytes or 0)/1048576)end
   text(value,x,y,w-110*s,self.hintFont,P.link,true)
   action('cancel','CANCEL',x+w-math.min(w,100*s),y,math.min(w,100*s));y=y+44*s
  end
  local busy=self._communityLatestJob or self._communityDownload or self._profileApplying
  if #available==0 then
   y=y+paragraph(self._communityFindJob and'Loading recommendations…'or'No compatible recommendations available for this game.',y)
  else
   local gap=12*s;local cols=math.max(1,math.min(3,math.floor((w+gap)/(260*s+gap))))
   local cw=(w-(cols-1)*gap)/cols;local coverH=90*s
   local cardH=coverH+118*s+self.stateFont:getHeight()+2*self.hintFont:getHeight()
   for i=1,math.min(#available,shown)do
    local row=available[i];local entry=row.entry
    local xx=x+((i-1)%cols)*(cw+gap);local yy=y+math.floor((i-1)/cols)*(cardH+gap)
    if visible(yy,cardH)then
     U.roundedCard(xx,yy,cw,cardH,12*s)
     -- This also queues the existing bounded original-manifest resolution.
     require('src.import.ModCatalogue').cover(self,entry,xx,yy,cw,coverH,.8)
     text(row.weekly and'MOD OF THE WEEK'or'FOR THIS GAME',xx+12*s,yy+coverH+8*s,cw-24*s,self.hintFont,row.weekly and P.gold or P.link)
     text(entry.title or entry.id,xx+12*s,yy+coverH+30*s,cw-24*s,self.stateFont,P.ink,true)
     text(entry.summary or'',xx+12*s,yy+coverH+36*s+self.stateFont:getHeight(),cw-24*s,nil,nil,true)
     local status=Community.compatibility(entry,version)
     local badge=status=='MANIFEST MATCH'and'GAME SUPPORT DECLARED'or entry.catalogueId and not entry._communityResolved and'CHECKING COMPATIBILITY'or'COMPATIBILITY NOT VERIFIED'
     text(badge,xx+12*s,yy+cardH-86*s,cw-24*s,self.hintFont,P.warning)
     local bw=(cw-32*s)/2
     action('details','DETAILS',xx+12*s,yy+cardH-44*s,bw,entry)
     if not busy then
      action('install','INSTALL',xx+20*s+bw,yy+cardH-44*s,bw,entry)
     end
    end
   end
   y=y+math.ceil(math.min(#available,shown)/cols)*(cardH+gap)
   if #available>shown then action('more','MORE RECOMMENDATIONS',x,y,math.min(w,280*s));y=y+44*s end
  end
  if self.findNotice then y=y+paragraph(self.findNotice.text,y,self.findNotice.ok and P.detail or P.red)end
  if not self._communityFindJob then action('refresh','REFRESH RECOMMENDATIONS',x,y,math.min(w,300*s));y=y+44*s end
  return y-top+12*s
 end
 local gamePanel=RI._drawGamePanel
 RI._drawGamePanel=function(self,version,x,y,w,h,...)
  local height=gamePanel(self,version,x,y,w,h,...)or 0
  if M.current(self)==version then return height+20*self._s+draw(self,version,x,y+height+20*self._s,w)end
  return height
 end
 local content=RI._sbDrawContent
 RI._sbDrawContent=function(self,x,y,w,h,...)
  local height=content(self,x,y,w,h,...)or 0
  local version=M.current(self)
  if version and(self._xyOpen or self._pinOpen)then return height+20*self._s+draw(self,version,x,y+height+20*self._s,w)end
  return height
 end
 local update=RI.update
 RI.update=function(self,...)
  local current=M.current(self)
  if current~=self._gameModsDrawn then self._gameModsActions={}end
  self._gameModsVersion=Auth.signedIn()and current and Versions.info(current)and current or nil
  return update(self,...)
 end
 local confirm=RI._findConfirmInstall
 RI._findConfirmInstall=function(self,entry,...)
  local current=M.current(self)
  self._gameModsInstallContext=current and{version=current,entry=entry,account=Auth.accountId()}or nil
  return confirm(self,entry,...)
 end
 local install=RI._findInstall
 RI._findInstall=function(self,entry,...)
  local context=self._gameModsInstallContext
  if context and context.entry==entry then
   if not Auth.signedIn()or context.account~=Auth.accountId()or context.version~=M.current(self)then
    notice(self,'The account or selected game changed. Choose the mod again.');return
   end
   if not Recommendations.compatible(entry,context.version)then
    notice(self,'This release does not match the selected game or engine. No mod was installed.');return
   end
  end
  local before=self._communityDownload
  local result=install(self,entry,...)
  local download=self._communityDownload
  if context and context.entry==entry and download and download~=before and download.id==entry.id then
   download.gameVersion=context.version;download.gameAccount=context.account
  end
  return result
 end
 local mouse=RI._sbMousepressed
 RI._sbMousepressed=function(self,x,y,...)
  local current=M.current(self)
  if current and current==self._gameModsDrawn then
   for _,r in ipairs(self._gameModsActions or {})do if r.version==current and U.inside(r,x,y)then
    if r.kind=='login'then self:_openAccount()
    elseif r.kind=='manage'then self._catalogManage=true;self.section='mods';self:_selectTab('mods');self.pageScroll=0
    elseif r.kind=='more'then self._gameModsShown[current]=(self._gameModsShown[current]or 3)+3
    elseif r.kind=='toggle'then
     local mod=r.entry;local gen=Versions.generation(current)
     if not mod.enabled and(not mod.gens or mod.gens[gen]~=false)then self:_toggleMod(mod.id)
     else self:_toggleModGeneration(mod.id,gen)end
    elseif Auth.signedIn()then
     if r.kind=='install'then self:_findConfirmInstall(r.entry)
     elseif r.kind=='details'then self:_findShowDetails(r.entry)
     elseif r.kind=='refresh'then self:_refreshFind(true)
     elseif r.kind=='cancel'then self:_communityCancelDownload()end
    else self:_openAccount()end
    return true
   end end
  end
  return mouse(self,x,y,...)
 end
end
return M
