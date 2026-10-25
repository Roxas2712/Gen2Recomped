-- RetroRecomped's account policy is enabled by its app bootstrap. The engine
-- remains usable by headless tools without network or account dependencies.
local P={FILE='storage_account.lua',enabled=false}
local S=require('src.core.SaveSerializer')
local function auth() return require('src.cloud.RetroCloud') end
local function disk() return require('src.core.SaveData').persistenceFs() end
local function valid(id) return type(id)=='string' and #id<=20 and id:match('^[1-9][0-9]*$') end
function P.enable() P.enabled=true end
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
  if not valid(id) then return nil,'Register or sign in and confirm your email before using saves or the Bank.' end
  local owner,why=P.owner()
  if why then return nil,why end
  if not owner then return nil,'Link the local saves and Bank to your confirmed account first.' end
  if owner~=id then return nil,'These local saves and Bank belong to another account. Sign in with that account; no files were reassigned.' end
  return true
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
  local ok,why=P.check();if ok then return true end
  self:_openAccount(after)
  if self._accountOverlay then self._accountOverlay.notice=why end
  return false
end
function P.stamp(save)
  if not P.enabled then return true end
  local ok,why=P.check();if not ok then return nil,why end
  save.meta=save.meta or {};save.meta.retroAccountId=auth().accountId();return true
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
    return play(self,version,...)
  end
end
return P
