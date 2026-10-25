local W={}
local Saves=require('src.core.SaveData')
local Resume=require('src.storage.SaveResume')
local Profile=require('src.mods.ModProfiles')
local Packages=require('src.mods.LauncherMods')
local Games=require('src.core.GameVersion')
local function notice(self,text)
  self.settingsNotice=text;self.modNotice={ok=false,text=text};self._settingsRowCache=nil
end
local function read(version,slot)
  local save,why=Saves.peekSlot(version,slot)
  if not save then return nil,why end
  return {save=save,fingerprint=Resume.fingerprint(save)}
end
local function unchanged(self,f)
  if Saves.activeSlot(f.version)~=f.slot then return nil,'The selected save changed. Choose Play again.' end
  local current,why=read(f.version,f.slot)
  if not current or current.fingerprint~=f.fingerprint then return nil,why or 'This save changed while it was being reviewed. Choose Play again.' end
  return current
end
local function open(self,version,slot,snapshot,report)
  if not report then
    local ok,result=pcall(Resume.assess,snapshot.save,version,Packages.list(),Saves.loadOptions())
    report=ok and result or {blocked=true,needsReview=true,rows={},problems={'Save requirements could not be read. Restore a known good copy before playing.'}}
  end
  self._resumeOverlay={version=version,slot=slot,fingerprint=snapshot.fingerprint,report=report,scroll=0,rects={},padIndex=2}
end
function W.close(self) self._resumeOverlay=nil end
function W.action(self,id)
  local f=self._resumeOverlay;if not f then return end
  if id=='close' then W.close(self);return end
  if id=='mods' then W.close(self);self:_sbGo('mods');self:_refreshMods();return end
  if id=='account' then W.close(self);self:_openAccount();return end
  if self._storageTask or self._profileApplying or self._communityDownload then f.notice='Finish the current transfer first.';return end
  local snapshot,why=unchanged(self,f)
  if not snapshot then f.notice=why;f.stale=true;return end
  local report=Resume.assess(snapshot.save,f.version,Packages.list(),Saves.loadOptions())
  f.report=report
  if id=='restore' then
    if f.stale or report.blocked or not report.plan then f.notice='Some requirements need a manual mod installation or an engine update.';return end
    if #report.plan.downloads>0 and not require('src.cloud.RetroCloud').signedIn() then W.close(self);self:_openAccount();return end
    self._resumeRestore={version=f.version,slot=f.slot,fingerprint=f.fingerprint}
    W.close(self)
    self:_communityApplyProfile(report.plan,true)
  elseif id=='copy' then
    if report.blocked then f.notice='Resolve the incompatible save requirements before opening this save.';return end
    -- The current device may intentionally run a different stack. Only ever
    -- continue on a new slot; the original and its cloud link remain intact.
    local version=f.version
    local copy,err=Saves.restoreAsNewSlot(version,{read=function() return snapshot.fingerprint end},'Continue on this device')
    if not copy then f.notice='Could not preserve a separate copy: '..tostring(err);return end
    if not Saves.setActiveSlot(version,copy) then
      f.notice='The copy was kept, but could not be selected. Choose it from Save files.';self:_refreshSlots(version);return
    end
    self:_refreshSlots(version)
    local copied,problem=read(version,copy)
    if not copied then f.notice='The copy could not be verified: '..tostring(problem);return end
    W.close(self)
    self._resumeBypass={version=version,slot=copy,fingerprint=copied.fingerprint,localHash=Profile.fingerprint(Packages.list(),Saves.loadOptions())}
    self:play(version)

  end
end
function W.tick(self)
  local pending=self._resumeRestore
  if not pending or self._profileApplying or self._storageTask then return end
  self._resumeRestore=nil
  local snapshot,why=unchanged(self,pending)
  if not snapshot then notice(self,why);return end
  local report=Resume.assess(snapshot.save,pending.version,Packages.list(),Saves.loadOptions())
  if report.needsReview then
    open(self,pending.version,pending.slot,snapshot,report)
    self._resumeOverlay.notice=report.engineMismatch and 'Mod choices restored. Review the engine version before continuing on a copy.' or 'Restore incomplete. Your original save is preserved; review the remaining requirements.'
  else self:play(pending.version) end
end
function W.scroll(self,dy)
  local f=self._resumeOverlay;if f then f.scroll=math.max(0,math.min(f.maxScroll or 0,f.scroll-dy*45));f.padActive=false end
end
function W.navigate(self,step)
  local f=self._resumeOverlay;if not f or #f.rects==0 then return end
  f.padIndex=((f.padIndex or 2)-1+step)%#f.rects+1;f.padActive=true
  local r=f.rects[f.padIndex];local v=f.viewport
  if not r.pinned then
    if r.y<v.y then f.scroll=math.max(0,f.scroll+r.y-v.y)
    elseif r.y+r.height>v.y+v.height then f.scroll=math.min(f.maxScroll or 0,f.scroll+r.y+r.height-v.y-v.height) end
  end
end
function W.draw(self)
  local f=self._resumeOverlay;if not f then return end
  local g=love.graphics;local ww,hh=g.getDimensions();local s=math.max(.65,math.min(ww/1050,hh/720,1.25))
  local width=math.min(820*s,ww-28*s);local height=math.min(670*s,hh-28*s);local x,y=(ww-width)/2,(hh-height)/2
  local U,p=self._ui,self.palette();f.rects={}
  g.push('all');g.setCanvas();g.origin();g.setShader();g.setScissor();g.setBlendMode('alpha')
  g.setColor(.015,.025,.05,.96);g.rectangle('fill',0,0,ww,hh)
  g.setColor(.06,.09,.14,1);g.rectangle('fill',x,y,width,height,14*s,14*s)
  local function text(value,tx,ty,w,big)
    g.setFont(big and self.stateFont or self.hintFont);U.col(big and p.ink or p.detail);g.printf(value,tx,ty,w,'left')
  end
  text('CONTINUE ON THIS DEVICE',x+24*s,y+20*s,width-145*s,true)
  local close=self:_chipButton(x+width-108*s,y+18*s,'BACK',{w=84*s,h=38*s,kind='accent'});close.id='close';close.pinned=true;f.rects[1]=close
  local v={x=x+18*s,y=y+76*s,width=width-36*s,height=height-94*s};f.viewport=v
  local top=v.y-f.scroll
  local function paragraph(value,big)
    local font=big and self.stateFont or self.hintFont;local _,lines=font:getWrap(value,width-48*s)
    text(value,x+24*s,top,width-48*s,big);top=top+math.max(1,#lines)*font:getHeight()+16*s
  end
  local function row(label,id)
    local _,lines=self.hintFont:getWrap(label,width-72*s);local h=math.max(38*s,#lines*self.hintFont:getHeight()+20*s)
    local r=self:_chipButton(x+24*s,top,'',{w=width-48*s,h=h,kind='accent'});r.id=id;f.rects[#f.rects+1]=r
    text(label,x+36*s,top+10*s,width-72*s);top=top+h+12*s
  end
  g.setScissor(v.x,v.y,v.width,v.height)
  paragraph(Games.info(f.version).displayName,true)
  paragraph('This save carries its own mod requirements. Match those versions before continuing, or keep the original and use a separate copy with your current mods.')
  if f.report.legacy then paragraph('Older save: mod versions are known where recorded, but package hashes and download sources may be unavailable.') end
  for _,problem in ipairs(f.report.problems or {}) do paragraph(problem) end
  local labels={ready='READY',download='RESTORE EXACT VERSION',manual='MANUAL SETUP',enable='ENABLE FOR THIS GAME',disable='SWITCH OFF FOR THIS GAME'}
  for _,mod in ipairs(f.report.rows or {}) do
    paragraph(mod.id..' · '..tostring(mod.version)..' · '..tostring(labels[mod.status] or mod.status),true)
    if mod.detail then paragraph(mod.detail) end
  end
  paragraph('Activation is restored for this game’s generation. Installed package versions are shared across games; replaced mod files are backed up.')
  if not f.stale and not f.report.blocked and f.report.plan then row('RESTORE THIS SAVE’S MOD SET','restore') end
  if not f.stale and not f.report.blocked then row('KEEP ORIGINAL · CONTINUE ON A COPY WITH CURRENT MODS','copy') end
  row('OPEN MOD MANAGER','mods')
  if not require('src.cloud.RetroCloud').signedIn() then row('SIGN IN FOR MOD DOWNLOADS','account') end
  paragraph(f.notice or 'Only this game’s generation is adjusted. Other generations keep their active mod choices. No save data is changed by reviewing this screen.')
  f.maxScroll=math.max(0,top+f.scroll-v.y-v.height);f.scroll=math.min(f.scroll,f.maxScroll)
  local selected=f.padActive and f.rects[f.padIndex]
  if selected and not selected.pinned then U.col(p.link);g.setLineWidth(2*s);g.rectangle('line',selected.x-3*s,selected.y-3*s,selected.width+6*s,selected.height+6*s,6*s,6*s) end
  g.setScissor()
  if f.maxScroll>0 then
    U.col(p.cardBlue);g.rectangle('fill',x+width-12*s,v.y,3*s,v.height)
    U.col(p.link);local th=math.max(20*s,v.height*v.height/(v.height+f.maxScroll));g.rectangle('fill',x+width-12*s,v.y+(v.height-th)*f.scroll/f.maxScroll,3*s,th)
  end
  g.pop()
end
function W.install(RI)
  local U=RI._ui
  local play=RI.play
  RI.play=function(self,version,...)
    if self._launcherSequence or self._handedOff or self._resumeOverlay then return end
    if not self.launcher or self.toolFlow then return play(self,version,...) end
    if self._storageTask or self._communityDownload then notice(self,'Finish the current transfer before starting a game.');return end
    if self._profileApplying or self._profileRecoveryBlocked then return play(self,version,...) end
    if not self.ready[version] or self.workState=='working' then return end
    local slot=Saves.activeSlot(version)
    if slot then
      local snapshot,why=read(version,slot)
      if why then notice(self,why);return end
      if snapshot then
        local bypass=self._resumeBypass;self._resumeBypass=nil
        if bypass and bypass.version==version and bypass.slot==slot and bypass.fingerprint==snapshot.fingerprint
          and bypass.localHash==Profile.fingerprint(Packages.list(),Saves.loadOptions()) then return play(self,version,...) end
        local ok,report=pcall(Resume.assess,snapshot.save,version,Packages.list(),Saves.loadOptions())
        if not ok or report.needsReview then open(self,version,slot,snapshot,ok and report or nil);return end
      end
    end
    return play(self,version,...)
  end
  local draw=RI.draw;RI.draw=function(self,...) draw(self,...);W.draw(self) end
  local update=RI.update;RI.update=function(self,dt,...) W.tick(self);return update(self,dt,...) end
  local press=RI.mousepressed;RI.mousepressed=function(self,x,y,b,...)
    local f=self._resumeOverlay;if not f then return press(self,x,y,b,...) end
    if b~=1 then return end;f.padActive=false
    for _,r in ipairs(f.rects) do if (r.pinned or U.inside(f.viewport,x,y)) and U.inside(r,x,y) then W.action(self,r.id);return end end
  end
  local key=RI.keypressed;RI.keypressed=function(self,k,...)
    local f=self._resumeOverlay;if not f then return key(self,k,...) end
    if k=='escape' then W.close(self)
    elseif k=='down' or k=='tab' then W.navigate(self,1)
    elseif k=='up' then W.navigate(self,-1)
    elseif k=='return' or k=='space' then local r=f.rects[f.padIndex or 2];if r then W.action(self,r.id) end end
  end
  local pad=RI.gamepadpressed;RI.gamepadpressed=function(self,j,b,...)
    local f=self._resumeOverlay;if not f then return pad(self,j,b,...) end
    if b=='b' then W.close(self) elseif b=='dpdown' then W.navigate(self,1) elseif b=='dpup' then W.navigate(self,-1)
    elseif b=='a' then local r=f.rects[f.padIndex or 2];if r then W.action(self,r.id) end end
  end
  local wheel=RI.wheelmoved;RI.wheelmoved=function(self,dx,dy,...) if self._resumeOverlay then W.scroll(self,dy);return end;if wheel then return wheel(self,dx,dy,...) end end
  local touch=RI.touchpressed;RI.touchpressed=function(self,id,x,y,...)
    local f=self._resumeOverlay;if not f then return touch(self,id,x,y,...) end
    if not f.touch then f.touch={id=id,y=y,startY=y} end
  end
  local move=RI.touchmoved;RI.touchmoved=function(self,id,x,y,...)
    local f=self._resumeOverlay;if not f then if move then return move(self,id,x,y,...) end;return end
    local t=f.touch;if t and t.id==id then if math.abs(y-t.startY)>8 then t.scrolling=true end;if t.scrolling then W.scroll(self,(y-t.y)/45) end;t.y=y end
  end
  local release=RI.touchreleased;RI.touchreleased=function(self,id,x,y,...)
    local f=self._resumeOverlay;if not f then if release then return release(self,id,x,y,...) end;return end
    local t=f.touch;if t and t.id==id then f.touch=nil;if not t.scrolling then self:mousepressed(x,y,1) end end
  end
  for _,name in ipairs({'textinput','mousereleased','mousemoved'}) do local original=RI[name];RI[name]=function(self,...) if self._resumeOverlay then return end;if original then return original(self,...) end end end
end
return W
