-- Fresh profile and packaged-app import routing, without game-derived bytes.
package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local checks=0
local function check(v,m)assert(v,m);checks=checks+1 end
local realOpen=io.open
io.open=function(path,...)if path:match('^/fresh%-profile/')then return nil end;return realOpen(path,...)end
love.filesystem.getSource=function()return '/fresh-profile/game.love'end
love.filesystem.getSaveDirectory=function()return '/fresh-profile/save'end
local writes={}
love.filesystem.read=function(path)return 'reviewed helper: '..path end
love.filesystem.createDirectory=function()return true end
love.filesystem.write=function(path,data)writes[path]=data;return true end
local Backend=require('src.import.PokemonXYBackend')
check(Backend.root()=='/fresh-profile/save/pokemon-xy-backend','packaged helper root is writable without an existing manifest')
check(writes['pokemon-xy-backend/tools/pokemon_x_backend.py']~=nil,'packaged backend script is extracted')
check(writes['pokemon-xy-backend/tools/qa_preserved.py']~=nil,'helper dependencies travel with the payload')
local jobs={}
local pending
love.thread={getChannel=function()return {clear=function()end,pop=function()local row=pending;pending=nil;return row end}end,newThread=function(path)
 local job={path=path,start=function(self,data)self.data=require('src.link.Json').decode(data)end,getError=function()end}
 jobs[#jobs+1]=job;return job
end}
package.loaded['src.import.LauncherBackdrop']={setPaused=function()end}
local fallback=0
local RI={_ui={}};RI.__index=RI
function RI.new()return setmetatable({ready={},section='games',pageScroll=0},RI)end
function RI:update()end;function RI:draw()end;function RI:_settings()return{}end
function RI:_sbOpenGame()fallback=fallback+1 end
function RI:filedropped()fallback=fallback+1 end
for _,method in ipairs{'textinput','keypressed','mousepressed','gamepadpressed','joystickpressed'}do RI[method]=function()end end
local XY=require('src.import.LauncherPokemonXY');XY.install(RI)
check(XY.available() and #XY.versions('3ds','pokemon')==2,'3DS is visible on a fresh profile')
check(#XY.versions('gb')==0 and #XY.versions('3ds','hacks')==0,'other system/series filters stay separate')
check(XY.info('x').experimental and XY.info('y').importable,'X/Y are importable beta entries')
local ui=RI.new();ui:_sbOpenGame('y')
check(ui._xyOpen and ui._xyEdition=='y' and fallback==0,'fresh Y card opens the external importer without RPG/account routing')
ui._xyJob=nil;ui:_xyImport('/my own/games/y.cxi')
check(jobs[#jobs].data.action=='import' and jobs[#jobs].data.edition=='y','import is distinct from native build/play')
check(jobs[#jobs].data.args[1]=='/my own/games/y.cxi','paths with spaces remain structured arguments')
local count=#jobs;ui:_xyImport('/other.cxi');check(#jobs==count,'a second import cannot compete with the active worker')
ui=RI.new();ui:filedropped({getFilename=function()return '/own/X.3DS'end})
check(jobs[#jobs].data.args[2]=='--detect-edition','a global 3DS drop detects its edition')
ui=RI.new();ui:filedropped({getFilename=function()return '/own/red.gb'end})
check(fallback==1,'existing RPG file-drop routing remains intact')
local runtime=Backend.runtime;Backend.runtime=function()return '/My Demo.app/Contents/Resources/3ds-runtime'end
ui=RI.new();ui._xyEdition='y';ui:_xyImport('/my own/y.cxi')
local job=jobs[#jobs]
check(job.data.mode=='playing' and job.data.args[2]=='--play-after-import','bundled imports automatically prepare and enter the normal play gate')
check(job.data.python=='/My Demo.app/Contents/Resources/3ds-runtime/python/bin/python3.12','a packaged import uses its bundled Python with spaces intact')
pending=require('src.link.Json').encode{progress='Preparing your game. The first import can take several minutes.'};ui:update(0)
check(ui._xyJob==job and ui._xyNotice:find('Preparing',1,true),'progress updates do not prematurely release a running worker')
pending=require('src.link.Json').encode{progress='Preparing your game. The first import can take several minutes.',edition='y',data={y={imported=true,ready=false}}};ui:update(0)
check(ui._xyJob==job and ui._xyData.y.imported and not ui._xyData.y.ready,'verified imports become visible while the native compilation is still running')
pending=require('src.link.Json').encode{progress='Compiling game · %d / %d',completed=32,total=487};ui:update(0)
check(ui._xyJob==job and ui._xyNotice:find('32 / 487',1,true),'native compilation progress remains visible while the worker runs')
pending=require('src.link.Json').encode{ok=false,error='Compiler stopped',data={y={imported=true,ready=false}}};ui:update(0)
check(not ui._xyJob and ui._xyData.y.imported and not ui._xyData.y.ready and ui._xyNoticeIsError,'a failed native build preserves the valid import and reports the error without claiming readiness')
Backend.runtime=runtime
local callback,options,dialogs
dialogs=0
love.window.showFileDialog=function(kind,done,settings)assert(kind=='openfile');callback=done;options=settings;dialogs=dialogs+1 end
ui=RI.new();ui._xyEdition='x';ui._xyOpen=true
count=#jobs;ui:_xyChooseImport()
check(ui._xyPicker and #jobs==count and options.attachtowindow and not options.multiselect,'native dialog returns without blocking or starting an import')
ui:_xyChooseImport();ui:_xyImport('/other.cxi')
check(dialogs==1 and #jobs==count,'an active picker cannot compete with another picker or dropped import')
callback({})
check(not ui._xyPicker and #jobs==count,'cancelling the native picker leaves imports unchanged')
ui:_xyChooseImport();callback({'/own games/X.cxi'})
check(not ui._xyPicker and jobs[#jobs].data.args[1]=='/own games/X.cxi','native selection reaches the real import worker with its absolute path intact')
ui._xyJob=nil;ui:_xyChooseImport();ui._xyEdition='y';count=#jobs;callback({'/stale/X.cxi'})
check(not ui._xyPicker and #jobs==count,'a stale picker cannot import into a different edition')
ui:_xyChooseImport();callback({},nil,'Picker failed')
check(not ui._xyPicker and ui._xyNoticeIsError and ui._xyNotice=='Picker failed','native picker failures are visible')
love.window.showFileDialog=function()error('Dialog unavailable')end
ui:_xyChooseImport()
check(not ui._xyPicker and ui._xyNoticeIsError,'a failed dialog launch releases its pending state')
print('3DS fresh import: '..checks..' checks passed')
