-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Cooperative backup/restore around the existing native profile format.
local Packages=require('src.mods.LauncherMods')
local Saves=require('src.core.SaveData')
local Safety=require('src.core.SaveSafety')
local Serialize=require('src.core.SaveSerializer')
local Merge=require('src.mods.Merge')
local Txn=require('src.mods.ModInstallTransaction')
local J=require('src.mods.ModInstallJob')
local P={}
local function valid(snapshot)
 assert(type(snapshot)=='table'and type(snapshot.root)=='string'and snapshot.root:match('^mod%-profile%-backups/%d+%-%d+$')and
  type(snapshot.entries)=='table','Invalid profile recovery record.')
 for _,entry in ipairs(snapshot.entries)do
  assert(type(entry.id)=='string'and entry.id:match('^[%w_%-][%w_.%-]*$')and
   (entry.backup==nil or entry.backup==snapshot.root..'/'..entry.id),'Invalid profile recovery entry.')
 end
end
local function marker(snapshot)
 local bytes=Serialize.encode(snapshot)
 assert(Safety.atomicWrite(Saves.persistenceFs(),'mod_profile_recovery.lua',bytes,{decode=Safety.decodeAny}),
  'Could not write profile recovery record.')
 return bytes
end
function P.cancelDraft(job,yielding)
 local draft=job.profileDraft;local fs=Saves.persistenceFs()
 assert(fs.read('mod_profile_recovery.lua')==draft.bytes,'Profile preparation marker changed; files were preserved.')
 job:removeProfile(draft.root,yielding)
 assert(fs.remove('mod_profile_recovery.lua'),'Could not retire cancelled profile preparation.')
 job.profileDraft=nil
end
function P.backup(job,ids)
 assert(not Saves.persistenceFs().read('mod_profile_recovery.lua'),'Recover the unfinished mod profile first.')
 local options=Saves.loadOptions()
 local snapshot={root=('mod-profile-backups/%d-%d'):format(os.time(),math.random(1,999999999)),entries={},
  mods=Merge.deepCopy(options.mods or{}),sources=Merge.deepCopy(options.modInstallSources or{}),
  syncState=Saves.persistenceFs().read('mod_profile_sync.lua'),preparing=true}
 for _,id in ipairs(ids)do
  assert(type(id)=='string'and id:match('^[%w_%-][%w_.%-]*$'),'Invalid mod ID.')
  local folder=Packages.folderFor(id)
  if folder then
   assert(not Packages.checkoutAt(folder),'A source checkout cannot be replaced by a profile.')
   assert(J.sameRoot(love.filesystem.getRealDirectory(folder..'/manifest.json'),job.root),'Profile package is outside the writable data folder.')
  end
  snapshot.entries[#snapshot.entries+1]={id=id,backup=folder and(snapshot.root..'/'..id)or nil,folder=folder}
 end
 job.profileDraft={root=snapshot.root,bytes=marker(snapshot)}
 for _,entry in ipairs(snapshot.entries)do
  if entry.folder then job:copyTree(entry.folder,entry.backup,'preserving profile')end
  job:checkpoint('preserving profile',0,0)
 end
 snapshot.preparing=nil;marker(snapshot);job.profileDraft=nil
 return snapshot
end
function P.restore(job,snapshot)
 valid(snapshot)
 if snapshot.preparing then
  job.profileDraft={root=snapshot.root,bytes=assert(Saves.persistenceFs().read('mod_profile_recovery.lua'))}
  P.cancelDraft(job,true);return true
 end
 for _,entry in ipairs(snapshot.entries)do
  local folder=Packages.folderFor(entry.id)
  if folder then
   assert(not Packages.checkoutAt(folder),'A source checkout now occupies '..entry.id)
   assert(J.sameRoot(love.filesystem.getRealDirectory(folder..'/manifest.json'),job.root),'Profile recovery destination is not writable.')
  end
  assert(not entry.backup or love.filesystem.getInfo(entry.backup..'/manifest.json'),'A profile recovery copy is missing.')
 end
 for _,entry in ipairs(snapshot.entries)do
  local folder=Packages.folderFor(entry.id)or('mods/'..entry.id)
  if entry.backup then
   local bytes=assert(love.filesystem.read(entry.backup..'/manifest.json'))
   local manifest=require('src.mods.Manifest').validate(require('src.link.Json').decode(bytes),entry.backup)
   assert(manifest.id==entry.id,'Profile recovery package identity differs.')
   Txn.start(job)
   Txn.publish(job,entry.backup,folder,manifest,nil,false,{replace=true},Packages.checkoutAt,function()end)
   job:finishItem()
  else Txn.withdraw(job,folder,entry.id,Packages.checkoutAt)end
  assert(not job.halted,'Installation cleanup must finish before restoring the profile.')
 end
 local options=Merge.deepCopy(Saves.loadOptions())
 options.mods=Merge.deepCopy(snapshot.mods or{});options.modInstallSources=Merge.deepCopy(snapshot.sources or{})
 assert(Saves.saveOptions(options),'Could not restore profile activation.')
 local fs=Saves.persistenceFs()
 if snapshot.syncState then
  assert(Safety.atomicWrite(fs,'mod_profile_sync.lua',snapshot.syncState,{decode=Safety.decodeAny}),'Could not restore profile sync metadata.')
 elseif fs.getInfo('mod_profile_sync.lua')then assert(fs.remove('mod_profile_sync.lua'),'Could not retire profile sync metadata.')end
 return Txn.finishProfile(job,snapshot)
end
function P.recover(job)
 local bytes=Saves.persistenceFs().read('mod_profile_recovery.lua')
 if not bytes then return true end
 return P.restore(job,Serialize.decode(bytes))
end
return P
