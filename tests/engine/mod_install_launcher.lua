-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fake=require('tests.modkit.install_fs');local Json=require('src.link.Json')
local Mods=require('src.mods.LauncherMods')
local step=Mods.stepInstall
-- Deterministic frame scheduling, while exercising the real IO job.
Mods.stepInstall=function(job)return step(job,0)end
local m=Fake()
local bytes='PKowned';m.files['owned.zip']=bytes;m.archives[bytes]={
 ['manifest.json']=Json.encode({id='owned',name='Owned',api=2,version='1.0.0',entry='main.lua'}),
 ['main.lua']='local mod=...;mod.exports.native=true',['large.bin']=string.rep('x',600000)}
local UI={};UI.__index=UI
function UI.new()return setmetatable({workState='choose',tab='crystal',pulse=0},UI)end
function UI:update(dt)self.pulse=self.pulse+dt end
function UI:draw()end
function UI:play()self.played=true end
function UI:keypressed()self.keys=(self.keys or 0)+1 end
function UI:mousepressed()self.clicks=(self.clicks or 0)+1 end
function UI:gamepadpressed()end
function UI:_refreshMods()self.refreshed=true end
function UI:_pickManyTally(ok)self.tallied=ok end
function UI:_pickManyAgain()self.again=true end
require('src.import.LauncherInstallJobs').install(UI)
local window=UI.new();window:_installMod('owned.zip')
T.check(window._localModInstall~=nil,'native install action creates actual package job')
T.eq(window.workState,'working','launcher blocks concurrent imports')
window:play();T.eq(window.played,nil,'Play cannot see a partially installed package')
window:keypressed('return');T.eq(window.keys,nil,'ordinary activation is blocked during installation')
window:mousepressed(10,10,1);T.eq(window.clicks,nil,'unrelated mouse input cannot alter the destination')
window:_pickManyTally(true);window:_pickManyAgain()
T.eq(window.tallied,nil,'mobile success is deferred until package commit')
T.eq(window.again,nil,'mobile picker does not reopen while its source is being read')
for _=1,2000 do if not window._localModInstall then break end;window:update(.01)end
T.eq(window.workState,'choose','previous native launcher state is restored')
T.eq(window.tallied,true,'mobile success is counted only after actual commit')
T.eq(window.again,true,'mobile picker resumes after source handles close')
T.eq(window.refreshed,true,'completed native package refreshes installed list')
T.check(window.pulse>0,'ordinary launcher updates keep pumping')
local nextWindow=UI.new();nextWindow:_installMod('owned.zip')
nextWindow:update(.01);nextWindow:draw()
T.check(nextWindow._modInstallCancelRect~=nil,'actual progress overlay exposes Cancel hit target')
nextWindow:keypressed('escape')
T.check(nextWindow._localModInstall.job.cancelled,'Escape requests actual installer cancellation')
for _=1,2000 do if not nextWindow._localModInstall then break end;nextWindow:update(.01)end
T.check(nextWindow.modNotice.text:find('cancelled',1,true),'cancel has a visible terminal notice')
T.eq(m.files['mods/owned-1/main.lua'],nil,'cancelled duplicate is never published')
local clicked=UI.new();clicked:_installMod('owned.zip');clicked:draw()
local r=clicked._modInstallCancelRect;clicked:mousepressed(r.x+1,r.y+1,1)
T.eq(clicked._localModInstall.job.cancelled,true,'progress Cancel button cancels actual job')
for _=1,2000 do if not clicked._localModInstall then break end;clicked:update(.01)end
local pad=UI.new();pad:_installMod('owned.zip');pad:gamepadpressed(nil,'back')
T.eq(pad._localModInstall.job.cancelled,true,'gamepad Back cancels actual job')
for _=1,2000 do if not pad._localModInstall then break end;pad:update(.01)end
m.restore()
Mods.stepInstall=step
T.finish('native launcher pumping, input guards, cancellation and deferred mobile ownership')
