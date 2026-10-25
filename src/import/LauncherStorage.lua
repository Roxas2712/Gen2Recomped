local Storage={}
local SaveData=require('src.core.SaveData')
local Versions=require('src.core.GameVersion')
local Task=require('src.cloud.Task')
function Storage.install(RI)
  function RI:_storageSync(version,slot)
    if self._storageTask then self.settingsNotice='Cloud sync is already running.';return end
    if self._profileApplying then self.settingsNotice='Finish the mod profile transfer before syncing again.';return end
    local list={}
    for _,v in ipairs(Versions.ORDER) do if self.ready[v] then list[#list+1]=v end end
    local mods=self.mods or require('src.mods.LauncherMods').list()
    local options=self:_settings()
    local task,why=Task.new(function()
      local target,err=self:_sbCloudTarget()
      if not target then return nil,err end
      local Cloud=require('src.import.CloudSync')
      if type(target)=='string' then target=Cloud.folderStore(target) end
      if version then
        local result,problem=Cloud.syncOne(target,version,slot)
        return result and ('Cloud sync: '..result) or nil,problem
      end
      local result,problem=Cloud.syncVersions(target,list)
      if not result then return nil,problem end
      local message='Cloud sync: '..Cloud.describe(result)
      local ok,Bank=pcall(require,'src.storage.PokemonBank')
      if ok then
        local synced,bankWhy=Bank.sync(target)
        if not synced then return nil,bankWhy end
        message=message..' · Bank '..tostring(synced)..' entries.'
      end
      local profile
      if options.modProfileSync then
        local profileWhy
        local profileStore=target
        if target.kind~='retro' then profileStore,profileWhy=require('src.cloud.RetroCloud').open() end
        if not profileStore then return nil,profileWhy end
        profile,profileWhy=require('src.mods.ModProfiles').sync(profileStore,mods,options)
        if not profile then return nil,profileWhy end
        message=message..' · Mod profile: '..profile.kind..'.'
      end
      return {message=message,profile=profile}
    end)
    self._storageTask=task;self._storageVersions=list
    self.settingsNotice=task and 'Syncing your saves and Pokémon Bank...' or tostring(why)
    self._storageNext=os.time()+300
  end
  function RI:_sbSyncAll() return self:_storageSync() end
  function RI:_sbSyncSlot(version,slot) return self:_storageSync(version,slot) end
  local rows=RI._sbCloudRows
  RI._sbCloudRows=function(self,add,...)
    rows(self,add,...)
    add({kind='section',label='YOUR STORAGE',note='Imported games and saves live outside the app. Updates keep them. Cloud transfers saves and Bank entries; each device keeps its own imported game data.'})
    add({kind='option',scope='launcher',label='AUTOMATIC SAVE SYNC',
      note='Sync while the launcher is open. Local play remains available offline.',
      row={id='cloudAutoSync',values={true,false},labels={[true]='ON',[false]='OFF'}}})
    add({kind='action',label='MODCOMPASS ACCOUNT & DEVICES',value='OPEN',action='retroCloudAccount'})
    add({kind='option',scope='launcher',label='SYNC MY MOD PROFILE',
      note='Use your ModCompass login for package versions, activation and generation choices. Login secrets, artwork and private mod settings stay local.',
      row={id='modProfileSync',values={false,true},labels={[true]='ON',[false]='OFF'}}})
    add({kind='option',scope='launcher',label='DOWNLOAD MY CLOUD MODS AUTOMATICALLY',
      note='Optional. Download the exact profile versions inside the launcher. Different engine versions and conflicts require review.',
      row={id='modProfileAutoDownload',values={false,true},labels={[true]='ON',[false]='OFF'}}})
    if self._modProfilePlan then
      add({kind='action',label='USE CLOUD MOD PROFILE ON THIS DEVICE',value='REVIEW',action='modProfileReview'})
      add({kind='action',label='USE THIS DEVICE AS MY CLOUD MOD PROFILE',value='REVIEW',action='modProfilePublish'})
    end
    if self._profileRecoveryBlocked then add({kind='action',label='RECOVER PREVIOUS MOD PROFILE',value='RETRY',action='modProfileRecover'}) end
    if self._storageTask then add({kind='action',label='CLOUD SYNC IN PROGRESS',value='CANCEL',action='retroCloudCancel'}) end
  end
  local action=RI._settingsAction
  RI._settingsAction=function(self,entry,...)
    if entry and entry.action=='retroCloudAccount' then self:_openAccount();return end
    if entry and entry.action=='retroCloudCancel' then
      if self._storageTask then self._storageTask:cancel();self._storageTask=nil end
      self.settingsNotice='Cloud sync cancelled. Local saves are preserved.';self._settingsRowCache=nil;return
    end
    return action(self,entry,...)
  end
  local set=RI._setSettingValue
  RI._setSettingValue=function(self,entry,value,...)
    local result=set(self,entry,value,...)
    local id=entry and entry.row and entry.row.id
    if id=='modProfileAutoDownload' and value then self:_settings().modProfileSync=true end
    if id=='modProfileSync' and not value then self:_settings().modProfileAutoDownload=false end
    if id=='modProfileSync' or id=='modProfileAutoDownload' then self._storageNext=0;self._settingsRowCache=nil end
    return result
  end
  local play=RI.play
  RI.play=function(self,...)
    -- A discarded launcher cannot continue a coroutine into a running game.
    if self._storageTask then self._storageTask:cancel();self._storageTask=nil end
    return play(self,...)
  end
  local update=RI.update
  RI.update=function(self,dt,...)
    if not self._launcherSequence then
      if self._storageTask then
        local result=self._storageTask:poll()
        if result then
          self._storageTask=nil;self._settingsRowCache=nil
          local payload=result.kind=='done' and result.first
          self.settingsNotice=type(payload)=='table' and payload.message or payload or ('Cloud sync paused: '..tostring(result.error or result.second))
          if type(payload)=='table' and payload.profile and (payload.profile.kind=='apply' or payload.profile.kind=='conflict') then
            self._modProfilePlan=payload.profile
            if payload.profile.kind=='apply' and not payload.profile.engineMismatch and self:_settings().modProfileAutoDownload then
              self:_communityApplyProfile(payload.profile)
            end
          elseif type(payload)=='table' and payload.profile then
            self._modProfilePlan=nil
          end
          for _,v in ipairs(self._storageVersions or {}) do pcall(self._refreshSlots,self,v) end
        end
      elseif self.launcher and not self._handedOff and not self.toolFlow and not self._bankOverlay and not self._developerOverlay and not self._accountOverlay and not self._resumeOverlay and not self._saveHistoryOverlay and not self._resumeRestore and not self._profileApplying and not self._profileRecoveryBlocked and self.workState~='working'
        and not self._cloudFlow and self:_settings().cloudAutoSync~=false and os.time()>=(self._storageNext or 0) then
        self._storageNext=os.time()+5
        local service=self:_sbCloudService()
        local definitions=require('src.import.LauncherSidebar').CLOUD_SERVICES
        local definition=definitions[service]
        if definition and require(definition.auth).signedIn() then self:_storageSync() end
      end
    end
    return update(self,dt,...)
  end
end
return Storage
