package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');love.filesystem.load=loadfile;local T=require('tests.harness')
local V=require('src.core.GameVersion');V.set('sapphire')
local Writer=require('src.import.LuaWriter');local Fs=require('src.import.CacheFs')
local Data=require('src.import.Gen3RsMapData');local oldRead,oldExists=Fs.read,Fs.exists
local files={
 ['data/generated/gba/rse/region_map/manifest.lua']=Writer.encode({layout={{}},assetLayout='rs',game='sapphire',sections={},files={'map.png'}}),
 ['data/generated/gba/region_map/map_sections.lua']=Writer.encode({layout='rs',build='sapphire',sections={}})}
Fs.read=function(p)return files[p]end;Fs.exists=function(p)return p=='map.png'end
T.eq(#Data.missing('sapphire'),0,'matching native map cache is ready')
T.eq(#Data.missing('ruby'),2,'wrong edition invalidates both native map manifests')
Fs.exists=function()return false end
T.eq(#Data.missing('sapphire'),1,'missing native map image invalidates cache')
Fs.read,Fs.exists=oldRead,oldExists
local load=require('compat.gen1-rs.Loader').new('sapphire')
local C=require('compat.gen1-rs.Constants').new(load)
T.eq(C:require('region_map_sections','MAPSEC_NONE'),88,'native RS section sentinel is bounded')
T.eq(C:flag('FLAG_HIDE_MAP_NAME_POPUP'),0x4000,'native hide-popup flag identity')
local sections={}
for i=0,87 do sections[i]={name='SECTION '..i,x=0,y=0,width=1,height=1}end
sections[0]={name='LITTLEROOT TOWN',x=4,y=11,width=1,height=1}
sections[1]={name='OLDALE TOWN',x=4,y=9,width=1,height=1}
local layout={};for y=1,15 do layout[y]={};for x=1,28 do layout[y][x]=88 end end
layout[12][5]=0;layout[10][5]=1
local mapsecs={};for name,id in pairs(C.region_map_sections.byName)do mapsecs[name:gsub('^MAPSEC_','')]=id end
local man={game='sapphire',layout=layout,assetLayout='rs',sections=sections,mapsecs=mapsecs,
  specialPlaces={{88,88}},redOutlineFlyDestinations={{mapSecId=88}},multiNameFlyDestinations={},heal={}}
local oldLoad=love.filesystem.load
love.filesystem.load=function(path)
  if path=='data/generated/gba/rse/region_map/manifest.lua'then return function()return man end end
  return loadfile(path)
end
local game={data={constants={gen3RsMap={format=1,version='sapphire',map='data/generated/gba/rse/region_map/manifest.lua',text={gOtherText_Hoenn='HOENN',gOtherText_FlyToWhere='FLY TO WHERE?'}},
  gen3RsBag={palette={}}},maps={MAP_G00_N09={group=0,number=9,regionMapSection=0,mapType='TOWN',width=20,height=20},
  MAP_G00_N10={group=0,number=10,regionMapSection=1,mapType='TOWN',width=20,height=20}}},
  save={flags={},options={},player={gender='girl'},visited={}},input={pressed={},held={}}}
for i=1,16 do game.data.constants.gen3RsBag.palette[i]=0 end
game.overworld={map={id='MAP_G00_N09',def=game.data.maps.MAP_G00_N09},player={cellX=5,cellY=9}}
function game.input:wasPressed(key)return self.pressed[key]end
function game.input:isDown(key)return self.held[key]or self.pressed[key]end
local globalRuntime=package.loaded['src.core.game3.runtime']
local kit=require('src.ui.Gen3RsMapKit').new(game)
T.eq(kit.session.gender,'female','host girl identity reaches native female fly logic')
T.eq(game.save.player.gender,'girl','native gender alias does not rewrite saved player')
T.eq(kit.mapView(game.data.maps.MAP_G00_N09).mapType,1,'string host map type becomes native enum in a view')
T.eq(game.data.maps.MAP_G00_N09.regionMapSectionId,nil,'native field aliases never enter host maps')
T.eq(kit.session.vars[0x4000],0,'unwritten script vars read zero')
T.eq(game.save.gen3Vars,nil,'reading native vars does not initialize save tables')
T.eq(package.loaded['src.core.game3.runtime'],globalRuntime,'native map runtime stays outside the host module cache')
game.data.maps.MAP_G00_N09.warps={{x=14,y=9}}
game.save.gen3DynamicWarp={map='MAP_G00_N09',warp=0,x=-1,y=-1}
T.eq(kit.session.dynamicWarp.x,14,'native map resolves raw zero-based saved warp event')
T.eq(game.save.gen3DynamicWarp.x,-1,'saved warp coordinates stay unchanged')
game.save.gen3DynamicWarp=nil;game.data.maps.MAP_G00_N09.warps=nil
local Popup=require('src.world.Gen3RsMapPopup').new(game)
T.check(Popup:matches(game),'popup belongs to current edition/data/save')
local savedData=game.data;game.data={};T.eq(Popup:matches(game),false,'popup rejects reloaded data context');game.data=savedData
local savedSave=game.save;game.save={};T.eq(Popup:matches(game),false,'popup rejects a different save context');game.save=savedSave
V.set('ruby');T.eq(Popup:matches(game),false,'popup rejects an edition switch');V.set('sapphire')
T.check(Popup:show(game.overworld.map.def),'native popup opens')
T.eq(Popup.native.window.name,'LITTLEROOT TOWN','native popup resolves RS town name')
for _=1,16 do Popup:tick()end
T.eq(Popup.native.task.yOffset,0,'popup slides in by two pixels for sixteen frames')
T.eq(Popup.native.task.state,1,'popup enters native wait state')
Popup:show(game.data.maps.MAP_G00_N10)
T.eq(Popup.native.task.state,2,'incoming map queues through slide-out')
for _=1,16 do Popup:tick()end
T.eq(Popup.native.window.name,'OLDALE TOWN','queued name changes after old popup leaves')
for _=1,170 do Popup:tick()end
T.eq(Popup.native.task,nil,'native popup erases after wait and slide-out')
game.save.flags.FLAG_G3_4000=true
T.eq(Popup:show(game.overworld.map.def),false,'script hide flag suppresses popup')
game.save.flags.FLAG_G3_4000=nil
local pops=0;local host={game=game,fly=false,close=function()pops=pops+1 end}
game.stack={pop=function()pops=pops+1 end}
local map=require('src.ui.Gen3RsRegionMap').new(host)
T.eq(map.state.mapSecId,0,'native wall map starts on player section')
T.eq(map.state.cursorX,5,'native player cursor has original x offset')
T.eq(map.state.cursorY,13,'native player cursor has original y offset')
for _=1,35 do map:update()end
T.eq(map.state.state,4,'native entrance reaches input state')
local before=map.state.cursorX;game.input.pressed={right=true};map:update();game.input.pressed={}
for _=1,5 do map:update()end
T.eq(map.state.cursorX,before+1,'native cursor advances one cell after its four-frame task')
game.input.pressed={a=true};map:update();game.input.pressed={}
for _=1,35 do map:update()end
T.eq(pops,1,'wall A returns once through host close callback')
T.check(map.closed,'closed native map stops updates')
T.eq(game.data.maps.MAP_G00_N09.regionMapSectionId,nil,'map initialization leaves original map object unchanged')
local H=C.heal_locations.byName
game.data.constants.gen3HealLocations={
 [H.HEAL_LOCATION_LITTLEROOT_TOWN_MAYS_HOUSE]={map='MAP_G00_N09',x=14,y=9},
 [H.HEAL_LOCATION_LITTLEROOT_TOWN_BRENDANS_HOUSE]={map='MAP_G00_N09',x=5,y=9},
 [H.HEAL_LOCATION_EVER_GRANDE_CITY_POKEMON_LEAGUE]={map='league',x=5,y=9},
 [H.HEAL_LOCATION_EVER_GRANDE_CITY]={map='city',x=27,y=49},
 [H.HEAL_LOCATION_BATTLE_TOWER_OUTSIDE]={map='tower',x=14,y=9}}
local chosen,warp
local flyhost={game=game,fly=true,close=function()pops=pops+1 end,
 onFly=function(id,dest)chosen=id;warp=dest end}
local fly=require('src.ui.Gen3RsRegionMap').new(flyhost)
T.eq(fly.state.mapSecType,3,'unvisited city cannot be flown to')
game.save.visited.MAP_G00_N09=false
fly:exit();fly=require('src.ui.Gen3RsRegionMap').new(flyhost)
T.eq(fly.state.mapSecType,3,'explicitly false legacy visit cannot unlock flight')
game.save.visited.MAP_G00_N09=true
fly:exit();fly=require('src.ui.Gen3RsRegionMap').new(flyhost)
T.eq(fly.state.mapSecType,2,'legacy visited map has native fly eligibility')
T.eq(game.save.flags[('FLAG_G3_%04X'):format(C:flag('FLAG_VISITED_LITTLEROOT_TOWN'))],nil,'legacy visits do not write native flags')
local dest=fly.native.flyWarpDestination(fly.kit.session,0,0)
T.eq(dest.x,14,'female Littleroot uses May native heal coordinates')
game.save.player.gender='boy';dest=fly.native.flyWarpDestination(fly.kit.session,0,0)
T.eq(dest.x,5,'male Littleroot uses Brendan native heal coordinates')
local leagueFlag=('FLAG_G3_%04X'):format(C:flag('FLAG_SYS_POKEMON_LEAGUE_FLY'))
game.save.flags[leagueFlag]=true
local ever=C:require('region_map_sections','MAPSEC_EVER_GRANDE_CITY')
dest=fly.native.flyWarpDestination(fly.kit.session,ever,0)
T.eq(dest.map,'league','League flag selects original northern Ever Grande heal row')
dest=fly.native.flyWarpDestination(fly.kit.session,ever,1)
T.eq(dest.map,'city','southern Ever Grande remains separate with League flag')
game.save.flags[leagueFlag]=false;dest=fly.native.flyWarpDestination(fly.kit.session,ever,0)
T.eq(dest.map,'city','closed League uses ordinary Ever Grande heal row')
dest=fly.native.flyWarpDestination(fly.kit.session,C:require('region_map_sections','MAPSEC_BATTLE_TOWER'),0)
T.eq(dest.map,'tower','native Battle Tower uses RS heal row')
fly.state.onPick(0,{posWithinMapSec=0})
T.eq(chosen,'MAP_G00_N09','native pick retains host map identity')
T.eq(warp.x,5,'native pick forwards exact original coordinates')
T.eq(warp.nativeRs,true,'native destination has explicit RS bridge tag')
T.check(fly.closed,'native pick closes adapter exactly once')
local contract=require('src.import.RomImporter').datasetContract('sapphire')
local legacy=require('src.import.RomImporter').datasetContract('emerald')
local function contains(rows,key)for _,v in ipairs(rows)do if v==key then return true end end;return false end
T.eq(contains(contract.modules,'scenes'),false,'RS native presentation replaces obsolete generic scene requirement')
T.eq(contains(legacy.modules,'scenes'),true,'Emerald retains its original scene requirement')
V.set('leafgreen');T.eq(require('src.ui.Gen3RsMapKit').available(game),false,'LeafGreen keeps its own map implementation')
love.filesystem.load=oldLoad
T.finish('Native RS map cache, constants, popup tasks and cursor contracts')
