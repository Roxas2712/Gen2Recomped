-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Json=require('src.link.Json')
local Mods=require('src.mods.LauncherMods')
local Cache=require('src.import.CacheFs')
local Fake=require('tests.modkit.install_fs')
local prefix=Cache.prefix;Cache.prefix='crystal/'
local function package(m,version,extra)
 local manifest=Json.encode({id='probe',name='Owned native mod',api=2,version=version,entry='main.lua'})
 local tree={['manifest.json']=manifest,['main.lua']='local mod=...;mod.exports.native=true',
  ['assets/large.bin']=string.rep(version,300000)}
 for key,value in pairs(extra or{})do tree[key]=value end
 local bytes='PKowned-'..version;m.archives[bytes]=tree;m.files['input-'..version..'.zip']=bytes
 return 'input-'..version..'.zip',tree
end
local function drain(job,visit)
 for frame=1,1000 do
  local phase,a,b,c=Mods.stepInstall(job,0)
  if visit then visit(job,phase,frame)end
  T.eq(Cache.prefix,'crystal/','a job never borrows the cartridge cache prefix')
  if phase=='done'then return a,b,c end
 end
 error('job never completed')
end
local function clean(m)
 T.eq(next(m.mounts),nil,'archive mount retired')
 for path in pairs(m.files)do T.check(not path:match('^mod%-install%-'),'no installer file leaks: '..path)end
 m.restore()
end
do
 local m=Fake();local source,tree=package(m,'1.0.0')
 local job=assert(Mods.beginInstallZip(source))
 T.eq(m.reads,0,'begin returns before archive IO')
 local other,why=Mods.beginInstallZip(source);T.eq(other,nil,'parallel publication is refused')
 local frames=0;local ok,id,version=drain(job,function(j,status)
  frames=frames+1
  if status=='running'and not j.committed then T.eq(m.files['mods/probe/main.lua'],nil,'unpublished package stays invisible')end
 end)
 T.eq(ok,true,'new native package installs');T.eq(id,'probe','actual manifest identity returned');T.eq(version,'1.0.0','actual version returned')
 T.check(frames>8,'copy and readback span real cooperative frames')
 T.eq(m.files['mods/probe/main.lua'],tree['main.lua'],'native entry bytes remain unchanged')
 clean(m)
end
for _,cancelPhase in ipairs({'reading','copying','verifying','ready to install'})do
 local m=Fake();local source=package(m,'2.0.0')
 local _,old=package(m,'1.0.0');for path,value in pairs(old)do m.files['mods/probe/'..path]=value end
 local before=m.files['mods/probe/main.lua'];m.files['mods/probe/baseroms/owned.bin']='owned private input'
 local job=assert(Mods.beginInstallZip(source,{replace=true}));local found=false
 for _=1,1000 do
  local status=Mods.stepInstall(job,0)
  if status=='running'and job.progress.phase==cancelPhase then found=true;break end
  assert(status~='done','phase not visited: '..cancelPhase)
 end
 T.check(found,'native phase is reachable: '..cancelPhase)
 T.eq(Mods.cancelInstall(job),true,'cancel admitted in '..cancelPhase)
 local ok,why=drain(job)
 T.eq(ok,nil,'cancel completes without publishing');T.check(why:find('cancelled',1,true),'cancel has a terminal reason')
 T.eq(m.files['mods/probe/main.lua'],before,'cancel leaves old native code unchanged')
 T.eq(m.files['mods/probe/baseroms/owned.bin'],'owned private input','cancel preserves private input')
 clean(m)
end
for _,failure in ipairs({'copy','publish','options','close'})do
 local m=Fake();local source=package(m,'2.0.0');local _,old=package(m,'1.0.0')
 for path,value in pairs(old)do m.files['mods/probe/'..path]=value end
 m.files['mods/probe/baseroms/owned.bin']='private original';m.options.mods.probe=false
 if failure=='copy'then m.failWrite=function(path)return path:find('/package/assets/',1,true)end
 elseif failure=='publish'then m.failRename=function(from,to)return to=='mods/probe'and from:find('/package',1,true)end
 elseif failure=='options'then m.failOptions=true
 else m.failClose=function(path)return path:find('/package/',1,true)end end
 local ok,why=drain(assert(Mods.beginInstallZip(source,{replace=true})))
 T.eq(ok,nil,'failure is reported: '..failure);T.check(type(why)=='string','failure has a diagnostic')
 T.eq(m.files['mods/probe/manifest.json'],old['manifest.json'],'previous version retained after '..failure)
 T.eq(m.files['mods/probe/baseroms/owned.bin'],'private original','private input retained after '..failure)
 T.eq(m.options.mods.probe,false,'activation retained after '..failure)
 clean(m)
end
do
 local m=Fake();local source=package(m,'2.0.0');local _,old=package(m,'1.0.0')
 for path,value in pairs(old)do m.files['mods/probe/'..path]=value end
 m.files['mods/probe/baseroms/owned.bin']=string.rep('private',100000)
 local job=assert(Mods.beginInstallZip(source,{replace=true}));local sawCommit=false
 local ok=drain(job,function(j,status)
  if j.committed and status=='running'then
   sawCommit=true;T.eq(Mods.cancelInstall(j),false,'late cancellation cannot undo publication')
   T.check(m.files['mods/probe/manifest.json']~=old['manifest.json'],'committing state exposes complete new package')
  end
 end)
 T.eq(ok,true,'replacement completes');T.check(sawCommit,'cleanup remains cooperative after publication')
 T.eq(m.files['mods/probe/baseroms/owned.bin'],string.rep('private',100000),'exact private input survives replacement')
 clean(m)
end
for _,boundary in ipairs({'before publication','after publication','after commit','staging'})do
 local m=Fake();local source=package(m,'2.0.0');local _,old=package(m,'1.0.0')
 for path,value in pairs(old)do m.files['mods/probe/'..path]=value end
 m.files['mods/probe/baseroms/owned.bin']='private'
 local stopped=false
 m.afterRename=function(from,to)
  if (boundary=='before publication'and to:find('/previous',1,true))or
    (boundary=='after publication'and to=='mods/probe')then stopped=true;coroutine.yield('process interruption')end
 end
 local job=assert(Mods.beginInstallZip(source,{replace=true}))
 for _=1,1000 do
  local status=Mods.stepInstall(job,0)
  if stopped or boundary=='staging'and job.progress.phase=='copying' or boundary=='after commit'and job.committed then break end
  assert(status~='done','interruption boundary missing')
 end
 Mods.releaseStaleInstalls();m.afterRename=nil
 local recover=assert(Mods.beginRecoverInstalls());local ok,why=drain(recover)
 T.eq(ok,true,'recovery completes at '..boundary..': '..tostring(why))
 if boundary=='after commit'then T.check(m.files['mods/probe/manifest.json']~=old['manifest.json'],'committed replacement survives process retirement')
 else T.eq(m.files['mods/probe/manifest.json'],old['manifest.json'],'uncommitted update restores original at '..boundary)end
 T.eq(m.files['mods/probe/baseroms/owned.bin'],'private','recovery preserves private input at '..boundary)
 clean(m)
end
Cache.prefix=prefix
T.finish('cooperative package staging, cancellation and native update rollback')
