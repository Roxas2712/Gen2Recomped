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
  if valid(id) then return P.check() end
  local scope=P.scope()
  if scope and scope~='guest' then return nil,'The account changed during this operation. Existing records were preserved.' end
  return true
end
function P.profileChanged(self)
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
function P.bind()
  local a=auth();local id=a.accountId and a.accountId()
  if not a.signedIn() or not valid(id) then return nil,'A confirmed account connection is required.' end
  local owner,why=P.owner()
  if why then return nil,why end
  if owner then return owner==id and true or nil,owner~=id and 'Existing saves and Bank belong to another account. Their assignment was preserved.' or nil end
  local bytes=S.encode({schema=1,accountId=id,linkedAt=os.time()})
  return require('src.core.SaveSafety').atomicWrite(disk(),P.FILE,bytes,{decode=function(value)
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
  save.meta=save.meta or {};save.meta.retroAccountId=auth().accountId()
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
