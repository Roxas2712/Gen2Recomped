-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local root=assert(os.getenv('INSTALL_ENGINE_ROOT'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
io.stdout:setvbuf('no');io.stderr:setvbuf('no')
local checks,co=0
local function check(value,why)checks=checks+1;assert(value,why)end
local function eq(a,b,why)check(a==b,(why or 'equality')..': '..tostring(a)..' != '..tostring(b))end
function love.errorhandler(message)
 print('Installer runtime failed: '..tostring(message)..'\n'..debug.traceback(co))
 return function()return 1 end
end
local function run()
 local fs=love.filesystem;local Json=require('src.link.Json')
 local file=assert(io.open(assert(os.getenv('INSTALL_QA_CONFIG')),'rb'))
 local config=Json.decode(file:read('*a'));file:close()
 check(fs.getSaveDirectory():find('oasc-mod-installer-qa-',1,true),'isolated test profile')
 check(fs.createDirectory(''),'mount the fresh QA save root before raw IO')
 local Cache=require('src.import.CacheFs');local Saves=require('src.core.SaveData')
 -- Pin all native writers to this fresh QA profile. No source/player mounts.
 Cache.root=function()return nil end
 Saves.otherLocations=function()return{}end;Saves.gameFolders=function()return{}end
 Saves.persistenceFs=function()return Cache.dataFs()end
 local loadOptions,saveOptions=Saves.loadOptions,Saves.saveOptions
 Saves.loadOptions=function()return loadOptions(Cache.dataFs())end
 Saves.saveOptions=function(options)return saveOptions(options,Cache.dataFs())end
 local Mods=require('src.mods.LauncherMods');Cache.prefix='crystal/'
 local function step(job)
  local status,a,b,c=Mods.stepInstall(job,0)
  eq(Cache.prefix,'crystal/','no borrowed cache prefix across frames')
  coroutine.yield()
  return status,a,b,c
 end
 local function drain(job)
  for _=1,5000 do local status,a,b,c=step(job);if status=='done'then return a,b,c end end
  error('installer did not terminate')
 end
 local function untilPhase(job,phase)
  for _=1,5000 do local status=step(job);assert(status~='done','missing phase '..phase)
   if job.progress.phase==phase then return end end
  error('phase timed out')
 end
 local ok,id=drain(assert(Mods.beginInstallZip(config.v1)))
 eq(ok,true,'real ZIP install: '..tostring(id));eq(id,'nativeprobe','manifest identity')
 Cache.root=function()return fs.getSaveDirectory()end
 eq(fs.read('mods/nativeprobe/main.lua'),config.entry,'native entry is byte-exact')
 check(fs.getInfo('crystal/mods')==nil,'mods are not ROM-cache prefixed')
 check(fs.createDirectory('mods/nativeprobe/baseroms'),'private input directory')
 check(fs.write('mods/nativeprobe/baseroms/private.bin','owned private test input'),'private fixture')
 local old=assert(fs.read('mods/nativeprobe/manifest.json'))
 for _,phase in ipairs({'reading','copying','verifying','ready to install'})do
  local job=assert(Mods.beginInstallZip(config.v2,{replace=true}));untilPhase(job,phase)
  check(Mods.cancelInstall(job),'cancel '..phase)
  local installed,why=drain(job)
  eq(installed,nil,'cancel never commits');check(why:find('cancelled',1,true),'terminal cancellation reason')
  eq(fs.read('mods/nativeprobe/manifest.json'),old,'cancel preserves previous manifest')
  eq(fs.read('mods/nativeprobe/baseroms/private.bin'),'owned private test input','cancel preserves private input')
 end
 for _,name in ipairs({'corrupt','wrong_game','wrong_api'})do
  local installed=drain(assert(Mods.beginInstallFromRelease('nativeprobe',{version='2.0.0',zip={url='https://fixture.invalid/mod.zip'}},config[name],'crystal')))
  eq(installed,nil,'refuses '..name);eq(fs.read('mods/nativeprobe/manifest.json'),old,'refusal preserves previous manifest')
 end
 local installed=drain(assert(Mods.beginInstallFromRelease('nativeprobe',{version='9.0.0',zip={url='https://fixture.invalid/mod.zip'}},config.v2,'crystal','9.0.0')))
 eq(installed,nil,'pinned manifest version checked before publication')
 eq(fs.read('mods/nativeprobe/manifest.json'),old,'pinned mismatch preserves old version')
 local job=assert(Mods.beginInstallZip(config.v2,{replace=true}));untilPhase(job,'copying')
 Mods.releaseStaleInstalls()
 check(drain(assert(Mods.beginRecoverInstalls())),'interrupted staging recovers')
 eq(fs.read('mods/nativeprobe/manifest.json'),old,'interrupted staging preserves active package')
 local rename=Cache.rawRename;local interrupted=false
 Cache.rawRename=function(from,to)
  local success,why=rename(from,to)
  if success and to=='mods/nativeprobe'then interrupted=true;coroutine.yield()end
  return success,why
 end
 job=assert(Mods.beginInstallZip(config.v2,{replace=true}))
 for _=1,5000 do local status=step(job);if interrupted then break end;assert(status~='done')end
 check(interrupted,'real directory exchange reached interruption boundary')
 Mods.releaseStaleInstalls();Cache.rawRename=rename
 check(drain(assert(Mods.beginRecoverInstalls())),'real directory rollback recovers')
 eq(fs.read('mods/nativeprobe/manifest.json'),old,'uncommitted exchange restores complete old version')
 eq(fs.read('mods/nativeprobe/baseroms/private.bin'),'owned private test input','recovery retains imports')
 local snapshot=drain(assert(Mods.beginBackupProfile({'nativeprobe'})))
 check(type(snapshot)=='table','real profile copy completes')
 check(drain(assert(Mods.beginInstallZip(config.v2,{replace=true}))),'real native update')
 check(drain(assert(Mods.beginRestoreProfile(snapshot))),'real profile rollback')
 eq(fs.read('mods/nativeprobe/manifest.json'),old,'profile restores old package')
 job=assert(Mods.beginInstallZip(config.v2,{replace=true}));local committed=false
 for _=1,5000 do
  local status,done=step(job)
  if job.committed and status~='done'then committed=true;eq(Mods.cancelInstall(job),false,'publication cannot be cancelled late')end
  if status=='done'then eq(done,true,'update completes');break end
 end
 check(committed,'post-commit cleanup yielded')
 eq(Json.decode(fs.read('mods/nativeprobe/manifest.json')).version,'2.0.0','new version visible')
 eq(fs.read('mods/nativeprobe/baseroms/private.bin'),'owned private test input','update retains private input')
 eq(#fs.getDirectoryItems('mod-install-journal'),0,'no durable receipt leak')
 eq(#fs.getDirectoryItems('mod-install-staging'),0,'no staged archive/file leak')
 eq(#fs.getDirectoryItems('mod-profile-backups'),0,'no profile copy leak')
 eq(Mods.installBusy(),false,'no live installer')
 local probe=Cache.scopedMount(config.folder,'installer-capability-probe')
 if not probe then
  -- Some distribution LOVE 11 builds hide every PHYSFS symbol. Direct ZIP
  -- selection is still supported; unavailable native mounts must fail closed.
  local success,why=drain(assert(Mods.beginInstallFolder(config.folder)))
  eq(success,nil,'unavailable external-directory bridge refuses safely')
  check(why:find('Select its ZIP files directly',1,true),'capability refusal offers the supported ZIP path')
  eq(Mods.installBusy(),false,'refused external directory releases job')
  print('External directories: unavailable; verified safe refusal and direct ZIP installs')
 else
 probe()
 print('External directories: supported')
 job=assert(Mods.beginInstallFolder(config.folder));untilPhase(job,'scanning')
 check(Mods.cancelInstall(job),'folder scan cancellation')
 eq(drain(job),nil,'folder scan cancels before installation')
 check(not fs.getInfo(job.token..'-scan'),'cancelled folder mount is released')
 local summary,why=drain(assert(Mods.beginInstallFolder(config.folder)))
 check(type(summary)=='table','real import folder scanned: '..tostring(why))
 eq(#summary.installed,2,'folder and one nested folder packages install')
 eq(#summary.failed,0,'folder packages read from actual external files')
 eq(#fs.getDirectoryItems('mod-install-staging'),0,'folder imports clean staging')
 check(fs.createDirectory('selected-data'),'create alternate owned root')
 local custom=fs.getSaveDirectory()..'/selected-data'
 check(Cache.withMounted(custom,'',function()
  Cache.root=function()return custom end
  local success,why=drain(assert(Mods.beginInstallZip(config.custom)))
  check(success,'selected root install: '..tostring(why))
  eq(fs.getRealDirectory('mods/customprobe/manifest.json'),custom,'archive and package use selected mounted root')
  eq(#fs.getDirectoryItems('mod-install-journal'),0,'selected root receipt cleanup')
  return true
 end),'alternate root stays mounted until all yielded IO is finished')
 end
 print('Native installer: '..checks..' checks PASS; real ZIP, filesystem, rollback, cancellation and profile IO')
 love.event.quit(0)
end
function love.load()co=coroutine.create(run)end
function love.update()
 local ok,why=coroutine.resume(co);if not ok then error(why)end
end
