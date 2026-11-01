-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');local T=require('tests.harness')
love.filesystem.load=function(path)return loadfile(path)end
local V=require('src.core.GameVersion');V.set('emerald')
local A=require('src.import.Gen3EmeraldWeatherAssets');local W=require('src.world.Gen3RsWeather')
local Writer=require('src.import.LuaWriter');local Fs=require('src.import.CacheFs')
local oldRead,oldExists=Fs.read,Fs.exists
local spec={format=1,version='emerald',resources=A.resources(),objectPaletteSlots={[0]=0,[100]=0,[105]=0},
 cycles={route119={2,3,5,3},route123={2,2,3,2}}}
T.eq(A.valid(spec,'emerald'),true,'complete own-edition weather contract')
for _,edition in ipairs{'ruby','sapphire','firered','leafgreen'}do
 T.eq(A.valid(spec,edition),false,'Emerald weather cannot satisfy another edition')
end
local readFiles={['data/generated/constants.lua']={gen3EmeraldWeather=spec},
 [A.ROOT..'manifest.lua']={format=1,game='emerald',family='rse',blobs={},palettes={}}}
Fs.read=function(path)return readFiles[path]and Writer.encode(readFiles[path])end
Fs.exists=function()return true end
T.eq(#A.missing(),0,'complete own manifest and all weather bytes')
readFiles[A.ROOT..'manifest.lua'].game='sapphire'
T.eq(A.missing()[1],A.ROOT..'manifest.lua','another RSE manifest cannot satisfy Emerald')
readFiles[A.ROOT..'manifest.lua'].game='emerald'
Fs.exists=function(path)return path~=A.ROOT..'rain.idx'end
T.eq(A.missing()[1],A.ROOT..'rain.idx','a missing original sheet forces cache upgrade')
spec.cycles.route119[2]=15
T.eq(A.valid(spec,'emerald'),false,'route cycle rejects abnormal mode')
spec.cycles.route119[2]=3
spec.resources[1]='data/generated/foreign/weather'
T.eq(A.valid(spec,'emerald'),false,'weather paths are exact and edition isolated')
spec.resources=A.resources();spec.objectPaletteSlots[0]=16
T.eq(A.valid(spec,'emerald'),false,'invalid original object palette slot rejected')
spec.objectPaletteSlots[0]=0
local load=require('compat.gen1-rs.Loader').new('emerald')
local S=load('src.import.gba.syms').of('emerald');local cfg=A.configure(S)
T.eq(cfg.palettes.fog,0x54c270,'own Emerald fog palette')
T.eq(cfg.drought_colors,0x54014c,'own raw drought table')
T.eq(cfg.drought_colors_size,0xc000,'six complete native drought lookup tables')
T.eq(cfg.drought_compressed,nil,'Emerald does not borrow Ruby compressed deltas')
T.eq(#cfg.blobs,9,'all original weather sheets')
T.eq(cfg.cycles.route119.off,0x54fe5c,'own Emerald Route119 cycle')
T.eq(cfg.cycles.route123.off,0x54fe60,'own Emerald Route123 cycle')
for i=0,15 do T.eq(W.translate(i,0,spec),i,'native Emerald weather id')end
for stage=0,7 do
 T.eq(W.translate(20,stage,spec),spec.cycles.route119[stage%4+1],'four-stage Route119 cycle')
 T.eq(W.translate(21,stage,spec),spec.cycles.route123[stage%4+1],'four-stage Route123 cycle')
end
Fs.read=function()return nil end
local Sound=require('src.core.Sound');local oldPlay=Sound.playId;local cues={}
Sound.playId=function(_,id)cues[#cues+1]=id;return{isPlaying=function()return false end}end
local game={data={constants={gen3EmeraldWeather=spec,gen3WeatherNames={
 [0]='NONE',[2]='SUNNY',[3]='RAIN',[5]='RAIN_THUNDERSTORM',[7]='VOLCANIC_ASH',[15]='ABNORMAL'},
 gen3EmeraldPresentation={songIds={SE_RAIN=83,SE_RAIN_STOP=84,SE_DOWNPOUR=85,
 SE_DOWNPOUR_STOP=86,SE_THUNDERSTORM=87,SE_THUNDERSTORM_STOP=88}}}},
 save={gen3WeatherActive=7,party={'untouched'},inventory={SUPER_POTION=2}}}
local stage=0;local ow={map={},camera={x=16,y=32},gen3WeatherStage=function()return stage end}
T.eq(W.available(game),true,'native provider accepts own Emerald resources')
local before=Writer.encode(game.save);W.update(ow,game)
local engine=ow.rsWeather.engine
T.eq(engine.snapshot().ash,true,'map entry initializes original ash task')
for _=1,60 do W.update(ow,game)end
T.eq(Writer.encode(game.save),before,'weather ticks preserve complete save')
T.eq(engine.state.frames,61,'native clock advances once per field update')
ow.map={};game.save.gen3WeatherActive=20;stage=2;W.update(ow,game)
T.eq(engine.getCurrentWeather(),5,'map weather uses the own-ROM cycle')
ow.player={cellX=19,cellY=11,elevation=3};ow.cellSerial=1
ow.map.def={coordEvents={{x=19,y=11,elevation=3,var=8,script=0}}}
T.eq(W.coordinate(ow,game),true,'scriptless Emerald boundary invokes native weather')
T.eq(game.save.gen3Weather,7,'coordinate event commits saved native ash')
T.eq(game.save.gen3WeatherActive,7,'coordinate event activates ash')
T.eq(W.coordinate(ow,game),false,'same visit does not restart the effect')
ow.cellSerial=2;ow.map.def.coordEvents[1].elevation=4
T.eq(W.coordinate(ow,game),false,'another elevation cannot trigger weather')
ow.cellSerial=3;ow.map.def.coordEvents[1].elevation=0;ow.map.def.coordEvents[1].var=20
T.eq(W.coordinate(ow,game),true,'cycle coordinate accepts wildcard elevation')
T.eq(game.save.gen3WeatherActive,5,'cycle uses the committed stage')
ow.map={};game.save.gen3WeatherActive=15;W.update(ow,game)
T.eq(W.current(ow,game),13,'abnormal mode begins with original downpour')
local committed=Writer.encode(game.save)
for _=1,601 do W.update(ow,game)end
T.eq(engine.state.currentAbnormal,12,'original task requests drought after its 600-frame delay')
T.eq(W.current(ow,game),engine.getCurrentWeather(),'battle inherits actual effect during the native transition')
for _=1,240 do if engine.getCurrentWeather()==12 then break end;W.update(ow,game)end
T.eq(W.current(ow,game),12,'original abnormal task alternates to drought')
local task=engine.state.abnormal;local delay=task.delay
ow.map={};W.update(ow,game)
T.eq(engine.state.abnormal,task,'adjacent abnormal maps retain the same original timer')
T.eq(engine.state.abnormal.delay,delay-1,'map entry does not reset the abnormal cycle')
T.eq(Writer.encode(game.save),committed,'abnormal animation does not rewrite saved mode')
game.save.gen3WeatherActive=2;W.update(ow,game)
T.eq(engine.state.abnormal,nil,'ordinary weather stops the abnormal task')
local frames=engine.state.frames
local time,random=os.time,math.random
os.time=function()error('weather observation polled calendar')end
math.random=function()error('weather observation consumed gameplay RNG')end
T.eq(W.current(ow,game),2,'battle observation uses committed weather')
T.eq(engine.state.frames,frames,'battle observation cannot advance the task')
os.time,math.random=time,random
V.set('sapphire');T.eq(W.available(game),false,'edition switch rejects stale Emerald state')
Sound.playId=oldPlay;Fs.read,Fs.exists=oldRead,oldExists
-- Exercise the real overworld entry points, including a map with no script hook.
local fixture=require('tools.player-runtime.fixture').new('emerald')
local g,world=fixture.game,fixture.world
g.data.constants.gen3EmeraldWeather=spec
g.data.constants.gen3EmeraldPresentation=game.data.constants.gen3EmeraldPresentation
g.data.constants.gen3WeatherNames=game.data.constants.gen3WeatherNames
local player=world.player
world.map.def.coordEvents={{x=player.cellX,y=player.cellY,elevation=0,var=8,script=0}}
world.coordFired=nil;world:checkCoordEventHere()
T.eq(g.save.gen3WeatherActive,7,'ordinary Emerald cell entry reaches the native coordinate dispatcher')
T.eq(world.runner:isRunning(),false,'weather does not acquire the script runner')
world.map.def.weather=2;g.save.player.map=world.map.id
world:applyMapWeather({via='boot'})
T.eq(g.save.gen3WeatherActive,7,'CONTINUE preserves saved coordinate weather over sunny header')
world:applyMapWeather({via='warp'})
T.eq(g.save.gen3WeatherActive,2,'ordinary new map entry uses its own header')
T.finish('Emerald native weather ownership, coordinate dispatch, daily cycles and abnormal task')
