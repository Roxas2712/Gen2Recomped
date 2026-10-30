-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared package publication, bounded recovery records and exact-root guards.
local Cache=require('src.import.CacheFs')
local Json=require('src.link.Json')
local Saves=require('src.core.SaveData')
local Merge=require('src.mods.Merge')
local Jobs=require('src.mods.ModInstallJob')
local T={}
local function raw(path)
  local info=love.filesystem.getInfo(path,'file')
  assert(not info or not info.size or info.size<=1024*1024,'Installer metadata exceeds its limit.')
  return love.filesystem.read(path,1024*1024+1)
end
local function receiptName(token)return 'mod-install-journal/'..token..'.json'end
local function writeReceipt(record,job)
  local path=receiptName(record.token);local bytes=Json.encode(record)
  assert(Cache.rawCreateDirectory('mod-install-journal'),'Could not create installation recovery folder.')
  local file=job:track(assert(Cache.dataFs().newFile(path..'.tmp','w'),'Could not open installation recovery record.'))
  local wrote,why=file:write(bytes);local closed,closeWhy=pcall(job.close,job,file)
  assert(wrote and closed,why or closeWhy or 'Could not write installation recovery record.')
  assert(raw(path..'.tmp')==bytes,'Installation recovery record did not read back whole.')
  local ok,why=Cache.rawRename(path..'.tmp',path);assert(ok,why or 'Could not publish installation recovery record.')
end
function T.start(job)
  if job.stagingReceipt then return end
  job.stagingReceipt=receiptName(job.token)
  writeReceipt({schema=1,state='staging',token=job.token,root=job.root,area=job.area},job)
end
local function priorOptions(id)
  local options=Saves.loadOptions() or{}
  return {enabled=Merge.deepCopy((options.mods or{})[id]),source=Merge.deepCopy((options.modInstallSources or{})[id])}
end
local function restoreOptions(record)
  local options=Merge.deepCopy(Saves.loadOptions()or{})
  options.mods=options.mods or{};options.modInstallSources=options.modInstallSources or{}
  options.mods[record.id]=record.prior.enabled
  options.modInstallSources[record.id]=record.prior.source
  assert(Saves.saveOptions(options),'Could not restore installation metadata.')
end
local function validate(record,path,job)
  assert(type(record)=='table' and record.schema==1 and type(record.token)=='string' and
    record.token:match('^install%-%d+%-%d+%-%d+$') and path==receiptName(record.token),'Invalid installer recovery record.')
  assert(Jobs.sameRoot(record.root,job.root),'Installer recovery belongs to a different data folder.')
  assert(record.area=='mod-install-staging/'..record.token,'Invalid installer staging folder.')
  if record.state=='staging' then return end
  if record.state=='profile_cleanup' then
    assert(type(record.profileRoot)=='string'and record.profileRoot:match('^mod%-profile%-backups/%d+%-%d+$')and
      type(record.profileMarker)=='string'and #record.profileMarker<=1024*1024,'Invalid profile cleanup record.')
    return
  end
  assert(type(record.id)=='string' and record.id:match('^[%w_%-][%w_.%-]*$'),'Invalid recovery mod ID.')
  assert(type(record.dest)=='string' and record.dest:match('^mods/[%w_%-][%w_.%-]*$'),'Invalid recovery destination.')
  assert(record.area=='mod-install-staging/'..record.token and record.stage==record.area..'/package' and
    record.backup==record.area..'/previous','Invalid installer recovery paths.')
  assert(record.state=='prepared' or record.state=='committed' or record.state=='withdrawing' or record.state=='withdrawn','Invalid installer recovery state.')
  assert((type(record.next)=='string' and #record.next<=1024*1024 or record.state=='withdrawing' or record.state=='withdrawn') and
    (record.before==nil or type(record.before)=='string' and #record.before<=1024*1024) and type(record.prior)=='table',
    'Invalid installer recovery metadata.')
  if record.next then assert(Json.decode(record.next).id==record.id,'Recovery replacement identity differs.')end
  if record.before then assert(Json.decode(record.before).id==record.id,'Recovery previous identity differs.')end
end
local function rollback(record,job)
  job.pendingReceipt=receiptName(record.token)
  local fs=love.filesystem
  local backup=fs.getInfo(record.backup)
  local current=raw(record.dest..'/manifest.json')
  if backup then
    if fs.getInfo(record.dest)then
      assert(current==record.next,'Installed package changed during recovery; previous files are preserved at '..record.backup)
      assert(not fs.getInfo(record.stage),'Recovery staging already exists.')
      assert(Cache.rawRename(record.dest,record.stage),'Could not retain the incomplete replacement.')
    end
    assert(Cache.rawRename(record.backup,record.dest),'Could not restore the previous complete package.')
  elseif record.before==nil and fs.getInfo(record.dest)then
    assert(current==record.next,'A different package now occupies the recovery destination.')
    assert(not fs.getInfo(record.stage),'Recovery staging already exists.')
    assert(Cache.rawRename(record.dest,record.stage),'Could not withdraw the uncommitted replacement.')
  elseif record.before~=nil then
    assert(current==record.before,'The previous package is unavailable; recovery files were preserved.')
  end
  restoreOptions(record)
  job:removeOwned(record.area,true)
  job:removeOwned(receiptName(record.token),false)
  job.pendingReceipt=nil
end
function T.recover(job)
  local fs=love.filesystem
  for _,name in ipairs(fs.getDirectoryItems('mod-install-journal'))do
    assert(name:match('^install%-%d+%-%d+%-%d+%.json$') or name:match('^install%-%d+%-%d+%-%d+%.json%.tmp$'),
      'Unknown installer recovery file; no installed packages were changed.')
    local path='mod-install-journal/'..name
    if name:sub(-4)=='.tmp' then
      -- A staging record alone cannot authorize moving an installed package.
      job:removeOwned(path,false)
    else
      local record=Json.decode(assert(raw(path),'Unreadable installer recovery record.'))
      validate(record,path,job)
      if record.state=='profile_cleanup' then
        job.pendingReceipt=path;job.committed=true
        local persistence=Saves.persistenceFs()
        local current=persistence.read('mod_profile_recovery.lua')
        assert(current==nil or current==record.profileMarker,'Profile recovery changed; preserved files were kept.')
        if current then assert(persistence.remove('mod_profile_recovery.lua'),'Could not retire profile recovery marker.')end
        job:removeProfile(record.profileRoot,true)
        job:removeOwned(record.area,true);job:removeOwned(path,false)
        job.pendingReceipt=nil;job.committed=false
      elseif record.state=='committed' or record.state=='staging' or record.state=='withdrawn' then
        job.committed=true;job.pendingReceipt=path
        job:removeOwned(record.area,true);job:removeOwned(path,false)
        job.pendingReceipt=nil;job.committed=false
      else
        -- Recovery is itself non-cancellable until the old complete package is
        -- back. Its only potentially large cleanup runs after restoration.
        rollback(record,job)
      end
    end
    job:checkpoint('recovering',0,0)
  end
end
function T.publish(job,source,dest,manifest,installedRaw,clone,opts,checkCheckout,unmount)
  local fs=love.filesystem
  local before=raw(dest..'/manifest.json')
  if fs.getInfo(dest) then
    assert(not checkCheckout(dest),'A source checkout cannot be replaced by the installer.')
    local actual=fs.getRealDirectory and fs.getRealDirectory(dest..'/manifest.json')
    assert(Jobs.sameRoot(actual,job.root),
      'This package is outside the selected writable data folder. Its existing files have been kept.')
  end
  local stage=job.area..'/package'
  job:copyTree(source,stage,'copying')
  if installedRaw then job:write(stage..'/manifest.json',installedRaw)end
  if before and fs.getInfo(dest..'/baseroms','directory')then job:copyTree(dest..'/baseroms',stage..'/baseroms','retaining imports')end
  local nextRaw=assert(raw(stage..'/manifest.json'),'Prepared manifest is missing.')
  local nextManifest=Json.decode(nextRaw)
  assert(nextManifest.id==manifest.id and nextManifest.version==manifest.version,'Prepared package identity changed.')
  unmount()
  job:checkpoint('ready to install',1,1)
  assert(raw(dest..'/manifest.json')==before,'Installed package changed while preparing; retry the import.')
  assert(not checkCheckout(dest),'A source checkout now occupies the destination.')
  if before then assert(Jobs.sameRoot(fs.getRealDirectory(dest..'/manifest.json'),job.root),'The installed package moved.')end
  local record={schema=1,token=job.token,root=job.root,area=job.area,stage=stage,backup=job.area..'/previous',
    dest=dest,id=manifest.id,before=before,next=nextRaw,prior=priorOptions(manifest.id),state='prepared'}
  local ok,why=pcall(function()
    writeReceipt(record,job);job.pendingReceipt=receiptName(job.token)
    assert(Cache.rawCreateDirectory('mods'),'Could not create the mod folder.')
    if before then assert(Cache.rawRename(dest,record.backup),'Could not preserve the previous complete package.')end
    assert(Cache.rawRename(stage,dest),'Could not publish the prepared package.')
    assert(raw(dest..'/manifest.json')==nextRaw,'Another file location is hiding the installed package.')
    local options=Merge.deepCopy(Saves.loadOptions()or{})
    if clone and not opts.replace then options.mods=options.mods or{};options.mods[manifest.id]=false end
    if manifest.github and manifest.updateCheck~=false then
      options.modInstallSources=options.modInstallSources or{}
      options.modInstallSources[manifest.id]={repo=manifest.github,version=manifest.version,source='manifest'}
    end
    assert(Saves.saveOptions(options),'Could not save installed package metadata.')
    record.state='committed';writeReceipt(record,job)
    job.committed=true
  end)
  if not ok then
    if job.pendingReceipt then
      local restored,reason=pcall(rollback,record,job)
      if not restored then error(tostring(why)..'; recovery retained: '..tostring(reason),0)end
    end
    error(why,0)
  end
  job.completed[#job.completed+1]=manifest.id
  -- Cleanup can span frames, but cancellation cannot undo a published package.
  local cleaned,cleanupWhy=pcall(function()
    job:removeOwned(job.area,true);job:removeOwned(receiptName(job.token),false)
  end)
  if cleaned then job.pendingReceipt=nil;job.stagingReceipt=nil
  else job.warning='Installed successfully; cleanup will resume next launch: '..tostring(cleanupWhy)end
  return true,manifest.id,manifest.version
end
function T.withdraw(job,dest,id,checkCheckout)
  local before=raw(dest..'/manifest.json');if not before then return true end
  assert(Json.decode(before).id==id,'A different package occupies the profile recovery destination.')
  assert(not checkCheckout(dest)and Jobs.sameRoot(love.filesystem.getRealDirectory(dest..'/manifest.json'),job.root),
    'Profile recovery cannot remove this package location.')
  job:checkpoint('restoring profile',0,0)
  assert(raw(dest..'/manifest.json')==before,'Package changed during profile recovery.')
  assert(Cache.rawCreateDirectory(job.area),'Could not create profile recovery staging.')
  local record={schema=1,state='withdrawing',token=job.token,root=job.root,area=job.area,stage=job.area..'/package',
    backup=job.area..'/previous',dest=dest,id=id,before=before,prior=priorOptions(id)}
  writeReceipt(record,job);job.pendingReceipt=receiptName(job.token)
  assert(Cache.rawRename(dest,record.backup),'Could not withdraw the added package.')
  record.state='withdrawn';writeReceipt(record,job);job.committed=true
  job:removeOwned(job.area,true);job:removeOwned(receiptName(job.token),false)
  job.pendingReceipt=nil;job.stagingReceipt=nil;job.committed=false
  return true
end
function T.finishProfile(job,snapshot)
  local fs=Saves.persistenceFs();local bytes=assert(fs.read('mod_profile_recovery.lua'),'Profile recovery marker is missing.')
  local stored=require('src.core.SaveSerializer').decode(bytes)
  assert(stored.root==snapshot.root,'Profile recovery marker changed.')
  local record={schema=1,state='profile_cleanup',token=job.token,root=job.root,area=job.area,
    profileRoot=snapshot.root,profileMarker=bytes}
  writeReceipt(record,job);job.pendingReceipt=receiptName(job.token);job.committed=true
  assert(fs.remove('mod_profile_recovery.lua'),'Could not commit the completed mod profile.')
  local ok,why=pcall(function()
    job:removeProfile(snapshot.root,true);job:removeOwned(receiptName(job.token),false)
  end)
  if ok then job.pendingReceipt=nil;job.committed=false
  else job.warning='Profile committed; cleanup resumes next launch: '..tostring(why)end
  return true
end
return T
