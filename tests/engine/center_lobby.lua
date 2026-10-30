-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;'..package.path
love=require('tests.love_stub');love.timer={getTime=function()return 0 end}
local version='red';local generation=1
package.loaded['src.core.GameVersion']={get=function()return version end,generation=function()return generation end}
package.loaded['src.core.MapIdentity']={sourceId=function(_,id)return id end}
package.loaded['src.cloud.RetroCloud']={signedIn=function()return false end,accountId=function()return nil end}
package.loaded['src.cloud.Play']={read=function()return{}end}
package.loaded['src.cloud.Task']={}
package.loaded['src.ui.PlayerRole']={label=function(s)return s end}
local C=require('src.ui.CenterLobby');local n=0;local function check(v,m)assert(v,m);n=n+1 end
for _,id in ipairs({'VIRIDIAN_POKECENTER','CHERRYGROVE_POKECENTER_1F','MAP_PETALBURG_CITY_POKEMON_CENTER_1F'})do
 local g={data={},save={},overworld={map={id=id,def={}}}}
 check(C.center(g)==id,'all GB/GBC/GBA Center identifiers expose the lobby')
end
check(not C.center({data={},overworld={map={id='VIRIDIAN_CITY',def={}}}}),'outdoor maps do not expose a Center lobby')
generation=4;version='platinum';package.loaded['src.world.Gen4Blackout']={spawnFor=function(_,id)return id==12 and {home=false}or id==1 and{home=true}end}
check(C.center({data={},overworld={map={id=12,def={}}}})=='12','DS Centers use the extracted native heal-location registry')
check(not C.center({data={},overworld={map={id=1,def={}}}}),'the DS home spawn is not mistaken for a Center')
version='heartgold';check(not C.supported(),'unqualified editions remain unavailable')
version='platinum';check(C.supported(),'qualified Platinum links are available')
local O={page='centerLobby',game={save={party={1}}}}
C.action(O,'centerPublic');check(O.notice:find('Sign in',1,true)and C.mode=='off','guests receive a clear online sign-in explanation without auto-advertising')
local rows=C.rows(O);local ids={};for _,r in ipairs(rows)do ids[r.id]=true end
check(ids.nearTrade and ids.nearBattle,'separate nearby trade and battle lobbies remain available to guests')
generation=3;version='firered'
local originalGame={save={party={1}}};O.game=originalGame
O.close=function()O.game=nil end;O.open=function(game)O.game=game end
package.loaded['src.ui.RetroOverlay']=O
local captured
package.loaded['src.features.Gen1CableLobby']={open=function(game)captured=game;return{}end}
C.action(O,'compatCable')
check(captured==originalGame,'cable entry retains its native owner when closing the overlay clears O.game')
O.game=originalGame;O.job={};captured=nil
C.action(O,'compatCable');check(captured==nil and O.game==originalGame,'active upload prevents opening another owner')
O.job=nil
package.loaded['src.features.Gen1CableLobby'].open=function()return nil,'not admitted'end
C.action(O,'compatCable');check(O.game==originalGame and O.notice=='not admitted','failed admission restores the Center overlay')
print('Center lobby: '..n..' checks passed')
