package.path='./?.lua;./?/init.lua;'..package.path
local count=0;local function check(v,why)count=count+1;assert(v,why)end
love={filesystem={load=function(path)return loadfile(path)end}}
local cues={};local playing=false
package.loaded['src.core.Sound']={playId=function(_,id)cues[#cues+1]=id
  return{isPlaying=function()return playing end}
end}
package.loaded['src.import.CacheFs']={prefix='weather-contract',read=function()return nil end}
local V=require('src.core.GameVersion');V.set('sapphire')
local W=require('src.world.Gen3RsWeather');local A=require('src.import.Gen3RsWeatherAssets')
local spec={format=1,version='sapphire',resources={},cycles={route119={2,3,5,3},route123={2,2,3,2}},
  objectPaletteSlots={[0]=0,[100]=0,[105]=0}}
for i=1,32 do spec.resources[i]='fixture-'..i end
check(A.valid(spec,'sapphire'),'A complete edition-specific weather manifest must be accepted')
check(not A.valid(spec,'ruby')and not A.valid(spec,'emerald'),'No edition may borrow another weather cache')
for i=0,14 do check(W.translate(i,0,spec)==i,'Direct native weather ID changed')end
for _,id in ipairs({-1,15,19,22,255})do check(W.translate(id,0,spec)==0,'Unsupported RS weather must translate to NONE')end
check(W.translate(263,0,spec)==7,'RS weather arguments use a byte')
for stage=0,7 do
  check(W.translate(20,stage,spec)==spec.cycles.route119[stage%4+1],'Route119 daily cycle changed')
  check(W.translate(21,stage,spec)==spec.cycles.route123[stage%4+1],'Route123 daily cycle changed')
end
local game={data={constants={gen3RsWeather=spec,gen3WeatherNames={[2]='SUNNY',[7]='VOLCANIC_ASH',
  [20]='ROUTE119_CYCLE',[21]='ROUTE123_CYCLE'},gen3RsPresentation={songIds={SE_RAIN=83,
  SE_RAIN_STOP=84,SE_DOWNPOUR=85,SE_DOWNPOUR_STOP=86,SE_THUNDERSTORM=87,SE_THUNDERSTORM_STOP=88}}}},
  save={gen3WeatherActive=7,untouched={party='natural',inventory=5}}}
local stage=0;local ow={map={},camera={x=16,y=32},gen3WeatherStage=function()return stage end}
local encode=require('src.import.LuaWriter').encode;local before=encode(game.save)
W.update(ow,game);local first=ow.rsWeather;local engine=first.engine
check(engine.snapshot().ash and engine.snapshot().curr==7,'Actual map entry must initialize native ash')
for _=1,120 do W.update(ow,game)end
check(first==ow.rsWeather and engine.state.frames==121,'Ordinary ticks must retain the same native task')
check(encode(game.save)==before,'Native task must not change party, inventory, weather bytes or saves')
local dy=engine.state.ashOffsetY;for _=1,6 do W.update(ow,game)end
check(engine.state.ashOffsetY==dy+1,'Native ash falls one native pixel per six field frames')
local cameraX=engine.state.totalCamX;ow.camera.x=ow.camera.x+16;W.update(ow,game)
check(engine.state.totalCamX==(cameraX-16)%65536,'Weather must follow the actual camera displacement')
game.save.gen3WeatherActive=3;W.update(ow,game)
check(engine.state.nextWeather==3,'Scripted DOWEATHER must request a transition')
for _=1,600 do W.update(ow,game)end
check(engine.snapshot().curr==3 and engine.snapshot().rainVisible==10,'Native rain must finish the ash transition')
check(#cues>0,'Native rain must play its original sound')
ow.map={};game.save.gen3WeatherActive=0;W.update(ow,game)
check(engine.snapshot().curr==0 and not engine.snapshot().ash,'A new clear map must clear old ash immediately')
check(engine.state.frames==1,'A map load must restart the native weather task')
ow.map={};game.save.gen3WeatherActive=20;stage=2;W.update(ow,game)
check(engine.getCurrentWeather()==5,'Daily route weather must use the extracted cycle table')
local function trigger()ow.cellSerial=(ow.cellSerial or 0)+1;return W.coordinate(ow,game)end
ow.player={cellX=19,cellY=11,elevation=3}
ow.map.def={coordEvents={{x=19,y=11,elevation=3,var=8,value=999}}}
check(trigger(),'Scriptless trigger8 must run without treating it as save variable8')
check(game.save.gen3Weather==7 and game.save.gen3WeatherActive==7 and engine.state.nextWeather==7,
  'Coordinate weather must update saved, active and next native weather together')
check(not W.coordinate(ow,game),'Rechecking the same visit must not restart coordinate weather')
ow.map.def.coordEvents[1].elevation=4
game.save.gen3WeatherActive=2
check(not trigger()and game.save.gen3WeatherActive==2,'Other elevations must not trigger weather')
ow.map.def.coordEvents[1].elevation=0
check(trigger()and game.save.gen3WeatherActive==7,'Elevation0 must match any player elevation')
ow.map.def.coordEvents[1].script=0x8123456;game.save.gen3WeatherActive=2
check(not trigger()and game.save.gen3WeatherActive==2,'Real coordinate scripts must not become weather')
ow.map.def.coordEvents[1].script='S1234567'
check(not trigger(),'A nonnumeric script key must not be mistaken for a null pointer')
ow.map.def.coordEvents[1].script=0;ow.map.def.coordEvents[1].var=2
check(trigger()and game.save.gen3WeatherActive==2,'The clear-weather boundary must clear ash')
ow.map.def.coordEvents[1].var=20
check(trigger()and game.save.gen3WeatherActive==5,'Coordinate cycles must use native daily translation')
ow.map.def.coordEvents[1].var=15
check(not trigger(),'RS has no coordinate trigger15')
ow.player.cellX=18
check(not trigger(),'Only the entered cell can change coordinate weather')
V.set('ruby');check(not W.available(game),'Changing edition must reject the previous weather cache')
print('PASS_RS_WEATHER_CONTRACT '..count)
