package.path='./?.lua;'..package.path
love=require('tests.love_stub')
love.graphics.polygon=love.graphics.polygon or function()end
local signed=true
package.loaded['src.cloud.RetroCloud']={signedIn=function()return signed end,accountId=function()return signed and '17' end}
package.loaded['src.cloud.NativeAccount']={devices=function()return {devices={}}end,policy=function()return {}end}
package.loaded['src.cloud.Task']={new=function(fn)return {poll=function()return {kind='done',first=fn()}end,cancel=function()end}end}
local RI=require('src.import.RomImporter')
local font=love.graphics.newFont(14)
local ui=setmetatable({launcher=true,sidebarMode=true,section='games',_s=1,_sb={},
 hintFont=font,stateFont=font,labelFont=font,_settings=function()return {}end},RI)
local U=RI._ui
local n=0;local function check(v,m)assert(v,m);n=n+1 end
-- A scrollable page leaves a global viewport that excludes the fixed header.
local old=U.setPageBand({160,700})
ui:_sbDrawTopBar(0,0,1200,1)
local r=ui._headerAccount;local x,y=r.x+r.width/2,r.y+r.height/2
check(U.inside(r,x,y),'the real clipped hit-test accepts the fixed account header outside the page viewport')
ui._mx,ui._my=x,y
check(ui:_ptIn(r),'hover and pointer navigation agree with the header click target')
ui:mousepressed(x,y,1)
check(ui._accountOverlay and ui._accountOverlay.mode=='account','a real launcher click opens the signed-in native profile through every installed input wrapper')
ui._pinOpen=true;ui._pinIndex=1;ui._pinButtons={{action=function()error('Pinball card captured account input')end}}
ui:keypressed('down')
check(ui._pinIndex==1,'Pinball card yields keyboard navigation to the open account workspace')
ui._pinOpen=false
require('src.import.AccountWorkspace').close(ui)
r=ui._headerAvatar;ui:mousepressed(r.x+5,r.y+5,1)
check(ui._accountOverlay and ui._accountOverlay.mode=='account','the large avatar is another pinned profile entry')
require('src.import.AccountWorkspace').close(ui)
signed=false;ui:_sbDrawTopBar(0,0,1200,1);r=ui._headerAccount
ui:mousepressed(r.x+5,r.y+5,1)
check(ui._accountOverlay and ui._accountOverlay.mode=='login','the fixed header also opens login for a guest')
require('src.import.AccountWorkspace').close(ui)
r=ui._headerRegister;ui:mousepressed(r.x+5,r.y+5,1)
check(ui._accountOverlay and ui._accountOverlay.mode=='register','registration is reachable through the same clipped header')
require('src.import.AccountWorkspace').close(ui)
local ordinary={x=0,y=10,width=20,height=20}
check(not U.inside(ordinary,5,15),'scrolled content outside the viewport stays inactive')
U.setPageBand(old)
print('Header account input: '..n..' checks passed')
