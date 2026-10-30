-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Fake=require('tests.modkit.install_fs')
local Mods=require('src.mods.LauncherMods');local Json=require('src.link.Json')
local function pack(m,id,version,entry)
 local bytes='PK'..id..version
 m.archives[bytes]={['manifest.json']=Json.encode({id=id,name=id,version=version,api=2,entry='main.lua',games={'crystal'}}),
  ['main.lua']=entry or'local m=...;m.exports.native=true', ['assets/test.bin']=string.rep('a',400000)}
 m.files[id..version..'.zip']=bytes;return id..version..'.zip'
end
local function drain(job)
 for _=1,3000 do local status,a,b,c=Mods.stepInstall(job,0);if status=='done'then return a,b,c end end
 error('job did not finish')
end
do
 local m=Fake();local path=pack(m,'native','1.0.0',[[local mod=...;mod.exports.native=true
 mod.events:on('game.tick',function()mod.exports.ticked=true end)]])
 local opts={replace=true,expectGame='crystal'};local job=assert(Mods.beginInstallZip(path,opts))
 opts.expectGame='red';opts.expectId='different'
 T.eq(drain(job),true,'install options are detached from caller mutation')
 local Version=require('src.core.GameVersion');local old=Version.get();Version.set('crystal')
 local result=T.sdk.loadMod('mods/native',{fs=m.fs,data=T.fixtures.fresh()})
 T.eq(#result.errors,0,'installed native Gen2 mod loads through actual Loader')
 T.eq(result.loader.exports.native.native,true,'unchanged native entry executes after installation')
 result.loader.events:emit('game.tick')
 T.eq(result.loader.exports.native.ticked,true,'native Gen2 event registration remains functional')
 result.release();Version.set(old)
 m.restore()
end
for _,kind in ipairs({'foreign','checkout'})do
 local m=Fake();local path=pack(m,'native','1.0.0');T.eq(drain(assert(Mods.beginInstallZip(path))),true,'fixture installs')
 local original=m.files['mods/native/manifest.json'];path=pack(m,'native','2.0.0')
 if kind=='foreign'then m.foreign=function(path)if path:match('^mods/')then return '/protected-location'end end
 else m.files['mods/native/.git/HEAD']='owned source checkout marker'end
 local ok=drain(assert(Mods.beginInstallZip(path,{replace=true})))
 T.eq(ok,nil,'refuses replacing '..kind..' location')
 T.eq(m.files['mods/native/manifest.json'],original,'refusal preserves existing package')
 m.restore()
end
do
 local m=Fake();local path=pack(m,'native','1.0.0');local other=pack(m,'second','1.0.0')
 local job=assert(Mods.beginInstallMany({path,other}))
 for _=1,3000 do
  assert(Mods.stepInstall(job,0)~='done')
  if #job.completed==1 and not job.committed and job.progress.phase=='next package'then break end
 end
 T.eq(Mods.cancelInstall(job),true,'batch can cancel before second package')
 T.eq(drain(job),nil,'cancelled batch terminates')
 T.check(m.files['mods/native/main.lua']~=nil,'earlier complete package remains installed')
 T.eq(m.files['mods/second/main.lua'],nil,'remaining package never published')
 m.restore()
end
do
 local m=Fake();local path=pack(m,'native','1.0.0')
 m.files['mod-install-journal/install-1-1-1.json']=Json.encode({schema=1,state='prepared',token='install-1-1-1',
  root='/owned',area='mod-install-staging/install-1-1-1',id='native',dest='mods/../protected'})
 local ok=drain(assert(Mods.beginRecoverInstalls()))
 T.eq(ok,nil,'invalid recovery cannot authorize traversal')
 T.check(m.files['mod-install-journal/install-1-1-1.json']~=nil,'unrecognized recovery is preserved for inspection')
 T.check(m.files[path]~=nil,'recovery never deletes source archive')
 m.restore()
end
do
 local m=Fake();local path=pack(m,'native','1.0.0');local Download=require('src.mods.ModDownload')
 local start=Download.start;local cancelled=0
 Download.start=function()return{poll=function()return{kind='progress',bytes=3,total=10}end,
  cancel=function()cancelled=cancelled+1 end}end
 local job=assert(Mods.beginInstallFromRelease('native',{zip={url='https://fixture.invalid/test'}}))
 assert(Mods.stepInstall(job,0)~='done')
 T.eq(job.progress.phase,'downloading','release job yields during download')
 T.eq(Mods.cancelInstall(job),true,'download cancelled through same installer API')
 T.eq(drain(job),nil,'cancelled download cannot start package install')
 T.eq(cancelled,1,'download worker ownership retired once')
 T.eq(m.files['mods/native/main.lua'],nil,'no late download can install')
 Download.start=start;m.restore()
end
do
 local m=Fake();local Platform=require('src.core.Platform');local nx=Platform.isNX
 Platform.isNX=function()return true end
 local reads,closes=0,0
 local dropped={open=function()return true end,getSize=function()return 64*1024*1024+1 end,
  read=function()reads=reads+1;error('oversized input must not be read')end,
  close=function()closes=closes+1;return true end}
 local ok,why=drain(assert(Mods.beginInstallZip(dropped)))
 T.eq(ok,nil,'oversized console ZIP refused before allocation')
 T.check(why:find('64 MiB',1,true),'console limit is explained')
 T.eq(reads,0,'console preflight does not read oversized input')
 T.eq(closes,1,'refused console source handle closes')
 Platform.isNX=nx;m.restore()
end
T.finish('native loader compatibility, detached options, guarded recovery, batch, download and console cancellation')
