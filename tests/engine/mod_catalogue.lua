package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local signed=true
package.loaded['src.cloud.RetroCloud']={signedIn=function() return signed end}
local M=require('src.import.ModCatalogue')
local Search=require('src.mods.ModSearch')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
check(M.scope({games={'red','crystal','emerald','platinum','black'}})=='GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5','all declared generations remain visible')
check(M.scope({title='Gen 2 Dex',games={},compatibility={{engine='g1r'}}})=='GEN 1 · DECLARED FOR GEN1RECOMP','content generations do not masquerade as supported games')
check(M.scope({})=='GENERATION NOT DECLARED','missing targets never claim every game')
local localMod={id='real',github='OWNER/REPO',name='Installed',enabled=true,games={'crystal'}}
local a,b=M.sections({localMod},{{id='catalogue-old',github='owner/repo',title='Remote'},{id='other',title='Available'}})
check(#a==1 and a[1].mod==localMod and #b==1,'repository identity joins catalogue IDs to installed mods')
a,b=M.sections({localMod},{},{query='does not match'})
check(#a==0 and #b==0,'local imports obey the same search')
local entries={{id='long',title='Other',author='Roxas2712',description='battle engine',tags={'Schönes'}},
  {id='short',title='Battle',games={'crystal'}},{id='unknown',title='Gen 2 Dex',compatibility={{engine='g1r'}}}}
local results=Search.filter(entries,{query='battle'})
check(results[1].id=='short' and #results==2,'exact titles rank above descriptions')
check(Search.filter(entries,{query='roxas battle schones'})[1].id=='long','AND search spans developer, descriptions and normalized umlaut tags')
check(#Search.filter(entries,{query='"battle engine"'})==1,'quoted phrases remain intact')
local approximate;results,approximate=Search.filter(entries,{query='battl'})
check(results[1].id=='short','partial titles remain discoverable')
results,approximate=Search.filter(entries,{query='batlle'})
check(#results==1 and approximate==1,'one-edit misspellings are marked as approximate matches')
check(#Search.filter(entries,{generation=2})==1 and #Search.filter(entries,{generation=1})==1,'generation filters use declared base games instead of title content')
check(#Search.filter(entries,{query='roxas',generation=2})==0,'generation and free text filters combine')
entries[1].description='Changed description'
check(#Search.filter(entries,{query='engine'})==0 and #Search.filter(entries,{query='changed'})==1,'cached documents refresh when catalogue fields change')
local imageCalls,prints,buttons=0,{},{}
local font=love.graphics.newFont(12)
function font:getWrap(v,w)
  local lines={};local cols=math.max(1,math.floor(w/7))
  for i=1,#v,cols do lines[#lines+1]=v:sub(i,i+cols-1) end
  return w,lines
end
local g=love.graphics
g.polygon=function() end
g.getScissor=function() return 0,0,1280,900 end
g.intersectScissor=function() end
g.print=function(v) prints[#prints+1]=v end
g.printf=function(v) prints[#prints+1]=v end
g.getFont=function() return font end
local RI={_ui={col=function() end,roundedCard=function() end,ellipsize=function(_,v)return v end,
  inside=function(r,x,y)return r and x>=r.x and x<=r.x+r.width and y>=r.y and y<=r.y+r.height end},
  palette=function() return setmetatable({},{__index=function()return {1,1,1} end}) end}
function RI:_drawModsPanel() self.managed=true;return 123 end
function RI:_sbModToolbar() return 44 end
function RI:_selectTab(t) self.tab=t;self.pageScroll=0 end
function RI:_sbMousepressed() end
function RI:_ensureMods() end
function RI:_ensureFind() end
function RI:_findRows() return self.findIndex.mods end
function RI:_findThumb() imageCalls=imageCalls+1 end
function RI:_chipButton(x,y,label,o)
  local r={x=x,y=y,width=o.w,height=o.h,label=label};buttons[#buttons+1]=r;return r
end
function RI:_findShowDetails(e) self.detail=e end
function RI:_findConfirmInstall(e) self.install=e end
function RI:_syncModUpdateInfo(force) self.updateChecks=(self.updateChecks or 0)+1;self.forced=force;self.modUpdateInfo={} end
function RI:update() end
function RI:_openAccount() self.account=true end
M.install(RI)
local mods={};for i=1,30 do mods[i]={id='m'..i,title='Mod '..i,summary='Useful information about this project.',categories={'Grafik & 3D'},games={'red','crystal'}} end
local ui=setmetatable({_s=1,hintFont=font,stateFont=font,warningFont=font,section='mods',tab='find',mods={},findIndex={mods=mods,categories={}}},{__index=RI})
ui:update(0);ui:update(0)
check(ui.updateChecks==1 and ui.forced,'app startup forces one repository update sweep rather than every frame')
local height=ui:_drawFindPanel(10,0,1100,900,true)
check(height>900 and #ui._catalogActions>3,'the signed-in catalogue renders without installed mods')
local count=imageCalls
check(count<30,'off-screen cards do not start image or repository jobs')
ui:_drawFindPanel(10,-700,1100,900,true)
check(imageCalls>count,'scrolling renders newly visible cards')
check(not table.concat(prints,' '):find('^MOD$'),'missing pictures receive category artwork')
for _,r in ipairs(ui._catalogActions) do
  check(r.x>=10 and r.x+r.width<=1110.01,'card buttons stay in their columns')
  if r.action=='install' then ui:_sbMousepressed(r.x+2,r.y+2);check(ui.install==r.entry,'install uses the existing account-gated flow');break end
end
ui:_selectTab('mods');check(ui.tab=='find','opening Mods defaults to the catalogue')
ui:_drawFindPanel(10,0,320,812,true)
local firstCover
for _,r in ipairs(ui._catalogActions) do
  check(r.x>=10 and r.x+r.width<=330.01,'portrait controls stay within the content width')
  if r.action=='preview' and not firstCover then firstCover=r end
end
check(firstCover and firstCover.y<500,'portrait toolbar leaves the catalogue visible without expanding every filter')
ui._catalogManage=true;ui:_selectTab('mods');check(ui.tab=='mods' and ui:_drawModsPanel()==123 and ui.managed,'load order, import and enable controls remain available')
signed=false;ui._catalogManage=false;ui:_selectTab('mods')
check(ui.tab=='mods' and ui._catalogManage and ui:_drawModsPanel()==123,'guests opening Mods land directly on installed mods and manual import controls')
ui._catalogManage=false;ui.tab='find';local beforeImages=imageCalls
ui:_drawFindPanel(10,0,320,812,true)
check(imageCalls==beforeImages and #ui._catalogActions==2,'guest browser shows only login and manual-import choices without requesting previews')
local manage=ui._catalogActions[2];ui:_sbMousepressed(manage.x+1,manage.y+1)
check(ui._catalogManage and ui.tab=='mods','manual imports remain reachable without an account prompt')
print('Mod catalogue: '..checks..' checks passed')
