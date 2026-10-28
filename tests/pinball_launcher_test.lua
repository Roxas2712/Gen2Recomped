-- ROM-free launch/cancellation routing through the actual Pinball UI module.
-- Contributions by Roxas2712.
package.path='./?.lua;'..package.path
love=require('tests.love_stub');love.filesystem.getSource=function()return '/pinball-qa-no-assets'end
local noop=function()end;local checks,connections,started,cancelled=0,0,0,0
local function check(ok,why)assert(ok,why);checks=checks+1 end
package.loaded['src.cloud.Task']={new=function(fn)return{poll=function()local a,b=fn();return{kind='done',first=a,second=b}end,cancel=function()cancelled=cancelled+1 end}end}
local lastNet
package.loaded['src.link.Net']={new=function()
 connections=connections+1;local net={address='QA transport',host=function()return true end,hostOnline=function()return true end,
 join=function()return true end,joinOnline=function()return true end,close=function(self)self.closed=true end};lastNet=net;return net
end}
local reject=false
package.loaded['src.pinball.Player']={new=function(_,options)
 if reject then error('QA native start failure')end
 started=started+1;return{net=options.net,update=noop,draw=noop}
end}
package.loaded['src.import.LauncherLibrary']={paint={text=noop}}
package.loaded['src.import.LauncherHardware']={appearance=noop,cartridge=noop}
package.loaded['src.import.LauncherSequence']={new=function()return{}end}
local backdropStops=0
package.loaded['src.import.LauncherBackdrop']={setPaused=noop,stop=function()backdropStops=backdropStops+1 end}
local Play={setExternalContext=noop,clearExternalContext=noop};package.loaded['src.cloud.Play']=Play
local RI={_ui={inside=function()return false end},new=function()return{}end,palette=function()return{link={},warning={}}end}
for _,key in ipairs{'textinput','keypressed','keyreleased','mousepressed','gamepadpressed','draw','update','_sbGames','_sbOpenGame','_sbDrawContent','_sbOwns','_sbMousepressed','_sbBack','_sbGo','_sbBackdropWant','play'}do RI[key]=noop end
local animations=false;RI._settings=function()return{launcherAnimations=animations}end
RI._chipButton=function(_,_,_,label)return{label=label}end
RI._playButton=function(self,x,y,w,h)self.playButtonRect={label='SPIELEN',x=x,y=y,width=w,height=h}end
local M=require('src.import.LauncherPinball')
-- Launcher construction also runs during real ROM-free session teardown.
-- A missing source provider means no prepared Pinball installation.
local getenv,fs,getSource=os.getenv,love.filesystem,love.filesystem.getSource
os.getenv=function(key)if key~='ASCENDANT_PINBALL_ROOT'then return getenv(key)end end
fs.getSource=nil;check(not M.available(),'headless source provider is optional')
love.filesystem=nil;check(M.session()==nil,'headless filesystem is optional')
love.filesystem=fs;fs.getSource=getSource;os.getenv=getenv
local ext=require('src.import.LauncherExternalGames')
check(ext.versions('gba','pokemon')[1]=='pinballrs' and ext.info('pinballrs').experimental,'unprepared Pinball remains visible as an importable beta cartridge')
local session={locale='en'};M.session=function()return session end
M.install(RI)
local ui=setmetatable({_s=1,_pinOpen=true,section='games',_pinLocale='en',ready={}}, {__index=RI})
ui:_sbOpenGame('pinballrs');ui:_sbDrawContent(0,0,1000,700)
check(ui._pinButtons[2].label=='SPIELEN'and ui._pinButtons[2].y<300,'standard primary Play belongs to the module hero before secondary settings')
check(ui._pinIndex==2,'Enter focuses the primary Play action on a ready cartridge')
ui.pageScroll=400;ui._pinFocusNeeded=true;ui:_sbDrawContent(0,-400,1000,700)
check(ui.pageScroll<100,'keyboard focus scrolls the primary Play control back into view')
local function click(label)
 ui:_sbDrawContent(0,0,1000,700)
 for _,button in ipairs(ui._pinButtons)do if button.label:find(label,1,true)then button.action();return end end
 error('Missing button: '..label)
end
local advancedHidden=true
for _,button in ipairs(ui._pinButtons)do if button.label:find('IP / Port',1,true)then advancedHidden=false end end
check(advancedHidden,'manual IP entry is hidden in the normal friend flow')
click('ERWEITERTE VERBINDUNG · LAN / EIGENER RELAY')
click('ONLINE / LAN · DIREKT HOSTEN')
check(connections==0 and ui._pinConnectJob,'button queues connection instead of doing account I/O in the click handler')
ui:update(.016);check(connections==1 and started==1 and ui._pinPlayer.net==lastNet,'completed transport launches the actual player path')
check(backdropStops==1,'native launch must stop the launcher soundtrack')
ui._pinPlayer=nil;click('ONLINE / LAN · VERBINDEN');ui:_sbBack()
check(cancelled==1 and not ui._pinConnectJob,'leaving library cancels pending connection')
ui:update(.016);check(connections==1 and started==1,'cancelled connection cannot launch later')
ui._pinOpen=true;ui.section='games';reject=true;click('ONLINE / LAN · DIREKT HOSTEN');ui:update(.016)
check(lastNet.closed and not ui._pinPlayer and ui._pinNotice:find('QA native start failure',1,true),'native startup failure closes its transport and reaches UI')
reject=false;animations=true;click('ONLINE / LAN · DIREKT HOSTEN');ui:update(.016)
check(ui._launcherSequence and ui._pinPendingNet==lastNet,'animated launch retains pending transport')
lastNet:close();ui._launcherSequence.onComplete()
check(started==1 and not ui._pinPlayer,'closed invitation during animation never starts a guest')
ui._launcherSequence=nil;ui._pinPendingNet=nil;ui._pinOpen=true;ui.section='games'
M.session=function()return nil end
ui:_sbDrawContent(0,0,1000,700)
local importButton,playButton=false,false
for _,r in ipairs(ui._pinButtons)do importButton=importButton or r.label:find('Import ROM',1,true);playButton=playButton or r.label:find('SPIELEN',1,true)end
check(importButton and not playButton,'unprepared cartridge exposes import instead of a nonfunctional Play button')
local callback;love.window.showFileDialog=function(_,fn)callback=fn end
local imported=0;ui._pinImport=function(_,path)imported=imported+1 end
ui:_pinChooseImport();callback({});check(imported==0 and not ui._pinPicker,'picker cancellation does not start preparation')
ui:_pinChooseImport();ui._pinOpen=false;callback({'/tmp/own-pinball.gba'});check(imported==0,'a late file selection cannot import after leaving Pinball')
ui._pinOpen=true;ui:_pinChooseImport();callback({'/tmp/own-pinball.gba'});check(imported==1,'an active Pinball picker starts import')
print(checks..' Pinball launcher lifecycle checks passed')
