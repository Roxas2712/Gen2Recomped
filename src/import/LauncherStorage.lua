local Storage={}
local SaveData=require('src.core.SaveData')
local Versions=require('src.core.GameVersion')
local Task=require('src.cloud.Task')
local Sync=require('src.storage.SyncStatus')
function Storage.install(RI)
  local GameCache=require('src.storage.GameCache');GameCache.refresh()
  function RI:_storageSync(version,slot,cartChoice,mode)
    if not require('src.storage.AccountStorage').requireUI(self,'storage') then return end
    if self._storageTask then self.settingsNotice='Cloud sync is already running.';return end
    if self._profileApplying then self.settingsNotice='Finish the mod profile transfer before syncing again.';return end
    self._storageRetry={version=version,slot=slot,cartChoice=cartChoice,mode=mode}
    local list={}
    for _,v in ipairs(Versions.ORDER) do list[#list+1]=v end
    local mods=self.mods or require('src.mods.LauncherMods').list()
    local options=self:_settings()
    local restoreOnly=mode=='restore'
    local ready={};for v,on in pairs(self.ready) do ready[v]=on end
    require('src.import.LauncherBackdrop').stop()
    local task,why=Task.new(function()
      local target,err=self:_sbCloudTarget()
      if not target then return nil,err end
      if cartChoice then
        if target.kind~='retro' then return nil,'Choose your RetroRecomped account for cartridge sync.' end
        local synced,why=require('src.storage.CartridgeCloud').sync(target,cartChoice)
        return synced and ('Custom cartridges: '..synced..'.') or nil,why
      end
      local games,cacheWarning
      if target.kind=='retro' then
        local cacheOptions={gameCacheDownload=options.gameCacheDownload,gameCacheUpload=not restoreOnly and options.gameCacheUpload}
        games,err=GameCache.sync(target,cacheOptions,ready,function(note) self.settingsNotice=note end,mode=='games-upload')
        if not games then
          if mode=='games-upload' or mode=='games' then return nil,err end
          cacheWarning=err;games={uploaded=0,downloaded=0,versions={}}
        end
        if mode=='games-upload' or mode=='games' then return {message='Private games: '..games.uploaded..' uploaded, '..games.downloaded..' restored.',games=games} end
      end
      local Cloud=require('src.import.CloudSync')
      if type(target)=='string' then target=Cloud.folderStore(target) end
      if version then
        local result,problem=Cloud.syncOne(target,version,slot)
        return result and ('Cloud sync: '..result) or nil,problem
      end
      local result,problem
      if restoreOnly then
        result,problem=Cloud.restoreVersions(target,list)
      else result,problem=Cloud.syncVersions(target,list) end
      if not result then return nil,problem end
      local message='Cloud sync: '..Cloud.describe(result)
      if games then message=message..' · Private games: '..games.uploaded..' uploaded / '..games.downloaded..' restored.' end
      if cacheWarning then message=message..' · Private game transfer paused: '..tostring(cacheWarning) end
      if target.kind=='retro' and options.cartridgeCloudSync and not restoreOnly then
        local carts,cartWhy=require('src.storage.CartridgeCloud').sync(target)
        if not carts then return nil,cartWhy end
        message=message..' · Custom cartridges: '..carts..'.'
      end
      local ok,Bank=pcall(require,'src.storage.PokemonBank')
      if ok and not restoreOnly and require('src.cloud.RetroCloud').signedIn() then
        local synced,bankWhy=Bank.sync(target)
        if not synced then return nil,bankWhy end
        message=message..' · Bank '..tostring(synced)..' entries.'
      end
      local profile
      if not restoreOnly and options.modProfileSync then
        local profileWhy
        local profileStore=target
        if target.kind~='retro' then profileStore,profileWhy=require('src.cloud.RetroCloud').open() end
        if not profileStore then return nil,profileWhy end
        profile,profileWhy=require('src.mods.ModProfiles').sync(profileStore,mods,options)
        if not profile then return nil,profileWhy end
        message=message..' · Mod profile: '..profile.kind..'.'
      end
      return {message=message,profile=profile,games=games,sync=result}
    end)
    self._storageTask=task;self._storageVersions=list
    Sync.set(task and 'uploading' or 'error',version,slot,why)
    self.settingsNotice=task and 'Syncing your saves and Pokémon Bank...' or tostring(why)
    self._storageNext=os.time()+300
  end
  function RI:_sbSyncAll() return self:_storageSync() end
  function RI:_sbSyncSlot(version,slot) return self:_storageSync(version,slot) end
  local rows=RI._sbCloudRows
  RI._sbCloudRows=function(self,add,...)
    rows(self,add,...)
    local state=Sync.get()
    add({kind='section',label='CLOUD STATUS',cloud=true,note=Sync.describe(state)..(state and state.detail and (' · '..state.detail) or '')})
    if state and (state.state=='error' or state.state=='cancelled' or state.state=='conflict') then
      add({kind='action',label='RETRY CLOUD SYNC',value='RETRY',action='storageRetry'})
    end
    add({kind='section',label='YOUR STORAGE',cloud=true,note='Saves, Bank and designs use progress storage. Private imported games have a separate account quota and remain available locally after app updates.'})
    add({kind='option',scope='launcher',label='AUTOMATIC SAVE SYNC',
      note='Sync while the launcher is open. Local play remains available offline.',
      row={id='cloudAutoSync',values={true,false},labels={[true]='ON',[false]='OFF'}}})
    add({kind='action',label='MODCOMPASS ACCOUNT & DEVICES',value='OPEN',action='retroCloudAccount'})
    add({kind='section',label='PRIVATE IMPORTED GAMES',cloud=true,note='Optional private copies of data you imported yourself, shared only with your own account devices. Saves keep their own quota. Existing imports are preserved when a cloud copy is activated.'})
    add({kind='option',scope='launcher',label='UPLOAD MY IMPORTED GAMES TO MY PRIVATE CACHE',note='Uploads game content to your private account storage. No sharing between accounts.',row={id='gameCacheUpload',values={false,true},labels={[true]='ON',[false]='OFF'}}})
    add({kind='option',scope='launcher',label='DOWNLOAD MY PRIVATE GAMES ON THIS DEVICE',note='Restore matching game/import revisions after signing in.',row={id='gameCacheDownload',values={false,true},labels={[true]='ON',[false]='OFF'}}})
    add({kind='action',label='UPLOAD MY IMPORTED GAMES NOW',value='UPLOAD',action='gameCacheUploadNow'})
    add({kind='action',label='RESTORE MY CLOUD GAMES & SAVES',value='RESTORE',action='accountRestoreNow'})
    add({kind='section',label='MY CARTRIDGES IN THE CLOUD',cloud=true,note='Your private cartridge images, colors, labels and logo choice join account save sync. Original versions are kept when two devices conflict.'})
    add({kind='option',scope='launcher',label='SYNC CUSTOM CARTRIDGE IMAGES & SETTINGS',
      note='Optional account storage for your artwork. This does not transfer ROMs or imported game caches.',
      row={id='cartridgeCloudSync',values={false,true},labels={[true]='ON',[false]='OFF'}}})
    add({kind='action',label='UPLOAD THIS DEVICE’S CARTRIDGES',value='UPLOAD',action='cartCloudUpload'})
    add({kind='action',label='RESTORE MY CLOUD CARTRIDGES',value='RESTORE',action='cartCloudRestore'})
    add({kind='option',scope='launcher',label='SYNC MY MOD PROFILE',
      note='Use your ModCompass login for package versions, activation and generation choices. Passwords and private mod settings stay local. Cartridge designs sync separately with account saves.',
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
    if entry and entry.action=='storageRetry' then
      local r=self._storageRetry or {};return self:_storageSync(r.version,r.slot,r.cartChoice,r.mode)
    end
    if entry and entry.action=='gameCacheUploadNow' then return self:_storageSync(nil,nil,nil,'games-upload') end
    if entry and entry.action=='accountRestoreNow' then return self:_storageSync(nil,nil,nil,'restore') end
    if entry and (entry.action=='cartCloudUpload' or entry.action=='cartCloudRestore') then
      return self:_storageSync(nil,nil,entry.action=='cartCloudUpload' and 'local' or 'cloud')
    end
    if entry and entry.action=='retroCloudAccount' then self:_openAccount();return end
    if entry and entry.action=='retroCloudCancel' then
      if self._storageTask then self._storageTask:cancel();self._storageTask=nil end
      Sync.set('cancelled')
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
    if id=='gameCacheUpload' or id=='gameCacheDownload' then self._storageNext=0;self._settingsRowCache=nil end
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
          self._storageTask=nil;self._settingsRowCache=nil;self._settingsCache=nil;self._cartStyleCache=nil
          local payload=result.kind=='done' and result.first
          Sync.result(type(payload)=='table' and (payload.sync or payload) or payload,result.error or result.second)
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
          GameCache.refresh();self:_recheckReady()
        end
      elseif self.launcher and not self._handedOff and not self.toolFlow and not self._bankOverlay and not self._developerOverlay
        and (not self._accountOverlay or self._cloudRestoreOnce and self._accountOverlay.mode=='account' and not self._accountOverlay.job and require('src.storage.AccountStorage').check())
        and not self._resumeOverlay and not self._saveHistoryOverlay and not self._resumeRestore and not self._profileApplying and not self._profileRecoveryBlocked and self.workState~='working'
        and not self._cloudFlow and (self:_settings().cloudAutoSync~=false or self:_settings().gameCacheUpload or self._cloudRestoreOnce) and (self._cloudRestoreOnce or os.time()>=(self._storageNext or 0)) then
        self._storageNext=os.time()+5
        local service=self:_sbCloudService()
        local definitions=require('src.import.LauncherSidebar').CLOUD_SERVICES
        local definition=definitions[service]
        if definition and require(definition.auth).signedIn() then
          local mode=self._cloudRestoreOnce and 'restore' or self:_settings().cloudAutoSync==false and 'games' or nil
          self._cloudRestoreOnce=nil;self:_storageSync(nil,nil,nil,mode)
        end
      end
    end
    return update(self,dt,...)
  end
end
return Storage
