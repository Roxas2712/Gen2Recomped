-- Copyright (c) 2026 Roxas2712. GPL-3.0; see translation/rompack/NOTICE.md.
-- Launcher-owned acquisition and consent; the built-in pack owns game text.
local W={}
local N=require('src.translation.NativeLanguages')
local function L(text)return require('src.translation.Service').launcherLookup(text)end
function W.open(self,version,play)
 if not N.requirement(version) then return false end
 self._nativeLanguage={version=version,language=N.preferred(self:_settings(),version),play=play,rects={},selected=1,scroll=0}
 W.refresh(self);return true
end
function W.refresh(self)
 local f=self._nativeLanguage;if not f then return end
 f.state=N.describe(f.version,f.language)
 f.choices={}
 for _,id in ipairs(N.ORDER) do
  local state=N.describe(f.version,id,f.state.manifest)
  f.choices[#f.choices+1]={id=id,supported=state.supported,ready=state.ready,automatic=state.automatic,canPrepare=state.canPrepare}
 end
end
local function close(self,id)
 local f=self._nativeLanguage
 local ok,why=N.select(f.version,id)
 if not ok then f.notice=tostring(why or 'Your preferences could not be saved. Please try again.');return end
 local version,play=f.version,f.play
 self._nativeLanguage=nil;self._languageImportEntry=nil;self._languageImportManifest=nil
 self._settingsCache=nil;self._settingsRowCache=nil;self.mods=nil
 if play then self:play(version) end
 return true
end
function W.action(self,id)
 local f=self._nativeLanguage;if not f then return end
 if f.job and id~='english' and id~='later' then return end
 if id:match('^language:') then f.language=id:sub(10);f.notice=nil;W.refresh(self)
 elseif id=='english' or id=='later' then return close(self,'en')
 elseif id=='use' and f.state.canPrepare then
  local version,manifest=f.version,f.state.manifest
  f.notice=L('Preparing Portuguese from your US ROM…')
  f.job=coroutine.create(function()
   return require('src.translation.PtbrPatch').prepare(version,manifest,function(done,total,phase)
    f.progress={done=done,total=total,phase=phase};coroutine.yield()
   end)
  end)
 elseif id=='use' and f.state.ready then return close(self,f.language)
 elseif id=='import' and f.state.nextEntry then
  self._languageImportEntry=f.state.nextEntry;self._languageImportManifest=f.state.manifest
  self:chooseModImport(N.ID)
 end
end
function W.scroll(self,dy)
 local f=self._nativeLanguage;if f then f.scroll=math.max(0,math.min(f.maxScroll or 0,f.scroll-dy*42)) end
end
local function navigate(self,delta)
 local f=self._nativeLanguage;if #f.rects>0 then f.selected=((f.selected or 1)-1+delta)%#f.rects+1;f.follow=true end
end
function W.draw(self)
 local f=self._nativeLanguage;if not f then return end
 local g=love.graphics;local ww,hh=g.getDimensions();local s=math.max(.55,math.min(ww/1060,hh/760,1.3))
 local w,h=math.min(990*s,ww-24),math.min(710*s,hh-24);local x,y=(ww-w)/2,(hh-h)/2
 local U,P=self._ui,self.palette();local tx=x+26*s;local tw=w-52*s
 g.push('all');g.setCanvas();g.origin();g.setShader();g.setScissor();g.setBlendMode('alpha')
 if g.setDepthMode then g.setDepthMode() end;if g.setStencilTest then g.setStencilTest() end
 if g.setColorMask then g.setColorMask(true,true,true,true) end
 g.setColor(.01,.02,.04,.96);g.rectangle('fill',0,0,ww,hh)
 U.col(P.bgBot);g.rectangle('fill',x,y,w,h,18*s,18*s)
 U.col(P.link,.6);g.rectangle('line',x,y,w,h,18*s,18*s)
 g.setFont(self.gameNameFont);U.col(P.ink);g.printf(L('Your game. Your language.'),tx,y+22*s,tw,'left')
 g.setFont(self.hintFont);U.col(P.detail)
 g.printf(require('src.core.GameVersion').info(f.version).displayName..' · '..L('Built-in Uni-Language'),tx,y+61*s,tw,'left')
 local v={x=tx,y=y+96*s,width=tw,height=h-191*s};f.viewport=v;f.rects={}
 local top=v.y-f.scroll;g.setScissor(v.x,v.y,v.width,v.height)
 local function para(text,color)
  text=L(text);g.setFont(self.hintFont);U.col(color or P.detail)
  local _,lines=self.hintFont:getWrap(text,tw);g.printf(text,tx,top,tw,'left');top=top+#lines*self.hintFont:getHeight()+14*s
 end
 local function button(id,text,xx,yy,bw,pinned,disabled)
  text=L(text);local font=self.hintFont;local _,lines=font:getWrap(text,bw-20*s)
  local bh=math.max(40*s,#lines*font:getHeight()+16*s)
  local r={id=id,x=xx,y=yy,width=bw,height=bh,pinned=pinned};if not disabled then f.rects[#f.rects+1]=r end
  local selected=id=='language:'..f.language or f.rects[f.selected]==r
  U.col(P.link,disabled and .02 or selected and .24 or .07);g.rectangle('fill',xx,yy,bw,bh,8*s,8*s)
  U.col(selected and P.link or P.detail,disabled and .5 or 1);g.setFont(font);g.printf(text,xx+10*s,yy+8*s,bw-20*s,'center')
  return bh
 end
 para('Choose a game language below. The requirements for this edition are shown after selection.')
 local cw=(tw-10*s)/2
 for i=1,#f.choices,2 do
  local rowHeight=0
  for column=0,1 do local row=f.choices[i+column];if row then
   local mark=row.supported and (row.ready and L('Ready') or row.automatic and L(row.canPrepare and 'From US ROM' or 'US ROM needed') or L('ROM needed')) or L('Unavailable for this edition')
   rowHeight=math.max(rowHeight,button('language:'..row.id,N.NAMES[row.id]..' · '..mark,tx+column*(cw+10*s),top,cw))
  end end
  top=top+rowHeight+8*s
 end
 top=top+12*s
 local state=f.state
 if not state.supported then
  para('This edition has no matching cartridge profile for this language. Japanese is available for Crystal; Korean for Gold and Silver. You can keep playing in English.',P.warning)
 elseif f.language~='en' then
  if state.automatic then
   para('Portuguese is created automatically from your US ROM using the included translation patch. No extra PT-BR ROM or patch download is needed.',P.ink)
   local provenance=state.patchRecipe.provenance
   if provenance and provenance.author then para(L('Translation')..': '..provenance.author)end
  elseif state.source then
   para(L('Required language ROM')..': '..state.source.name..' · '..state.source.version,P.ink)
   para('SHA-1: '..state.source.sha1)
   para(L('Size')..': '..tostring(state.source.size)..' bytes')
  end
  if state.profile and state.profile.noticeKey then
   local locales=require('mods.UNI_LANGUAGE_NATIVE.locales')
   local locale=locales[N.canonical(self:_settings().launcherLanguage)] or locales.en
   para(locale[state.profile.noticeKey] or locales.en[state.profile.noticeKey])
  end
  if state.baseEntry then
   para(L('English base ROM')..': '..state.baseEntry.name)
   para('SHA-1: '..(state.automatic and state.patchRecipe.baseSha1 or state.requirement.base.sha1))
   para(state.baseReady and 'Your English base ROM is already retained locally.' or 'Import the matching English base once. Future imports retain it automatically.')
  end
  para('Only the exact listed revision is accepted. Supply your own ROM files; none are included or downloaded. Your game progress stays unchanged.')
  local entry=state.nextEntry
  if entry then
   local bh=button('import',L('IMPORT REQUIRED ROM')..' · '..entry.name,tx,top,tw);top=top+bh+16*s
  elseif state.ready then para('All requirements are ready. You can now use this language.',P.link)
  elseif state.canPrepare then para('Your US ROM is ready. Confirm to create Portuguese automatically.',P.link) end
 end
 if f.notice then para(f.notice,P.warning) end
 f.maxScroll=math.max(0,top+f.scroll-v.y-v.height)
 if f.follow then local r=f.rects[f.selected];if r and not r.pinned then
  if r.y<v.y then f.scroll=math.max(0,f.scroll+r.y-v.y) elseif r.y+r.height>v.y+v.height then f.scroll=math.min(f.maxScroll,f.scroll+r.y+r.height-v.y-v.height) end
 end;f.follow=nil end
 g.setScissor()
 if f.maxScroll>0 then
  local knob=math.max(24*s,v.height*v.height/(v.height+f.maxScroll))
  U.col(P.link,.3);g.rectangle('fill',v.x+tw+9*s,v.y,3*s,v.height)
  U.col(P.link);g.rectangle('fill',v.x+tw+9*s,v.y+(v.height-knob)*f.scroll/f.maxScroll,3*s,knob)
 end
 local bw=(tw-20*s)/3;local foot=y+h-66*s
 button('english','PLAY IN ENGLISH',tx,foot,bw,true)
 button('later','SET UP LATER',tx+bw+10*s,foot,bw,true)
 button('use',f.job and 'Preparing Portuguese…' or 'USE THIS LANGUAGE',tx+2*(bw+10*s),foot,bw,true,f.job or not(state.ready or state.canPrepare))
 g.pop()
end
function W.install(RI)
 function RI:_nativeLanguageImported(version,bytes,sha1)
  if not self.launcher or not N.requirement(version) then return end
  local ran,ok,why=pcall(N.keepBase,version,bytes,sha1)
  if not ran or not ok then self.nativeLanguageNotice=tostring(why or ok) end
  self._nativeLanguageOffers=self._nativeLanguageOffers or {};self._nativeLanguageOffers[#self._nativeLanguageOffers+1]=version
 end
 local play=RI.play;RI.play=function(self,version,...)
  if self._nativeLanguage then return end
  local o=self:_settings()
  if self.launcher and self.ready[version] and N.requirement(version) then
   local choice=type(o.nativeLanguages)=='table' and o.nativeLanguages[version]
   local state=choice and N.describe(version,choice)
   if (not choice and N.preferred(o,version)~='en') or (state and not state.ready) then return W.open(self,version,true) end
  end
  return play(self,version,...)
 end
 local update=RI.update;RI.update=function(self,dt,...)
  if self._nativeLanguage then
   local f=self._nativeLanguage
   if f.job then
    local ok,why=coroutine.resume(f.job)
    if not ok then
     f.job=nil;f.progress=nil
     require('src.core.Logger').warn('PT-BR preparation failed: %s',tostring(why))
     f.notice=L('Portuguese preparation failed. Your current language is unchanged. Check the US ROM and try again.')
     W.refresh(self)
    elseif coroutine.status(f.job)=='dead' then
     f.job=nil;f.progress=nil;W.refresh(self);return close(self,f.language)
    end
   end
   self.pulse=(self.pulse or 0)+dt
   if self.pickPending then self:_pollPickedFiles(dt) end
   return
  end
  local result=update(self,dt,...)
  if not self._setupOverlay and not self._setupPending and not self._launcherSequence and not self._romQueue and not self._pickMany and self.workState~='working' then
   local q=self._nativeLanguageOffers
   if q and #q>0 then
    local version=table.remove(q,1);local o=self:_settings()
    if not (o.nativeLanguages and o.nativeLanguages[version]) and N.preferred(o,version)~='en' then W.open(self,version) end
   end
  end
  return result
 end
 local entry=RI._modImportEntry;RI._modImportEntry=function(self,id,...)
  if id==N.ID and self._languageImportEntry then return self._languageImportEntry,{name='Uni-Language',manifestPath=self._languageImportManifest.path} end
  return entry(self,id,...)
 end
 local imported=RI._installModImport;RI._installModImport=function(self,id,...)
  local result=imported(self,id,...)
  if id==N.ID and self._nativeLanguage then
   self._nativeLanguage.notice=self.modNotice and self.modNotice.text;W.refresh(self)
  end
  return result
 end
 local draw=RI.draw;RI.draw=function(self,...)draw(self,...);W.draw(self)end
 local press=RI.mousepressed;RI.mousepressed=function(self,x,y,b,...)
  local f=self._nativeLanguage;if not f then return press(self,x,y,b,...) end
  if b==1 then for _,r in ipairs(f.rects) do if (r.pinned or self._ui.inside(f.viewport,x,y)) and self._ui.inside(r,x,y) then return W.action(self,r.id) end end end
 end
 local key=RI.keypressed;RI.keypressed=function(self,k,...)
  local f=self._nativeLanguage;if not f then return key(self,k,...) end
  if k=='escape' then W.action(self,'later')
  elseif k=='tab' or k=='down' or k=='right' then navigate(self,1)
  elseif k=='up' or k=='left' then navigate(self,-1)
  elseif k=='return' or k=='space' then local r=f.rects[f.selected];if r then W.action(self,r.id) end end
 end
 local pad=RI.gamepadpressed;RI.gamepadpressed=function(self,j,b,...)
  if not self._nativeLanguage then return pad(self,j,b,...) end
  local k=({a='return',b='escape',dpup='up',dpdown='down',dpleft='left',dpright='right',start='return'})[b];if k then self:keypressed(k) end
 end
 local wheel=RI.wheelmoved;RI.wheelmoved=function(self,dx,dy,...)if self._nativeLanguage then return W.scroll(self,dy)end;return wheel(self,dx,dy,...)end
 for _,method in ipairs({'touchpressed','touchmoved','touchreleased'}) do local original=RI[method]
  RI[method]=function(self,id,x,y,...)
   local f=self._nativeLanguage;if not f then if original then return original(self,id,x,y,...)end;return end
   if method=='touchpressed' then if not f.touch then f.touch={id=id,x=x,y=y,startX=x,startY=y}end
   elseif method=='touchmoved' then local t=f.touch;if t and t.id==id then t.moved=t.moved or math.abs(x-t.startX)>8 or math.abs(y-t.startY)>8;if t.moved then W.scroll(self,(y-t.y)/42)end;t.y=y end
   else local t=f.touch;if t and t.id==id then f.touch=nil;if not t.moved then self:mousepressed(x,y,1)end end end
  end
 end
 local dropped=RI.filedropped;RI.filedropped=function(self,file,...)
  local f=self._nativeLanguage
  if not f then return dropped(self,file,...) end
  if f.state.nextEntry then
   self._languageImportEntry=f.state.nextEntry;self._languageImportManifest=f.state.manifest
   return self:_installModImport(N.ID,file)
  end
 end
 for _,method in ipairs({'textinput','mousereleased','gamepadaxis','joystickhat'}) do local original=RI[method]
  if original then RI[method]=function(self,...)if self._nativeLanguage then return end;return original(self,...)end end
 end
 local rows=RI._launcherSettingsRows;RI._launcherSettingsRows=function(self,...)
  local result=rows(self,...);table.insert(result,2,{kind='action',label='GAME LANGUAGE (ROM)',value='OPEN',action='nativeLanguage'});return result
 end
 local settingsRows=RI._settingsRows
 if settingsRows then RI._settingsRows=function(self,...)
  local result=settingsRows(self,...)
  if self._workspaceCategory=='language' or self.settingsPage=='translation' then
   table.insert(result,2,{kind='action',label='GAME LANGUAGE (ROM)',value='OPEN',action='nativeLanguage'})
  end
  return result
 end end
 local action=RI._settingsAction;RI._settingsAction=function(self,r,...)
  if r and r.action=='nativeLanguage' then
   local version=self._translationSettingsVersion or self.tab
   return W.open(self,N.requirement(version) and version or 'crystal')
  end
  return action(self,r,...)
 end
end
return W
