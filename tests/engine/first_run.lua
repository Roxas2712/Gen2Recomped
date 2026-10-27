package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local options={}
local count=0;local function check(v,m)assert(v,m);count=count+1 end
local fail,writes,translated= false,0,0
package.loaded['src.core.SaveData']={loadOptions=function()return options end,saveOptions=function(o)writes=writes+1;if fail then return nil end;options=o;return o end}
local language='en'
package.loaded['src.translation.Service']={setLauncher=function(o)language=o.launcherLanguage end,enqueueLauncher=function()translated=translated+1 end,launcherLookup=function(v)return v end}
local W=require('src.import.FirstRun')
local RI={_ui={inside=function(r,x,y)return r and x>=r.x and y>=r.y and x<r.x+r.width and y<r.y+r.height end},
 new=function()return {launcher=true}end,update=function(self)self.updated=true end,draw=function()end,
 mousepressed=function(self)self.leaked=true end,keypressed=function(self)self.leaked=true end,gamepadpressed=function()end,wheelmoved=function()end,
 _launcherSettingsRows=function()return {}end,_settingsAction=function()end,_workspaceOpenCategory=function()end,
 _settings=function()return options end,applyTheme=function()end,_openAccount=function(self)self._accountOverlay={}end,chooseRomBatch=function(self)self.imported=true end}
RI.__index=RI;local new=RI.new;RI.new=function()return setmetatable(new(),RI)end
W.install(RI)
local ui=RI.new();check(ui._setupPending,'existing installs without a completed guide are offered it once')
ui._launcherSequence={kind='intro'};ui:update(0);check(not ui._setupOverlay and ui.updated,'the intro can finish before setup takes input')
ui._launcherSequence=nil;ui.updated=nil;ui:update(0);check(ui._setupOverlay and not ui.updated,'setup pauses hidden launcher actions')
W.action(ui,'language:de');W.action(ui,'theme:carbon')
check(language=='de' and not options.launcherLanguage and writes==0,'language and look preview without writing or downloading')
fail=true;check(not W.finish(ui) and ui._setupOverlay and not options.launcherSetupVersion,'failed persistence cannot dismiss the guide')
fail=false;check(W.finish(ui) and not ui._setupOverlay,'preferences save before setup closes')
check(options.launcherLanguage=='de' and options.launcherTheme=='carbon' and options.launcherSaveStorageChoice=='local' and options.cloudAutoSync==false,'guest play has a remembered local-save choice')
check(not ui._accountOverlay and not ui.imported,'finishing never signs in or starts a game import')
check(not RI.new()._setupPending,'successful completion survives a new launcher instance')
options.cloudAutoSync=true;options.launcherSaveStorageChoice='cloud';options.gameCacheUpload=false
ui:_workspaceOpenCategory('setup');W.action(ui,'skip')
check(options.cloudAutoSync and options.launcherSaveStorageChoice=='cloud' and not options.gameCacheUpload,'replaying the tour preserves existing cloud consent')
W.open(ui);W.action(ui,'register');check(ui._accountOverlay.mode=='register' and not ui._setupOverlay,'optional registration opens the native account flow after persisting setup')
W.open(ui);ui._setupOverlay.rects={{id='next',x=0,y=0,width=100,height=40,pinned=true}};ui._setupOverlay.viewport={x=0,y=0,width=100,height=200}
ui:touchpressed(1,20,20);ui:touchreleased(1,20,20);check(ui._setupOverlay.page==2,'a touchscreen tap advances exactly once')
ui:touchpressed(1,20,20);ui:touchmoved(1,20,100);ui:touchreleased(1,20,100);check(ui._setupOverlay.page==2,'scroll gestures cannot activate the underlying button')
ui:mousepressed(200,200,1);check(not ui.leaked,'clicks outside the guide never reach the library')
print('First run: '..count..' checks passed')

local B=require('src.import.CartridgeBatch');local start=B.start;local downloads=0
B.start=function(_,confirmed)assert(confirmed);downloads=downloads+1 end
W.open(ui);W.action(ui,'originals')
check(ui._setupOverlay.originals and not options.launcherOriginalCartridges and downloads==0,'original-image preview does not consent or download before saving')
W.action(ui,'downloadOriginals')
check(options.launcherOriginalCartridges and options.launcherOriginalCartridgesConsent==B.CONSENT and downloads==1,'explicit download stores the future-image preference first')
check(W.finish(ui)and options.launcherOriginalCartridges,'the artwork choice survives completing the guide')
B.start=start
local theme=require('src.import.LauncherTheme');local draw=theme.drawLogo;local branded=0
ui.logo={getDimensions=function()return 500,160 end}
theme.drawLogo=function(image)check(image==ui.logo,'setup uses the actual brand image');branded=branded+1 end
W.logo(ui,0,0,240,180);check(branded==1,'setup logo uses the shared accent-aware drawing path')
theme.drawLogo=draw
print('Setup artwork: '..count..' checks passed')
