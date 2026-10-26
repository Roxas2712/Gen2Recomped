package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion');local M=require('src.world.FriendMap')
love.data={hash=function(_,s)return s end,encode=function(_,_,s)return require('src.link.Fingerprint').digest(s):rep(4)end}
local data=T.fixtures.fresh();local map=require('src.world.Map').new(data.maps.FIX_TOWN,data.tilesets.FIX_OUT)
local game={data=data,save={options={}},overworld={map=map}};package.loaded['src.core.Game']=game
local A=require('src.ui.FriendActivity');local doc
package.loaded['src.cloud.Play']={read=function()return doc end}
V.set('red');local proof=M.describe(game.overworld);local device={edition='blue',zone={map=map.id,navigation=proof}}
T.check(A.resolve(game,device).id==map.id,'Red resolves a verified Blue map against its own imported navigation')
local edition,zone=A.label(game,{edition='yellow'})
T.check(edition=='Pokemon Yellow'and zone=='Unknown zone','edition stays visible when the friend has not shared a zone')
device.zone.navigation={schema=1,map=map.id,width=proof.width,height=proof.height,layout='different'}
T.eq(A.resolve(game,device),nil,'changed mod navigation never becomes a guessed map marker')
device.zone.navigation=proof;device.edition='gold';T.eq(A.resolve(game,device),nil,'different generations never reuse a matching-looking map identifier')
for _,version in ipairs({'red','gold','emerald'})do
 V.set(version);local info={edition=version,zone={map=map.id,navigation=M.describe(game.overworld)}}
 T.check(A.resolve(game,info),'presence can resolve edition maps in generations 1, 2 and 3')
end
V.set('red');device.edition='blue';doc={friends={}}
for i=1,8 do doc.friends[i]={account_id=tostring(i),nickname='Friend '..i,playing={device,device}}end
T.eq(#A.locations(game),5,'standard map caps at five distinct friends and ignores duplicate devices')
doc=nil;T.eq(#A.locations(game),0,'stale presence leaves no lingering map markers')
T.finish('Friend edition and zone mapping')
