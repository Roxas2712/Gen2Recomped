-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Mods=require('src.mods.LauncherMods')
local Json=require('src.link.Json')
local Fake=require('tests.modkit.install_fs')
local function pack(m,id,version)
 local tree={['manifest.json']=Json.encode({id=id,name=id,version=version,api=2,entry='main.lua'}),
  ['main.lua']='local mod=...;mod.exports.native=true -- '..version,['data/owned.bin']=string.rep(version,120000)}
 local bytes='PK'..id..version;m.archives[bytes]=tree;m.files[id..version..'.zip']=bytes
 return id..version..'.zip',tree
end
local function drain(job)
 for _=1,3000 do
  local status,a,b,c=Mods.stepInstall(job,0)
  if status=='done'then return a,b,c end
 end
 error('profile job did not terminate')
end
local function fixture()
 local m=Fake();local _,tree=pack(m,'one','1.0.0')
 for path,value in pairs(tree)do m.files['mods/one/'..path]=value end
 m.files['mods/one/baseroms/private.bin']='private original'
 m.options={mods={one=false,unrelated=true},modInstallSources={one={repo='owner/one',version='1.0.0'}}}
 return m,tree
end
local function updated(m)
 for _,id in ipairs({'one','two'})do
  local path=pack(m,id,'2.0.0')
  local ok,why=drain(assert(Mods.beginInstallFromRelease(id,{version='2.0.0',zip={url='https://fixture.invalid/'..id}},path)))
  T.eq(ok,true,'profile replacement installs '..id..': '..tostring(why))
 end
end
local function clean(m)
 T.eq(next(m.mounts),nil,'profile job releases mounts')
 T.eq(m.files['mod_profile_recovery.lua'],nil,'completed profile retires recovery marker')
 for path in pairs(m.files)do
  T.check(not path:match('^mod%-install%-')and not path:match('^mod%-profile%-backups/'),'owned recovery output cleaned: '..path)
 end
 m.restore()
end
do
 local m,original=fixture();local snapshot,why=drain(assert(Mods.beginBackupProfile({'one','two'})))
 T.check(type(snapshot)=='table','whole profile backup completes: '..tostring(why))
 T.eq(m.files['mods/one/main.lua'],original['main.lua'],'profile preparation never edits installed code')
 updated(m)
 local ok,err=drain(assert(Mods.beginRestoreProfile(snapshot)))
 T.eq(ok,true,'profile rollback completes: '..tostring(err))
 T.eq(m.files['mods/one/main.lua'],original['main.lua'],'rollback restores exact native entry bytes')
 T.eq(m.files['mods/two/manifest.json'],nil,'rollback withdraws newly added package')
 T.eq(m.files['mods/one/baseroms/private.bin'],'private original','rollback preserves private import')
 T.eq(m.options.mods.one,false,'rollback restores old enable state')
 T.eq(m.options.mods.unrelated,true,'rollback preserves unrelated profile entry')
 T.eq(m.options.modInstallSources.one.version,'1.0.0','rollback restores package provenance')
 clean(m)
end
for _,interrupt in ipairs({false,true})do
 local m,original=fixture();local job=assert(Mods.beginBackupProfile({'one','two'}))
 for _=1,1000 do
  assert(Mods.stepInstall(job,0)~='done')
  if job.profileDraft and job.progress.phase=='preserving profile'then break end
 end
 if interrupt then
  Mods.releaseStaleInstalls();T.eq(drain(assert(Mods.beginRecoverInstalls())),true,'incomplete backup is recovered without restoring partial files')
 else
  T.eq(Mods.cancelInstall(job),true,'profile backup is cancellable')
  T.eq(drain(job),nil,'cancelled backup never returns a usable snapshot')
 end
 T.eq(m.files['mods/one/main.lua'],original['main.lua'],'cancel/interruption preserves installed package')
 clean(m)
end
do
 local m,original=fixture();local snapshot=drain(assert(Mods.beginBackupProfile({'one','two'})));updated(m)
 local job=assert(Mods.beginRestoreProfile(snapshot))
 for _=1,1000 do
  assert(Mods.stepInstall(job,0)~='done')
  if job.progress.phase=='restoring profile'then break end
 end
 Mods.releaseStaleInstalls()
 T.eq(drain(assert(Mods.beginRecoverInstalls())),true,'interrupted multi-package rollback resumes')
 T.eq(m.files['mods/one/main.lua'],original['main.lua'],'resumed rollback restores original package')
 T.eq(m.files['mods/two/main.lua'],nil,'resumed rollback removes added package')
 clean(m)
end
do
 local m=fixture();local snapshot=drain(assert(Mods.beginBackupProfile({'one','two'})));updated(m)
 local job=assert(Mods.beginFinishProfile(snapshot))
 for _=1,1000 do
  assert(Mods.stepInstall(job,0)~='done')
  if job.committed then break end
 end
 Mods.releaseStaleInstalls()
 T.eq(drain(assert(Mods.beginRecoverInstalls())),true,'committed profile cleanup resumes after process retirement')
 T.check(m.files['mods/two/manifest.json']~=nil,'committed profile retains added package')
 T.check(m.files['mods/one/main.lua']:find('2.0.0',1,true)~=nil,'committed profile retains new version')
 clean(m)
end
T.finish('cooperative profile backup, rollback and process recovery')
