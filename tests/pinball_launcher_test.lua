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
package.loaded['src.import.LauncherBackdrop']={setPaused=noop}
local Play={setExternalContext=noop,clearExternalContext=noop};package.loaded['src.cloud.Play']=Play
local RI={_ui={inside=function()return false end},new=function()return{}end,palette=function()return{link={},warning={}}end}
for _,key in ipairs{'textinput','keypressed','keyreleased','mousepressed','gamepadpressed','draw','update','_sbGames','_sbOpenGame','_sbDrawContent','_sbOwns','_sbMousepressed','_sbBack','_sbGo','_sbBackdropWant','play'}do RI[key]=noop end
local animations=false;RI._settings=function()return{launcherAnimations=animations}end
RI._chipButton=function(_,_,_,label)return{label=label}end
local M=require('src.import.LauncherPinball');local session={locale='en'};M.session=function()return session end
M.install(RI)
local ui=setmetatable({_s=1,_pinOpen=true,section='games',_pinLocale='en',ready={}}, {__index=RI})
local function click(label)
 ui:_sbDrawContent(0,0,1000,700)
 for _,button in ipairs(ui._pinButtons)do if button.label:find(label,1,true)then button.action();return end end
 error('Missing button: '..label)
end
click('ONLINE / LAN · DIREKT HOSTEN')
check(connections==0 and ui._pinConnectJob,'button queues connection instead of doing account I/O in the click handler')
ui:update(.016);check(connections==1 and started==1 and ui._pinPlayer.net==lastNet,'completed transport launches the actual player path')
ui._pinPlayer=nil;click('ONLINE / LAN · VERBINDEN');ui:_sbBack()
check(cancelled==1 and not ui._pinConnectJob,'leaving library cancels pending connection')
ui:update(.016);check(connections==1 and started==1,'cancelled connection cannot launch later')
ui._pinOpen=true;ui.section='games';reject=true;click('ONLINE / LAN · DIREKT HOSTEN');ui:update(.016)
check(lastNet.closed and not ui._pinPlayer and ui._pinNotice:find('QA native start failure',1,true),'native startup failure closes its transport and reaches UI')
reject=false;animations=true;click('ONLINE / LAN · DIREKT HOSTEN');ui:update(.016)
check(ui._launcherSequence and ui._pinPendingNet==lastNet,'animated launch retains pending transport')
lastNet:close();ui._launcherSequence.onComplete()
check(started==1 and not ui._pinPlayer,'closed invitation during animation never starts a guest')
print(checks..' Pinball launcher lifecycle checks passed')
