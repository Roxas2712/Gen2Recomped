local M={}
local Profile=require('src.mods.ModProfiles')
local Packages=require('src.mods.LauncherMods')
local Download=require('src.mods.ModDownload')
local Task=require('src.cloud.Task')
local Http=require('src.cloud.Http')
local Json=require('src.link.Json')
local Saves=require('src.core.SaveData')
local Community=require('src.import.LauncherCommunity')
local function message(self,text,ok)
  self.settingsNotice=text;self.modNotice={ok=ok~=false,text=text};self.findNotice=self.modNotice;self._settingsRowCache=nil
end
local function clearFiles(state)
  for _,file in ipairs(state.files or {}) do love.filesystem.remove(file.path) end
end
local function stop(self,why)
  local state=self._profileApplying;if not state then return end
  if state.restoreJob or state.finishJob then message(self,'Finishing profile recovery or commit…',true);return false end
  if state.job then state.job:cancel() end
  if state.download then state.download:cancel() end
  local installation=state.installJob or state.backupJob
  if installation then
    state.stopWhy=why
    if Packages.cancelInstall(installation)then state.stage='cancelling' end
    message(self,'Cancelling the transfer and preserving the previous profile…',true);return true
  end
  if state.backup then
    local job,err=Packages.beginRestoreProfile(state.backup)
    if job then state.restoreJob=job;state.stage='restoring';state.stopWhy=why;return true end
    self._profileRecoveryBlocked=true;message(self,'Mod profile recovery needs attention: '..tostring(err),false)
  else
    if Saves.persistenceFs().read('mod_profile_recovery.lua')then self._profileRecoveryBlocked=true end
    message(self,why..' Installed mods are unchanged.',false)
  end
  clearFiles(state);self._profileApplying=nil;self:_refreshMods()
end
function M.tick(self)
  local state=self._profileApplying;if not state then return end
  if state.stage=='cancelling' then
    local key=state.installJob and 'installJob'or'backupJob'
    local status,result=Packages.stepInstall(state[key]);if status~='done'then return end
    if key=='backupJob'and type(result)=='table'then state.backup=result end
    state[key]=nil;return stop(self,state.stopWhy or 'Profile cancelled.')
  elseif state.stage=='restoring' then
    local status,ok,why=Packages.stepInstall(state.restoreJob);if status~='done'then return end
    state.restoreJob=nil
    if not ok then self._profileRecoveryBlocked=true;message(self,'Profile recovery files retained: '..tostring(why),false)
    else self._profileRecoveryBlocked=nil;message(self,(state.stopWhy or 'Transfer cancelled.')..' Previous profile restored.',false)end
    clearFiles(state);self._profileApplying=nil;self:_refreshMods();return
  elseif state.stage=='finishing' then
    local status,ok,why=Packages.stepInstall(state.finishJob);if status~='done'then return end
    state.finishJob=nil
    if not ok then
      self._profileRecoveryBlocked=true;clearFiles(state);self._profileApplying=nil
      message(self,'Profile commit recovery is required: '..tostring(why),false);return
    end
    clearFiles(state);self._profileApplying=nil;if not state.plan.resume then self._modProfilePlan=nil end
    self._settingsCache=nil;self:_refreshMods()
    message(self,state.plan.resume and 'This save’s mod versions and activation have been restored.'or'Cloud mod profile applied. Package versions and activation now match.',true)
    return
  end
  if state.stage=='catalogue' then
    if self._communityFindJob then return end
    if not self.findIndex then stop(self,'ModCompass catalogue unavailable.');return end
    state.byRepo={}
    for _,entry in ipairs(self.findIndex.mods or {}) do if entry.github and entry.catalogueId then state.byRepo[entry.github:lower()]=entry end end
    state.stage='resolve'
  end
  if state.stage=='resolve' then
    if state.retryAt and love.timer.getTime()<state.retryAt then return end
    state.retryAt=nil
    local wanted=state.plan.downloads[state.cursor]
    if not wanted then state.stage='backup';return end
    local entry=state.byRepo[wanted.repo:lower()]
    if not entry then stop(self,'No approved ModCompass source for '..wanted.id..'.');return end
    if not state.job then
      state.title=wanted.id..' '..wanted.version
      state.job=Task.new(function()
        local query={version=wanted.version};if wanted.tag then query.tag=wanted.tag end
        local code,bytes=Http.request('GET',entry.resolveUrl..'/latest?'..Http.form(query),{headers={Accept='application/json'}})
        if code==429 then return {rateLimited=true} end
        if code~=200 then return nil,'Repository check failed ('..tostring(code or 'offline')..').' end
        return Json.decode(bytes)
      end)
      if not state.job then stop(self,'Background repository checks are unavailable.');return end
    end
    local result=state.job:poll();if not result then return end
    state.job=nil
    if result.kind=='done' and type(result.first)=='table' and result.first.rateLimited then
      state.retryCount=(state.retryCount or 0)+1
      if state.retryCount>3 then stop(self,'ModCompass is busy. Try again later; installed packages are unchanged.');return end
      state.retryAt=love.timer.getTime()+65
      message(self,'ModCompass request limit reached. Retrying in 65 seconds; you can cancel the transfer.',true);return
    end
    state.retryCount=0
    if result.kind~='done' or not Community.resolve(entry,result.first) or entry.id~=wanted.id then stop(self,'Repository identity could not be verified for '..wanted.id..'.');return end
    local release
    for _,row in ipairs(result.first.releases or {}) do if row.version==wanted.version and (not wanted.tag or row.tag==wanted.tag) then release=row;break end end
    if not release then stop(self,'The pinned ZIP '..wanted.id..' '..wanted.version..' is not available.');return end
    if wanted.sha256 then
      if release.zip.sha256 and release.zip.sha256~=wanted.sha256 then stop(self,'The pinned package fingerprint changed: '..wanted.id..'.');return end
      release.zip.sha256=wanted.sha256
    end
    local job,why=Download.start(release)
    if not job then stop(self,tostring(why));return end
    state.download=job;state.release=release;state.stage='download'
  elseif state.stage=='download' then
    local result=state.download:poll()
    if result.kind=='progress' then state.bytes=result.bytes;state.total=result.total
    elseif result.kind=='done' then
      state.files[#state.files+1]={path=result.path,release=state.release,id=state.plan.downloads[state.cursor].id,repo=state.plan.downloads[state.cursor].repo,sha256=result.digest}
      state.download=nil;state.bytes=0;state.total=nil;state.cursor=state.cursor+1;state.stage='resolve'
    else stop(self,'Mod download failed: '..tostring(result.error or 'cancelled'));return end
  elseif state.stage=='backup' then
    local pending=state.plan.resume and self._resumeRestore
    if pending then
      local snapshot=Saves.peekSlot(pending.version,pending.slot)
      if Saves.activeSlot(pending.version)~=pending.slot or not snapshot or require('src.storage.SaveResume').fingerprint(snapshot)~=pending.fingerprint then
        stop(self,'The selected save changed during download. Choose Play again.');return
      end
    end
    if not Profile.unchanged(state.plan,Packages.list(),Saves.loadOptions()) then stop(self,'Local mods changed while downloading. Sync again.');return end
    local ids={};for _,file in ipairs(state.files) do ids[#ids+1]=file.id end
    if not state.backupJob then
      local job,why=Packages.beginBackupProfile(ids)
      if not job then stop(self,'Could not preserve the current profile: '..tostring(why));return end
      state.backupJob=job
    end
    local status,backup,why=Packages.stepInstall(state.backupJob);if status~='done'then return end
    state.backupJob=nil
    if not backup then stop(self,'Could not preserve the current profile: '..tostring(why));return end
    state.backup=backup;state.stage='install';state.cursor=1
  elseif state.stage=='install' then
    local file=state.files[state.cursor]
    if file then
      if not state.installJob then
        local job,why=Packages.beginInstallFromRelease(file.id,file.release,file.path,nil,file.release.version)
        if not job then stop(self,'Profile installation failed: '..tostring(why));return end
        state.installJob=job
      end
      local status,ok,version,mismatch=Packages.stepInstall(state.installJob);if status~='done'then return end
      state.installJob=nil
      if state.stopWhy then stop(self,state.stopWhy);return end
      if not ok or mismatch or version~=file.release.version then stop(self,'Profile installation failed: '..tostring(mismatch or version));return end
      state.cursor=state.cursor+1
    else
      local options=Saves.loadOptions();options.modInstallSources=options.modInstallSources or {}
      for _,file in ipairs(state.files) do options.modInstallSources[file.id]={repo=file.repo,version=file.release.version,tag=file.release.tag,sha256=file.sha256} end
      if not Saves.saveOptions(options) then stop(self,'Could not save package provenance.');return end
      local ok,why=Profile.accept(state.plan)
      if not ok then stop(self,tostring(why));return end
      local job,err=Packages.beginFinishProfile(state.backup)
      if not job then stop(self,tostring(err));return end
      state.finishJob=job;state.stage='finishing'
    end
  end
end
function M.install(RI)
  function RI:_cancelProfileInstall()return stop(self,'Profile transfer cancelled.')end
  function RI:_communityApplyProfile(plan,manual)
    if self._profileApplying or self._communityDownload or self._storageTask then message(self,'Finish the current download or sync first.',false);return end
    if (plan.kind=='conflict' or plan.engineMismatch) and not manual then self._modProfilePlan=plan;message(self,'Cloud mod profile needs review.',false);return end
    local installed=Packages.list()
    if not Profile.unchanged(plan,installed,Saves.loadOptions()) then
      self._modProfilePlan=nil;message(self,'Local mods changed during sync. Sync again before applying the cloud profile.',false);return
    end
    local current=Profile.plan(plan.profile,installed,plan.resume);current.hash=plan.hash;current.scope=plan.scope;current.localHash=plan.localHash
    if #current.downloads==0 then
      local ok,why=Profile.accept(current)
      if not ok then message(self,tostring(why),false);return end
      if not current.resume then self._modProfilePlan=nil end;self._settingsCache=nil;self:_refreshMods();message(self,current.resume and 'This save’s mod activation has been restored.' or 'Cloud mod activation applied.',true);return
    end
    self._profileApplying={plan=current,stage='catalogue',cursor=1,files={}}
    if not self.findIndex then self.findLoaded=false end
    if not self.findLoaded then self:_ensureFind() end
    message(self,'Preparing '..#current.downloads..' pinned mod downloads from ModCompass...',true)
  end
  local new=RI.new
  RI.new=function(...)
    local self=new(...)
    local bytes=Saves.persistenceFs().read('mod_profile_recovery.lua')
    if bytes then
      self._pendingProfileRecovery=true;self._profileRecoveryBlocked=true
      message(self,'Preparing recovery of the previous complete mod profile…',true)
    end
    return self
  end
  local action=RI._settingsAction
  RI._settingsAction=function(self,entry,...)
    if entry and entry.action=='modProfilePublish' and self._modProfilePlan then
      self._modConfirm={kind='cloudModPublish',title='Use this device as your cloud profile?',yesLabel='Use this device',
        lines={'Publish this device’s current package versions and activation choices.',
          'Other devices can adopt them on their next sync. Their local mod files are kept.',
          'Simultaneous cloud changes are refused; sync again if another device publishes first.'}}
      return
    end
    if entry and entry.action=='modProfileRecover' then
      self:_recoverModInstallations()
      return
    end
    if entry and entry.action=='modProfileReview' and self._modProfilePlan then
      local plan=self._modProfilePlan
      local lines={#plan.profile.mods..' packages in your cloud profile.',#plan.downloads..' exact package versions need downloading.'}
      if plan.engineMismatch then lines[#lines+1]='Profile engine: '..plan.profile.engine..'; this engine: '..require('src.core.Version').engine end
      if plan.kind=='conflict' then lines[#lines+1]='Both devices changed. Applying chooses the cloud activation profile; local mod files are backed up.' end
      lines[#lines+1]='Extra local packages are kept but switched off.'
      self._modConfirm={kind='cloudModProfile',title='Use cloud mod profile?',yesLabel='Apply profile',lines=lines,plan=plan};return
    end
    return action(self,entry,...)
  end
  local press=RI.mousepressed
  RI.mousepressed=function(self,x,y,button,...)
    local confirm=self._modConfirm
    if confirm and (confirm.kind=='cloudModProfile' or confirm.kind=='cloudModPublish') then
      if button==1 and RI._ui.inside(self._modConfirmYes,x,y) then
        self._modConfirm=nil
        if confirm.kind=='cloudModProfile' then self:_communityApplyProfile(confirm.plan,true)
        elseif not self._storageTask and not self._profileApplying then
          self._storageTask=Task.new(function()
            local store,why=require('src.cloud.RetroCloud').open();if not store then return nil,why end
            -- Read before publishing so the provider has the current revision.
            -- The following write still uses compare-and-swap if another device races.
            store.read(Profile.PATH)
            local ok,err=Profile.publish(store,Packages.list(),Saves.loadOptions())
            if not ok then return nil,err end
            return {message='This device is now your cloud mod profile.',profile={kind='published'}}
          end)
          message(self,self._storageTask and 'Publishing this device’s mod profile...' or 'Background networking unavailable.',self._storageTask~=nil)
        end
      elseif button==1 and RI._ui.inside(self._modConfirmNo,x,y) then self._modConfirm=nil end
      return
    end
    if self._profileCancelRect and RI._ui.inside(self._profileCancelRect,x,y) then stop(self,'Profile download cancelled.');return end
    if self._profileApplying and (self._profileApplying.stage=='backup' or self._profileApplying.stage=='install') then return end
    return press(self,x,y,button,...)
  end
  local play=RI.play
  RI.play=function(self,...)
    if self._profileApplying or self._profileRecoveryBlocked then message(self,'Complete or recover the mod profile before starting a game.',false);return end
    return play(self,...)
  end
  local backdrop=RI._sbBackdropWant
  RI._sbBackdropWant=function(self,...)
    if self._profileRecoveryBlocked or self._profileApplying then return nil end
    return backdrop(self,...)
  end
  for _,method in ipairs({'_drawModsPanel','_drawFindPanel','_sbGames'}) do
    local original=RI[method]
    RI[method]=function(self,x,y,w,h,...)
      local state=self._profileApplying
      self._profileCancelRect=nil
      if not state then return original(self,x,y,w,h,...) end
      local s=self._s;local label='MOD PROFILE · '..state.stage:upper()..' · '..(state.title or '')
      if state.retryAt then label=label..' · RETRY IN '..math.max(0,math.ceil(state.retryAt-love.timer.getTime()))..'s' end
      if state.total then label=label..string.format(' · %.1f / %.1f MB',(state.bytes or 0)/1048576,state.total/1048576) end
      love.graphics.setFont(self.hintFont);RI._ui.col(RI.palette().link)
      love.graphics.printf(label,x,y,math.max(60,w-110*s),'left')
      if not state.restoreJob and not state.finishJob then self._profileCancelRect=self:_chipButton(x+w-100*s,y,'CANCEL',{w=100*s,h=32*s}) end
      return 50*s+original(self,x,y+50*s,w,h-50*s,...)
    end
  end
  local update=RI.update
  RI.update=function(self,dt,...)
    if not self._launcherSequence then
      local ok,why=pcall(M.tick,self)
      if not ok then stop(self,'Mod profile stopped: '..tostring(why)) end
    end
    return update(self,dt,...)
  end
end
return M
