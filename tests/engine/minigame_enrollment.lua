-- Mandatory entry notice, with real hub and isolated persistent profiles.
-- Contributions by Roxas2712. No network or third-party assets.
love=require('tests.love_stub')
local S=require('src.core.SaveSerializer');local filesA,filesB={},{};local fail=false
local function fs(files)return{read=function(p)return files[p]end,write=function(p,b)if fail then return false,'full'end;files[p]=b;return true end,
 getInfo=function(p)return files[p]and{type='file',size=#files[p]}end,rename=function(p,q)files[q]=files[p];files[p]=nil;return true end,remove=function(p)files[p]=nil;return true end,createDirectory=function()return true end}end
local a,b=fs(filesA),fs(filesB);local active=a
package.loaded['src.core.SaveData']={persistenceFs=function()return active end}
local builds,art,starts=0,0,0
package.loaded['src.pokewalker.minigames.Context']={build=function()builds=builds+1;return{walker={name='QA'},wild={{dex=25,name='QA'}},version='red'}end}
local G=require('src.pokewalker.minigames.Gfx');G.art=function()art=art+1;return nil end
local E=require('src.pokewalker.minigames.Enrollment')
local H=require('src.ui.WalkerMinigames');local W=require('src.pokewalker.Walker')
H.games=function()return{{id='memory',title='QA',new=function()starts=starts+1;return{score=0,time=0,update=function()end,input=function()end}end}}end
local n=0;local function check(v,m)assert(v,m);n=n+1 end
local st=W.newState();local h=H.new(nil,st)
check(h.enrolling and not h.gateChecked,'first entry has no preselected confirmation')
check(builds==0 and art==0 and starts==0 and not st.minigames,'unaccepted entry loads no game context, art, game instance or reward budget')
h:play(1,true);check(h.enrolling and starts==0,'direct hub play cannot skip the notice')
h.gateFocus=2;h:action('a')
check(not E.accepted(H.GAME_MODULES)and not h.session,'continue without ticking remains locked')
h.gateFocus=1;h:key('return');check(h.gateChecked and not E.accepted(H.GAME_MODULES),'ticking alone does not store acceptance')
h:key('down');h:key('return')
check(E.accepted(H.GAME_MODULES)and not h.enrolling and h.settingContent and builds==0 and art==0,'explicit accept opens separate content setup before gameplay or art')
check(not st.minigames and starts==0,'acceptance alone does not initialize the reward budget')
h.contentFocus=1;h:action('a')
check(not h.settingContent and builds==1 and st.minigames,'explicit basic graphics choice initializes the catalogue')
h:play(1,true);check(starts==1 and h.session.phase=='play','accepted entry can start a minigame')
local stored=filesA[E.FILE];check(stored and not stored:find('token',1,true),'receipt contains no device credential')
local restarted=H.new(nil,W.newState());check(not restarted.enrolling,'same local profile and version do not prompt again')
local closed=0;h.onClose=function()closed=closed+1 end;H.active=h
check(E.revoke()and closed==1 and not h.session and not E.accepted(H.GAME_MODULES),'withdrawal retires an active run without settling it')
check(not st.minigames.daily or st.minigames.daily.plays==0,'withdrawal awards no round payout')
local refused=H.new(nil,W.newState());local exited=false;refused.onClose=function()exited=true end
refused:key('escape');check(exited and not E.accepted(H.GAME_MODULES),'back without accepting leaves the minigames locked')
fail=true;refused.gateChecked=true;refused.gateFocus=2;refused:action('a')
check(refused.enrolling and not E.accepted(H.GAME_MODULES),'a failed write never unlocks access');fail=false
local beforeVersion=E.VERSION;E.VERSION=beforeVersion+1
check(not E.accept(a,beforeVersion,H.GAME_MODULES),'changed notice version cannot be accepted through stale UI')
E.VERSION=beforeVersion;assert(E.accept(a,E.VERSION,H.GAME_MODULES))
local old=a.read(E.FILE);active=b
check(not E.accepted(H.GAME_MODULES),'another profile starts without inherited acceptance')
check(not E.accept(a,E.VERSION,H.GAME_MODULES)and not filesB[E.FILE]and filesA[E.FILE]==old,'an account change cannot store confirmation in either profile through stale UI')
active=a;E.VERSION=E.VERSION+1
check(not E.accepted(H.GAME_MODULES),'notice revision requires new acceptance');E.VERSION=beforeVersion
local added={unpack(H.GAME_MODULES)};added[#added+1]='src.pokewalker.minigames.FutureGame'
check(not E.accepted(added),'a changed registered catalogue requires a new acknowledgement')
filesA[E.FILE]='return os.execute("never execute")'
check(not E.accepted(H.GAME_MODULES),'malformed receipts fail closed without execution')
print('Minigame enrollment: '..n..' mandatory-entry checks passed')
