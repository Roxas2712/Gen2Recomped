package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local clock,account=0,'17';love.timer.getTime=function()return clock end
package.loaded['src.cloud.RetroCloud']={accountId=function()return account end}
local R=require('src.import.RomImporter');local M=require('src.import.ImportReview');local V=require('src.core.GameVersion')
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local detached=0;package.loaded['src.storage.GameCache']={prefix=function()detached=detached+1;return nil end}
local ui=setmetatable({ready={red=true},returning={},tab='red',_acknowledgeInterruptedImport=function()end},{__index=R})
local verified={version='red',hash=V.info('red').sha1,size=1024*1024}
ui:startData('fixture','fixture.gb',nil,verified)
check(ui._modConfirm and ui._modConfirm.kind=='reimport','real verified import stops at review')
check(not ui.worker and not ui.importing and detached==0,'review precedes cache detach and import writes')
check(ui.ready.red,'opening review preserves Play readiness')
local original=ui._modConfirm;ui:startData('other','other.gb',nil,verified)
check(ui._modConfirm==original,'another drop cannot replace an open review')
M.cancel(ui);check(ui.ready.red and not ui._modConfirm,'cancel preserves the installed game')
local picked=0;ui.choose=function()picked=picked+1 end;ui:reimport('red')
check(picked==1 and ui.ready.red,'cancelling the file picker never disables Play')
check(ui:_pendingRomReady().red==false and ui.ready.red,'explicit mobile pick can replace this edition without disabling its installed copy')
local continued=0;M.request(ui,'red',function()continued=continued+1 end,true)
check(not M.accept(ui,ui._modConfirm) and continued==0,'opening double-click cannot confirm replacement')
clock=1;check(M.accept(ui,ui._modConfirm) and continued==1,'one explicit approval continues once')
M.request(ui,'red',function()continued=continued+1 end,true);clock=2;account='18'
check(not M.accept(ui,ui._modConfirm) and continued==1,'account change invalidates review')
M.request(ui,'red',function()continued=continued+1 end,true);clock=3;ui._storageTask={}
check(not M.accept(ui,ui._modConfirm) and continued==1,'a new transfer blocks replacement')
ui._storageTask=nil;ui._romQueue={};M.request(ui,'red',function()end,true);M.cancel(ui)
check(ui._romQueueResume,'cancelled batch replacement permits the queue to continue')
check(not M.request(ui,'blue',function()end,false),'first-time imports do not need replacement confirmation')
ui._existingImports={red=true};ui.ready.red=false;ui:startData('fixture','fixture.gb',nil,verified)
check(ui._modConfirm~=nil,'stale caches remain protected even when not playable')
print('Import review: '..checks..' checks passed')
