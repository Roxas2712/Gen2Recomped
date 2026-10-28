-- One account-private snapshot, with optimistic concurrency and no reward merge.
-- Reuses ModCompass objects, device authentication and normal save-slot links.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local C={PATH='profiles/pokewalker/state.lua',STATE='cloud_sync_walker.lua',MAX=2*1024*1024}
local S=require('src.core.SaveSerializer')
local Safety=require('src.core.SaveSafety')
local Saves=require('src.core.SaveData')
local W=require('src.pokewalker.Walker')
local Cloud=require('src.import.CloudSync')
local Policy=require('src.storage.AccountStorage')
local function hash(bytes)return Cloud.hash(bytes)end
local function decode(bytes)
 if type(bytes)~='string'or #bytes>C.MAX then return end
 local ok,doc=pcall(S.decode,bytes)
 if not ok or type(doc)~='table'or doc.schema~=1 or type(doc.accountId)~='string'
  or not doc.accountId:match('^[1-9][0-9]*$')or type(doc.state)~='table'then return end
 local st=doc.state
 local nodes=0
 local function bounded(value,depth)
  nodes=nodes+1
  if nodes>32768 or depth>32 then return false end
  if type(value)=='number'then return value==value and value~=math.huge and value~=-math.huge end
  if type(value)=='string'then return #value<=16384 end
  if type(value)=='table'then
   for key,child in pairs(value)do
    if not bounded(key,depth+1)or not bounded(child,depth+1)then return false end
   end
  end
  return true
 end
 if not bounded(st,0)then return end
 if st.format~=1 then return end
 for _,key in ipairs{'watts','lifetimeWatts','lifetimeSteps','stepRemainder','days','course'}do
  local v=st[key];if type(v)~='number'or v~=v or v<0 or v>1e12 then return end
 end
 if st.course%1~=0 or st.course>26 then return end
 for _,key in ipairs{'history','caught','items','finds','events','log','settings','notices'}do if type(st[key])~='table'then return end end
 if st.walking~=nil then
  local a=st.walking;local src=type(a)=='table'and a.source
  if type(src)~='table'or type(a.raw)~='table'or not require('src.core.GameVersion').info(src.version)
   or type(src.cloudId)~='string'or #src.cloudId>100 or not src.cloudId:match('^[%w_%-]+$')or src.slot~=nil then return end
 end
 return doc
end
C.decode=decode
local function capture(store)
 local live=W.peek()
 if not live and not W.exists()then return nil end
 local st=S.decode(S.encode(live or W.load()))
 if W.recoveryError then return nil,W.recoveryError end
 st.stepsJournal=nil -- Native sensor receipts belong to this device only.
 if st.walking then
  local src=st.walking.source
  local links=Cloud.loadState(Cloud.stateKey(store)).links
  local link=src and links[src.version]and links[src.version][src.slot]
  if not link then return nil,'Sync the walking Pokémon’s source save first. Your walk is preserved.'end
  local saved=Saves.persistenceFs().read('saves/'..src.version..'/'..tostring(src.slot)..'.lua')
  if not saved or hash(saved)~=link.hash then return nil,'Sync the walking Pokémon’s source save first. Your walk is preserved.'end
  src.cloudId=link.cloudId;src.slot=nil
 end
 return {schema=1,accountId=store.accountId,state=st}
end
C.capture=capture
local function restore(store,doc)
 local copy=S.decode(S.encode(doc.state))
 local localState=W.peek()
 copy.stepsJournal=localState and localState.stepsJournal
 if not copy.stepsJournal then
  local journal=require('src.core.StepJournal').read(love.filesystem)
  if journal then copy.stepsJournal={epoch=journal.epoch,total=journal.total,to=journal.to}end
 end
 if copy.walking then
  local src=copy.walking.source;local links=Cloud.loadState(Cloud.stateKey(store)).links
  local matches={}
  for slot,link in pairs(links[src.version]or{})do if link.cloudId==src.cloudId then matches[#matches+1]=slot end end
  if #matches~=1 then return nil,'Restore the walking Pokémon’s source save before restoring the Pokéwalker.'end
  src.slot=matches[1];src.cloudId=nil
  local save=Saves.peekSlot(src.version,src.slot)
  if not save then return nil,'Restore the walking Pokémon’s source save before restoring the Pokéwalker.'end
  local needle=S.encode(copy.walking.raw)
  local function contains(value,depth)
   if type(value)~='table'or depth>12 then return false end
   if value.species and S.encode(value)==needle then return true end
   for _,child in pairs(value)do if type(child)=='table'and contains(child,depth+1)then return true end end
   return false
  end
  if contains(save,0)then return nil,'This Pokémon is already in the source save. Both Pokéwalker copies were preserved.'end
  local open=Saves.slotOpenElsewhere(src.version,src.slot)
  if open then return nil,'Close the source game before restoring its Pokéwalker.'end
 end
 return W.adopt(copy)
end
local function sync(store,restoreOnly)
 local ok,why=Policy.storeCheck(store);if not ok then return nil,why end
 if store.kind~='retro'or store.accountId~=require('src.cloud.RetroCloud').accountId()then return nil,'Connect your ModCompass account to sync the Pokéwalker.'end
 local disk=W.storage();local owner=store.accountId
 local function current()
  local yes,err=Policy.storeCheck(store)
  if not yes or W.storage()~=disk or require('src.cloud.RetroCloud').accountId()~=owner then return nil,err or 'The active account changed.'end
  return true
 end
 local localDoc,problem=capture(store);if problem then return nil,problem end
 local localBytes=localDoc and S.encode(localDoc);local localHash=localBytes and hash(localBytes)
 local baseline={schema=1};local previous=disk.read(C.STATE)
 if previous then
  local parsed,value=pcall(S.decode,previous)
  if not parsed or type(value)~='table'or value.schema~=1 then return nil,'Pokéwalker sync history needs recovery. Local progress was preserved.'end
  baseline=value
 end
 local raw=store.read(C.PATH)
 if not current()then return nil,'The active account changed.'end
 local remote=raw and decode(raw)
 if raw and(not remote or remote.accountId~=owner)then return nil,'Invalid cloud Pokéwalker. Local progress was preserved.'end
 local remoteHash=remote and hash(S.encode(remote))
 local result,finalHash
 if not localDoc and not remote then return 'empty'end
 if localHash==remoteHash then result='current';finalHash=remoteHash
 elseif restoreOnly and localDoc and baseline.localHash~=localHash then
  -- Login restoration never discards local walks, watts or unclaimed prizes.
  return nil,'Pokéwalker changed on both devices. Both copies were preserved; resolve the conflict before continuing.'
 elseif not localDoc or baseline.localHash==localHash then
  if not remote then
   if localDoc then return nil,'The cloud Pokéwalker is missing. Local progress was preserved.'end
   return 'empty'
  end
  local restored,err=restore(store,remote);if not restored then return nil,err end
  result='restored';finalHash=remoteHash
 elseif not remote and not baseline.remoteHash or remoteHash==baseline.remoteHash then
  if restoreOnly then return 'local'end
  local written,err=store.write(C.PATH,localBytes)
  if not written then return nil,err end
  if not current()then return nil,'The active account changed.'end
  result='uploaded';finalHash=localHash
 else
  local path='walker/conflicts/'..tostring(remoteHash)..'.lua'
  local saved,err=Safety.atomicWrite(disk,path,raw,{decode=Safety.decodeAny})
  if not saved then return nil,err end
  return nil,'Pokéwalker changed on both devices. Both copies were preserved; resolve the conflict before continuing.'
 end
 local written,err=Safety.atomicWrite(disk,C.STATE,S.encode({schema=1,localHash=finalHash,remoteHash=finalHash}),{decode=Safety.decodeAny})
 if not written then return nil,err end
 return result
end
function C.sync(store,restoreOnly)
 if W.syncing then return nil,'Pokéwalker sync is already running.'end
 local hub=package.loaded['src.ui.WalkerMinigames']
 local run=hub and hub.active and hub.active.session
 if run and run.phase~='intro'and run.phase~='results'then return 'playing'end
 W.syncing=true;W.syncTask=coroutine.running()or'main'
 local ok,result,why=pcall(sync,store,restoreOnly)
 W.syncing=nil;W.syncTask=nil
 if not ok then return nil,tostring(result)end
 return result,why
end

-- Choices bind to both complete snapshots; changed/account-switched previews
-- must be reviewed again. The normal object-store revision guard still wins.
local function exclusive(store,fn)
 if W.syncing then return nil,'Pokéwalker sync is already running.'end
 local allowed,why=Policy.storeCheck(store);if not allowed then return nil,why end
 local fs,owner=W.storage(),require('src.cloud.RetroCloud').accountId()
 if store.kind~='retro'or store.accountId~=owner then return nil,'Connect your ModCompass account to sync the Pokéwalker.'end
 local hub=package.loaded['src.ui.WalkerMinigames']
 local run=hub and hub.active and hub.active.session
 if run and run.phase~='intro'and run.phase~='results'then return nil,'Finish the active minigame before reviewing cloud progress.'end
 local function current()
  local yes,err=Policy.storeCheck(store)
  if not yes or W.storage()~=fs or require('src.cloud.RetroCloud').accountId()~=owner then
   return nil,err or 'The active account changed.'
  end
  return true
 end
 W.syncing=true;W.syncTask=coroutine.running()or'main'
 local ok,value,err=pcall(fn,fs,owner,current)
 W.syncing=nil;W.syncTask=nil
 if not ok then return nil,tostring(value)end
 return value,err
end
local function pair(store,current)
 local localDoc,why=capture(store);if not localDoc then return nil,why or 'No local Pokéwalker progress to review.'end
 local localBytes=S.encode(localDoc)
 local raw=store.read(C.PATH);local yes,err=current();if not yes then return nil,err end
 local remote=raw and decode(raw)
 if not remote or remote.accountId~=store.accountId then return nil,'Invalid cloud Pokéwalker. Local progress was preserved.'end
 return{localDoc=localDoc,localBytes=localBytes,localHash=hash(localBytes),
   remote=remote,raw=raw,remoteHash=hash(S.encode(remote))}
end
function C.review(store)
 return exclusive(store,function(_,owner,current)
  local p,why=pair(store,current);if not p then return nil,why end
  if p.localHash==p.remoteHash then return nil,'Pokéwalker progress is already current.'end
  return{accountId=owner,localHash=p.localHash,remoteHash=p.remoteHash,
   localWatts=p.localDoc.state.watts,cloudWatts=p.remote.state.watts,
   localWalking=p.localDoc.state.walking and p.localDoc.state.walking.name,
   cloudWalking=p.remote.state.walking and p.remote.state.walking.name}
 end)
end
function C.resolve(store,preview,choice)
 if choice~='local'and choice~='cloud'then return nil,'Choose a complete local or cloud version.'end
 return exclusive(store,function(fs,owner,current)
  local p,why=pair(store,current);if not p then return nil,why end
  if type(preview)~='table'or preview.accountId~=owner
   or preview.localHash~=p.localHash or preview.remoteHash~=p.remoteHash then
   return nil,'Pokéwalker progress changed. Review both versions again.'
  end
  for _,copy in ipairs{{'local',p.localHash,p.localBytes},{'cloud',p.remoteHash,p.raw}}do
   local path='walker/conflicts/'..copy[1]..'-'..copy[2]..'.lua'
   local saved,err=Safety.atomicWrite(fs,path,copy[3],{decode=Safety.decodeAny})
   if not saved then return nil,err end
  end
  local yes,err=current();if not yes then return nil,err end
  local finalHash
  if choice=='cloud'then
   local restored,problem=restore(store,p.remote);if not restored then return nil,problem end
   finalHash=p.remoteHash
  else
   local written,problem=store.write(C.PATH,p.localBytes);if not written then return nil,problem end
   finalHash=p.localHash
  end
  yes,err=current();if not yes then return nil,err end
  local written,problem=Safety.atomicWrite(fs,C.STATE,S.encode({schema=1,localHash=finalHash,remoteHash=finalHash}),{decode=Safety.decodeAny})
  if not written then return nil,problem end
  return choice=='cloud'and'restored'or'uploaded'
 end)
end
return C
