-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native launcher consumers for cooperative package installation.
local Packages=require('src.mods.LauncherMods')
local M={}
local function current(self)
 if self._localModInstall then return self._localModInstall end
 local download=self._communityDownload
 if download and download.installJob then return {job=download.installJob,owner='community'}end
 local profile=self._profileApplying
 if profile and (profile.installJob or profile.backupJob or profile.restoreJob or profile.finishJob)then
  return {job=profile.installJob or profile.backupJob or profile.restoreJob or profile.finishJob,owner='profile'}
 end
end
local function note(self,text,ok)self.modNotice={text=text,ok=ok~=false}end
local function begin(self,job,why,kind)
 if not job then note(self,tostring(why),false);return false end
 self._localModInstall={job=job,kind=kind,previous=self.workState}
 self.workState='working';self.tab='mods';note(self,'Preparing mod installation…',true);return true
end
local function available(self)
 if self.workState=='working' or self._communityDownload or self._profileApplying or Packages.installBusy()then
  note(self,'Finish or cancel the current operation first.',false);return false
 end
 return true
end
local function finish(self,state,a,b,c)
 self._localModInstall=nil;self.workState=state.previous
 local ok,text=a,b
 if state.kind=='many' and type(a)=='table'then ok,text=Packages.summarize(a)
 elseif state.kind=='recovery'then
  if not a then self._modInstallRecoveryBlocked=true;self._profileRecoveryBlocked=true;text='Installation recovery needs attention: '..tostring(b)
  else self._modInstallRecoveryBlocked=nil;self._profileRecoveryBlocked=nil;self._pendingProfileRecovery=nil;text='Mod installation recovery completed.'end
 elseif a then text=state.kind=='release'and('Installed version '..tostring(b)..(c and (': '..c)or''))or('Installed '..tostring(b))end
 if state.job.cancelled then
  text='Import cancelled. Current package unchanged.'
  if #state.job.completed>0 then text=text..' '..#state.job.completed..' earlier packages were installed completely.'end
 end
 if state.job.warning then text=tostring(text)..' '..state.job.warning end
 if state.job.pendingReceipt and not a then self._modInstallRecoveryBlocked=true;self._profileRecoveryBlocked=true end
 note(self,tostring(text or 'Import failed.'),ok)
 if self._refreshMods then pcall(self._refreshMods,self)end
 if state.pick and self._consumeInstalledModPick then self:_consumeInstalledModPick(state.pick[1],state.pick[2],a==true)end
 if state.tally and self._pickManyTally then self:_pickManyTally(a==true)end
 if state.again and self._pickManyAgain then self:_pickManyAgain()end
 if state.mobileMany and self._pickManyBegin then self:_pickManyBegin('mod')end
 if state.pickerOnEmpty and (state.job.sourceCount or 0)==0 and self._openModNativePicker then self:_openModNativePicker()end
 if state.kind=='many'and state.job.sourceCount==0 and not state.mobileMany and not state.pickerOnEmpty and self._modInboxHint then self:_modInboxHint()end
end
function M.install(RI)
 function RI:_installMod(source,opts)
  if not available(self)then return end
  local job,why=Packages.beginInstallZip(source,opts);begin(self,job,why,'one')
 end
 function RI:_installMods(sources,opts)
  if not available(self)then return end
  local job,why=Packages.beginInstallMany(sources,opts);begin(self,job,why,'many')
 end
 function RI:_installModInbox(first,mobileMany,pickerOnEmpty)
  if not available(self)then return end
  if self.ensureModsInboxDir then self:ensureModsInboxDir()end
  local job,why=Packages.beginInstallInbox(first)
  if begin(self,job,why,'many')then
   self._localModInstall.mobileMany=mobileMany;self._localModInstall.pickerOnEmpty=pickerOnEmpty
  end
 end
 function RI:_installModFolder(path)
  if not available(self)then return end
  local job,why=Packages.beginInstallFolder(path);begin(self,job,why,'many')
 end
 function RI:_recoverModInstallations()
  if self._localModInstall or self._communityDownload or self._profileApplying or Packages.installBusy()then return end
  local job,why=Packages.beginRecoverInstalls();begin(self,job,why,'recovery')
 end
 function RI:_cancelModInstall()
  local state=self._localModInstall;if not state then return false end
  local accepted=Packages.cancelInstall(state.job)
  if accepted then note(self,'Cancelling and cleaning up…',true)
  else note(self,'Finishing the complete installation…',true)end
  return accepted
 end
 function RI:_cancelAnyModInstall()
  local state=current(self)
  if not state then return false end
  if state.owner=='community'then return self:_communityCancelDownload()end
  if state.owner=='profile'and self._cancelProfileInstall then return self:_cancelProfileInstall()end
  return self:_cancelModInstall()
 end
 local new=RI.new
 RI.new=function(...)
  local self=new(...)
  if self._pendingProfileRecovery or love.filesystem.getInfo('mod-install-journal','directory')and #love.filesystem.getDirectoryItems('mod-install-journal')>0 then
   local job,why=Packages.beginRecoverInstalls();begin(self,job,why,'recovery')
  end
  return self
 end
 local update=RI.update
 RI.update=function(self,dt,...)
  local state=self._localModInstall
  if state then
   local status,a,b,c=Packages.stepInstall(state.job)
   if status=='done'then finish(self,state,a,b,c)end
  end
  return update(self,dt,...)
 end
 local tally,again=RI._pickManyTally,RI._pickManyAgain
 if tally then RI._pickManyTally=function(self,...)
  if self._localModInstall then self._localModInstall.tally=true;return end
  return tally(self,...)
 end end
 if again then RI._pickManyAgain=function(self,...)
  if self._localModInstall then self._localModInstall.again=true;return end
  return again(self,...)
 end end
 local play=RI.play
 RI.play=function(self,...)
  if self._localModInstall or Packages.installBusy() or self._modInstallRecoveryBlocked then
   note(self,'Finish mod installation or recovery before playing.',false);return
  end
  return play(self,...)
 end
 local key=RI.keypressed
 RI.keypressed=function(self,value,...)
  if value=='escape'and self._profileApplying then return self:_cancelProfileInstall()end
  if value=='escape'and self._communityDownload then return self:_communityCancelDownload()end
  if current(self)then if value=='escape'then self:_cancelAnyModInstall()end;return end
  return key(self,value,...)
 end
 local mouse=RI.mousepressed
 RI.mousepressed=function(self,x,y,button,...)
  if current(self)then
   local r=self._modInstallCancelRect
   if r and button==1 and x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h then self:_cancelAnyModInstall()end
   return
  end
  return mouse(self,x,y,button,...)
 end
 local pad=RI.gamepadpressed
 if pad then RI.gamepadpressed=function(self,joystick,button,...)
  if button=='back'or require('src.core.GamepadMap').mapGamepadButton(button)=='b'then
   if self._profileApplying then return self:_cancelProfileInstall()end
   if self._communityDownload then return self:_communityCancelDownload()end
  end
  if current(self)then
   local action=require('src.core.GamepadMap').mapGamepadButton(button)
   if action=='b' or button=='back'then self:_cancelAnyModInstall()end;return
  end
  return pad(self,joystick,button,...)
 end end
 local draw=RI.draw
 RI.draw=function(self,...)
  local result=draw(self,...);local state=current(self)
  self._modInstallCancelRect=nil
  if state then
   local g=love.graphics;local w,h=g.getDimensions();local width=math.min(w-32,560);local x,y=(w-width)/2,h/2-76
   g.push('all');g.setColor(0,0,0,.7);g.rectangle('fill',0,0,w,h)
   g.setColor(.06,.09,.14,1);g.rectangle('fill',x,y,width,152,8,8)
   if self.hintFont then g.setFont(self.hintFont)end
   local progress=state.job.progress
   local label=state.job.cleaning and 'Cancelling and cleaning up…'or('Installing mod · '..tostring(progress.phase))
   g.setColor(1,1,1,1);g.printf(label,x+16,y+16,width-32,'left')
   local ratio=progress.total>0 and math.min(1,progress.done/progress.total)or 0
   g.setColor(.1,.25,.3,1);g.rectangle('fill',x+16,y+55,width-32,8)
   g.setColor(.2,.8,.9,1);g.rectangle('fill',x+16,y+55,(width-32)*ratio,8)
   local finishing=state.job.committed or state.job.pendingReceipt or state.job.cleaning
   g.setColor(.2,.3,.4,1);g.rectangle('fill',x+16,y+85,width-32,40,5,5)
   g.setColor(1,1,1,1);g.printf(finishing and 'Finishing…'or'Cancel · Esc / Back',x+16,y+96,width-32,'center')
   if not finishing then self._modInstallCancelRect={x=x+16,y=y+85,w=width-32,h=40}end
   g.pop()
  end
  return result
 end
end
return M
