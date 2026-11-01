-- RetroRecomped's account policy is enabled by its app bootstrap. The engine
-- remains usable by headless tools without network or account dependencies.
local P={FILE='storage_account.lua',enabled=false}
local S=require('src.core.SaveSerializer')
local tasks=setmetatable({},{__mode='k'})
local function auth() return require('src.cloud.RetroCloud') end
local function disk() return require('src.core.SaveData').persistenceFs() end
local function valid(id) return type(id)=='string' and #id<=20 and id:match('^[1-9][0-9]*$') end
function P.enable() P.enabled=true end
function P.scope()
  -- Pure/headless SDK consumers do not enable RetroRecomped's account policy.
  -- Constructing a public API must not read cloud credentials or require LOVE.
  if not P.enabled then return nil end
  local co=coroutine.running()
  if co and tasks[co] then return tasks[co] end
  local a=auth();return a.accountId and a.accountId()
end
function P.attachTask(co) tasks[co]=P.scope() or 'guest' end
function P.owner()
  local bytes=disk().read(P.FILE)
  if not bytes then return nil end
  local ok,value=pcall(S.decode,bytes)
  if ok and type(value)=='table' and value.schema==1 and valid(value.accountId) then return value.accountId end
  return nil,'Storage account record needs recovery. Existing saves and Bank records were preserved.'
end
function P.check()
  if not P.enabled then return true end
  local a=auth();local id=a.accountId and a.accountId()
  local scope=P.scope()
  if scope and scope~=id then return nil,'The account changed during this operation. Existing records were preserved.' end
  if not valid(id) then return nil,'Register or sign in and confirm your email before using the Bank or cloud saves.' end
  local owner,why=P.owner()
  if why then return nil,why end
  if not owner then return nil,'Link the local saves and Bank to your confirmed account first.' end
  if owner~=id then return nil,'These local saves and Bank belong to another account. Sign in with that account; no files were reassigned.' end
  return true
end
-- Device-local saves are available to guests. Bank and cloud boundaries keep
-- using check(), which still requires a confirmed, explicitly linked owner.
function P.saveCheck()
  if not P.enabled then return true end
  local id=auth().accountId and auth().accountId()
  local scope=P.scope()
  if scope and scope~=(valid(id)and id or'guest') then return nil,'The account changed during this operation. Existing records were preserved.' end
  if valid(id)then
    local owner,why=P.owner()
    if why then return nil,why end
    if owner and owner~=id then return nil,'These local saves and Bank belong to another account. Sign in with that account; no files were reassigned.'end
  end
  return true
end
function P.profileChanged(self)
  self._storageResumeAfter=nil
  local outbox=package.loaded['src.storage.CloudOutbox'];if outbox then outbox.cancel() end
  local hub=package.loaded['src.ui.WalkerMinigames']
  if hub and hub.active then hub.active:close(true)end
  self.walker=nil;self._walkerPumpT=0
  local backdrop=package.loaded['src.import.LauncherBackdrop'];if backdrop and backdrop.stop then backdrop.stop() end
  local cache=package.loaded['src.storage.GameCache'];if cache then cache.refresh() end
  if cache and self._recheckReady then self:_recheckReady() end
  self._settingsCache=nil;self._settingsRowCache=nil;self._gameSlotRows=nil
  local id=P.scope();local bank=self._bankOverlay
  if bank and bank.accountId~=id then
    if bank.tradeJob then bank.tradeJob:cancel();bank.tradeJob=nil end
    if bank.accountId then self._profileBankDrafts=self._profileBankDrafts or {};self._profileBankDrafts[bank.accountId]=bank end
    self._bankOverlay=nil
  end
  if self._saveHistoryOverlay then require('src.import.SaveHistoryWorkspace').close(self) end
  if self._refreshSlots then for _,v in ipairs(require('src.core.GameVersion').ORDER) do if self.ready and self.ready[v] then self:_refreshSlots(v) end end end
end
local function hasProgress(fs,prefix)
  for _,path in ipairs({'saves','bank','states','modstorage','mod_storage','pokewalker.lua','walker','minigames','exports'})do
    if fs.getInfo(prefix..path)then return true end
  end
  for _,v in ipairs(require('src.core.GameVersion').ORDER)do
    local suffix=require('src.core.GameVersion').saveSuffix(v)
    if suffix and fs.getInfo(prefix..'save'..suffix..'.lua')then return true end
  end
end
function P.localSources()
  local sources={}
  if hasProgress(disk(),'')then sources[#sources+1]='local' end
  local base=require('src.core.SaveData').rawPersistenceFs()
  local guest=require('src.storage.ProfileFs').guestPrefix(base)
  if guest and hasProgress(base,guest)then sources[#sources+1]='guest'end
  return sources
end
function P.bind(choice)
  local a=auth();local id=a.accountId and a.accountId()
  if not a.signedIn() or not valid(id) then return nil,'A confirmed account connection is required.' end
  local owner,why=P.owner()
  if why then return nil,why end
  if owner then return owner==id and true or nil,owner~=id and 'Existing saves and Bank belong to another account. Their assignment was preserved.' or nil end
  local bytes=S.encode({schema=1,accountId=id,linkedAt=os.time()})
  local fs,path=disk(),P.FILE
  if choice=='guest' or choice=='separate'then
    fs=require('src.core.SaveData').rawPersistenceFs()
    local prefix=choice=='guest'and require('src.storage.ProfileFs').guestPrefix(fs)or('profiles/'..id..'/')
    if not prefix then return nil,'No free local guest profile is available.' end
    if fs.read(prefix..P.FILE)then return nil,'This local profile is already assigned. Existing records were preserved.' end
    local ok,err=fs.createDirectory(prefix:sub(1,-2));if not ok then return nil,err or 'Could not create the account profile.' end
    path=prefix..P.FILE
  end
  return require('src.core.SaveSafety').atomicWrite(fs,path,bytes,{decode=function(value)
    local parsed=S.decode(value);return type(parsed)=='table' and parsed.schema==1 and valid(parsed.accountId) and parsed
  end})
end
function P.requireUI(self,after)
  local localSave=after=='history' or type(after)=='table' and after.kind=='play'
  local ok,why=(localSave and P.saveCheck or P.check)();if ok then return true end
  self:_openAccount(after)
  if self._accountOverlay then self._accountOverlay.notice=why end
  return false
end
function P.stamp(save)
  if not P.enabled then return true end
  local ok,why=P.saveCheck();if not ok then return nil,why end
  save.meta=save.meta or {};save.meta.retroAccountId=P.owner()==auth().accountId()and auth().accountId()or nil
  save.meta.localOnly=not valid(save.meta.retroAccountId) or nil;return true
end
function P.storeCheck(store)
  local ok,why=P.check();if not ok then return nil,why end
  if P.enabled and type(store)=='table' and store.accountId and store.accountId~=auth().accountId() then
    return nil,'The cloud connection belongs to another account. Reconnect before syncing.'
  end
  return true
end
function P.resume(self,after)
  if after=='bank' or after=='bankDex' then return require('src.import.BankWorkspace').open(self,after=='bankDex' and 'dex' or nil) end
  if after=='history' then return require('src.import.SaveHistoryWorkspace').open(self) end
  if type(after)=='table' and after.kind=='play' then return self:play(after.version) end
  return true
end
function P.install(RI)
  local play=RI.play
  RI.play=function(self,version,...)
    if self.workState=='working'or self.ready and not self.ready[version]then return end
    if not P.requireUI(self,{kind='play',version=version}) then return end
    if P.enabled and not valid(auth().accountId and auth().accountId()) then
      local options=self._settings and self:_settings() or require('src.core.SaveData').loadOptions()
      if not options.launcherSaveStorageChoice then
        self:_openAccount({kind='play',version=version,storagePrompt=true});return
      end
    end
    return play(self,version,...)
  end
end
return P
