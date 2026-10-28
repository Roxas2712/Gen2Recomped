-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- A durable intent joins the native source-save and account-local walker writes.
local M={FILE='walker_transfer.lua'}
local S=require('src.core.SaveSerializer')
local Safety=require('src.core.SaveSafety')
local Saves=require('src.core.SaveData')
local function decode(raw)
  local ok,value=pcall(S.decode,raw)
  if ok and type(value)=='table'and value.schema==1 then return value end
end
local function read(fs)
  for _,suffix in ipairs{'','.tmp','.bak'}do
    local raw=fs.read(M.FILE..suffix)
    if raw then
      local t=decode(raw)
      if not t then return nil,'The Pokémon transfer journal needs recovery. Its files were preserved.'end
      if t.status=='complete'then return false end
      if t.status~='pending'or type(t.id)~='string'or type(t.version)~='string'
        or not require('src.core.GameVersion').info(t.version)
        or type(t.slot)~='string'or #t.slot>100 or not t.slot:match('^[%w_-]+$')
        or type(t.saveBefore)~='string'or type(t.saveAfter)~='table'
        or type(t.walkerAfter)~='string'or t.walkerBefore~=nil and type(t.walkerBefore)~='string'
        or t.saveAfter.walkerTransfer~=t.id or t.scope~=(fs._accountPrefix or'')then
        return nil,'The Pokémon transfer journal is incomplete. Its files were preserved.'
      end
      local ok,walker=pcall(S.decode,t.walkerAfter)
      if not ok or type(walker)~='table'or walker.format~=1 or walker.transferReceipt~=t.id then
        return nil,'The Pokémon transfer journal is incomplete. Its files were preserved.'
      end
      return t
    end
  end
  return false
end
function M.pending(fs)
  local t,why=read(fs);return t~=false,why
end
local function write(fs,file,bytes)
  local ok,why=Safety.atomicWrite(fs,file,bytes,{bak=file..'.bak',decode=Safety.decodeAny})
  if not ok then return nil,why end
  return true
end
local function current(fs)
  if Saves.persistenceFs()~=fs then return nil,'The active account changed. The transfer is preserved.'end
  local policy=package.loaded['src.storage.AccountStorage']
  if policy and policy.enabled then return policy.saveCheck()end
  return true
end
function M.recover(fs,walkerFile)
  local t,why=read(fs)
  if t==false then return true end
  if not t then return nil,why end
  local yes,err=current(fs);if not yes then return nil,err end
  local path='saves/'..t.version..'/'..t.slot..'.lua'
  local bytes=fs.read(path)
  local ok,save=pcall(S.decode,bytes)
  if not ok or type(save)~='table'then return nil,'The source save needs recovery. The Pokémon transfer is preserved.'end
  local walkerBytes=fs.read(walkerFile)
  if walkerBytes~=t.walkerBefore and walkerBytes~=t.walkerAfter then
    return nil,'The Pokéwalker changed during a pending transfer. Both copies were preserved.'
  end
  if save.walkerTransfer~=t.id then
    if bytes~=t.saveBefore then return nil,'The source save changed during a pending transfer. Both copies were preserved.'end
    if Saves.slotOpenElsewhere(t.version,t.slot)then return nil,'Close the source game before recovering its Pokémon transfer.'end
    yes,err=current(fs);if not yes then return nil,err end
    local written,problem=Saves.writeSlot(t.version,t.slot,S.decode(S.encode(t.saveAfter)))
    if not written then return nil,problem end
    -- A writer reporting success must have published the actual native slot.
    local raw=fs.read(path);local valid,published=pcall(S.decode,raw)
    if not valid or type(published)~='table'or published.walkerTransfer~=t.id then
      return nil,'The source save did not verify. The Pokémon transfer is preserved.'
    end
  end
  yes,err=current(fs);if not yes then return nil,err end
  if walkerBytes~=t.walkerAfter then
    local written,problem=write(fs,walkerFile,t.walkerAfter)
    if not written then return nil,problem end
  end
  yes,err=current(fs);if not yes then return nil,err end
  return write(fs,M.FILE,S.encode{schema=1,status='complete',id=t.id})
end
function M.commit(fs,walkerFile,version,slot,before,save,walker)
  local pending,why=M.pending(fs)
  if pending then return nil,why or 'Reopen the Pokéwalker to recover its pending Pokémon transfer.'end
  local yes,err=current(fs);if not yes then return nil,err end
  if type(slot)~='string'or #slot>100 or not slot:match('^[%w_-]+$')
    or not require('src.core.GameVersion').info(version)then return nil,'Invalid source save.'end
  if fs.read('saves/'..version..'/'..slot..'.lua')~=before then return nil,'The source save changed. Reopen the Pokémon list.'end
  local afterSave=S.decode(S.encode(save));local afterWalker=S.decode(S.encode(walker))
  local id=require('src.import.CloudSync').hash(S.encode{before=before,walker=fs.read(walkerFile),after=afterSave,state=afterWalker})
  afterSave.walkerTransfer=id;afterWalker.transferReceipt=id
  local record={schema=1,status='pending',id=id,version=version,slot=slot,
    scope=fs._accountPrefix or'',
    saveBefore=before,saveAfter=afterSave,walkerBefore=fs.read(walkerFile),walkerAfter=S.encode(afterWalker)}
  local written,problem=write(fs,M.FILE,S.encode(record))
  if not written then return nil,problem end
  local recovered,recoveryError=M.recover(fs,walkerFile)
  if not recovered then return nil,recoveryError end
  return true,afterWalker
end
return M
