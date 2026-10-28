-- Module-page layout, hit routing and final install-context guards.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local signed,account=true,'qa-one'
package.loaded['src.cloud.RetroCloud']={signedIn=function()return signed end,accountId=function()return account end}
local Page=require('src.import.LauncherGameMods')
local g=love.graphics;local noop=function()end
g.polygon=g.polygon or noop;g.intersectScissor=noop
local clip={0,0,1400,5000};g.getScissor=function()return unpack(clip)end
local prints={};g.print=function(value)prints[#prints+1]=value end;g.printf=g.print
local RI={_ui={col=noop,roundedCard=noop,ellipsize=function(_,v)return v end,inside=function(r,x,y)
 return r and x>=r.x and x<=r.x+r.width and y>=r.y and y<=r.y+r.height and(not r.clipY or y>=r.clipY[1]and y<=r.clipY[2])end},palette=function()return setmetatable({},{__index=function()return {1,1,1}end})end}
function RI:_drawGamePanel()return 60 end
function RI:_sbDrawContent()return 40 end
function RI:_sbMousepressed()self.fellThrough=true end
function RI:_findConfirmInstall(e)self.confirmed=e end
function RI:_findInstall(e)self.downloads=(self.downloads or 0)+1;self.download=e;self._communityDownload={id=e.id,phase='download'}end
function RI:update()end
Page.install(RI)
local font=g.newFont(14)
function font:getWrap(value,width)
 local lines={};local line=''
 for word in tostring(value):gmatch('%S+')do
  if line~=''and self:getWidth(line..' '..word)>width then lines[#lines+1]=line;line=word
  else line=line==''and word or line..' '..word end
 end
 lines[#lines+1]=line;return width,lines
end
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local function fixture()
 local entries={}
 for i=1,7 do entries[i]={id='mod'..i,title='Mod '..i,summary='A game-specific improvement',api=3,game_version='>=0.7.0 <1.0.0',games={'red'},downloadURL='https://example.test/mod.zip'}end
 local ui=setmetatable({_s=1,section='games',gamesView='game',tab='red',hintFont=font,stateFont=font,mods={{id='local',name='Local',version='1',games={'red'},enabled=false}},findIndex={mods=entries}}, {__index=RI})
 function ui:_ensureMods()end
 function ui:_ensureFind()self.findChecks=(self.findChecks or 0)+1 end
 function ui:_refreshFind()self.refreshed=true end
 function ui:_chipButton(x,y,label,o)return{x=x,y=y,width=o.w,height=o.h,label=label}end
 function ui:_findThumb()self.previews=(self.previews or 0)+1 end
 function ui:_findShowDetails(e)self.details=e end
 function ui:_openAccount()self.accountOpened=true end
 function ui:_selectTab(t)self.tab=t end
 function ui:_toggleMod(id)self.toggled=id end
 function ui:_toggleModGeneration(id,gen)self.toggledGen={id,gen}end
 function ui:_communityCancelDownload()self.cancelled=true end
 return ui
end
local function rect(ui,kind)
 for _,r in ipairs(ui._gameModsActions or {})do if r.kind==kind then return r end end
end
local function click(ui,r)assert(r,'expected control');return ui:_sbMousepressed(r.x+r.width/2,r.y+r.height/2)end
for _,width in ipairs{280,420,780,1400}do
 local ui=fixture();clip={0,0,width,5000}
 local height=ui:_drawGamePanel('red',0,0,width,5000,true)
 check(height>60 and ui.previews==3,'recommendations render a bounded first page at '..width)
 for i,a in ipairs(ui._gameModsActions)do
  check(a.x>=0 and a.x+a.width<=width+.01,'control stays inside narrow page')
  for j,b in ipairs(ui._gameModsActions)do if j>i then
   check(not(a.x<b.x+b.width and b.x<a.x+a.width and a.y<b.y+b.height and b.y<a.y+a.height),'controls do not overlap')
  end end
 end
 click(ui,rect(ui,'more'));ui:_drawGamePanel('red',0,0,width,5000,true)
 check(ui.previews==9,'show more reveals the next three recommendations without changing tabs')
end
local ui=fixture();clip={0,0,1000,5000};ui:_drawGamePanel('red',0,0,1000,5000,true)
click(ui,rect(ui,'toggle'));check(ui.toggled=='local','local activation reuses the existing mod toggle')
ui.mods[1].enabled=true;ui.mods[1].gens={false};ui:_drawGamePanel('red',0,0,1000,5000,true)
click(ui,rect(ui,'toggle'));check(ui.toggledGen[2]==1,'generation activation reuses the existing scope-aware toggle')
click(ui,rect(ui,'install'));check(ui.confirmed and not ui.downloads,'click requests the normal install confirmation, never an automatic download')
ui:_findInstall(ui.confirmed);check(ui.downloads==1,'a confirmed matching game/account reaches the existing installer')
check(ui._communityDownload.gameVersion=='red'and ui._communityDownload.gameAccount=='qa-one','the download retains the approved game/account for ZIP validation and commit')
local target=ui.confirmed;target.games={'blue'};ui:_findInstall(target)
check(ui.downloads==1 and not ui.findNotice.ok,'a latest-manifest scope change is refused again at the final install boundary')
target.games={'red'};target.game_version='>=99.0.0';ui:_findInstall(target)
check(ui.downloads==1,'a newly resolved incompatible engine is refused')
target.game_version='>=0.7.0 <1.0.0';ui.tab='blue';ui:_findInstall(target)
check(ui.downloads==1,'navigation during confirmation cannot install for an old game')
ui.tab='red';account='qa-two';ui:_findInstall(target)
check(ui.downloads==1,'account changes during confirmation are refused')
account='qa-one';signed=false;ui:_findInstall(target)
check(ui.downloads==1,'sign-out cannot finish a new online install')
ui.accountOpened=false;ui.previews=0;ui.findChecks=0;ui:_drawGamePanel('red',0,0,1000,5000,true)
check(ui.previews==0 and ui.findChecks==0 and not rect(ui,'install'),'guests see local mods without fetching or revealing online recommendations')
check(not ui.accountOpened and rect(ui,'login'),'guest rendering never opens a profile automatically')
click(ui,rect(ui,'login'));check(ui.accountOpened,'the explicit login control opens the account')
signed=true;ui=fixture();clip={0,0,1000,90};ui:_drawGamePanel('red',0,0,1000,5000,true)
check(ui.previews==nil,'offscreen cards do not queue preview or manifest requests')
clip={0,0,1000,5000};ui:_drawGamePanel('red',0,0,1000,5000,true);local old=rect(ui,'install')
ui.section='mods';ui.fellThrough=false;click(ui,old)
check(ui.fellThrough and not ui.confirmed,'stale game-page controls cannot intercept another section')
ui.section='games';ui.tab='blue';ui:update();check(#ui._gameModsActions==0,'changing edition clears old hit targets before the next draw')
ui._pinOpen=true;ui.previews=0;ui:_sbDrawContent(0,0,1000,5000)
check(ui.previews==0 and #ui._gameModsActions==0,'native Pinball never receives incompatible RPG package buttons')
ui._pinOpen=false;ui._xyOpen=true;ui._xyEdition='x';ui:_sbDrawContent(0,0,1000,5000)
check(ui.previews==0,'native X/Y keeps its separate mod-format workflow')
print('Game mods page: '..checks..' layout, routing and install-context checks passed')
