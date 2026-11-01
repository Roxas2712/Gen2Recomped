-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local F=require('tools.player-runtime.fixture')
local OW=require('src.world.OverworldController')
local V=require('src.core.GameVersion')
local Json=require('src.link.Json')
local originalTime,originalRandom=os.time,math.random
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  local f=F.new(edition);local g,w=f.game,f.world
  g.data.constants.gen3WeatherNames={[0]='NONE',[2]='SUNNY',[3]='RAIN',[5]='RAIN_THUNDERSTORM',[20]='ROUTE119_CYCLE'}
  g.data.constants.gen3BattleWeather={SUNNY=nil,RAIN='RAIN',RAIN_THUNDERSTORM='RAIN'}
  g.renderer={}
  for _,weather in ipairs{0,2,3,20}do
    g.save.gen3WeatherActive=weather
    g.save.gen3WeatherDay=nil;g.save.gen3WeatherStage=nil
    local before=Json.encode(g.save)
    os.time=function()error('render/observation polled the calendar')end
    math.random=function()error('render/observation consumed gameplay RNG')end
    T.eq(w:gen3WeatherStage(),0,'new saves expose the initial committed stage')
    w:drawFieldWeather();w:battleWeather();w:drawFieldWeather()
    if weather==3 then T.check(g.renderer.screenWeather(240,160),'rain still draws its native presentation')end
    T.eq(Json.encode(g.save),before,edition..' first and repeated weather draws preserve the entire save')
    math.random=originalRandom
  end
  os.time=function()return 17*86400+100 end
  f.map.def.weather=20
  g.save.gen3WeatherDay=nil;g.save.gen3WeatherStage=nil
  w:applyMapWeather()
  T.eq(g.save.gen3WeatherDay,17,'map entry initializes the daily calendar before drawing')
  T.eq(g.save.gen3WeatherStage,0,'new-game weather starts at original stage zero')
  T.eq(w:battleWeather(),nil,'first cycle stage remains sunny')
  os.time=function()return 19*86400 end
  local before=Json.encode(g.save)
  T.eq(w:gen3WeatherStage(),0,'a render does not advance a paused field across days')
  w:drawFieldWeather()
  T.eq(Json.encode(g.save),before,'day rollover waits for a field update')
  T.eq(w:updateGen3WeatherStage(),2,'field update advances by elapsed days')
  T.eq(g.save.gen3WeatherDay,19)
  T.eq(w:battleWeather(),nil,'calendar stage changes preserve the already saved sunny weather')
  T.eq(g.save.gen3Weather,2,'daily update does not retranslate a saved byte')
  local rainCount=(g.save.gen3Stats or{})[40]or 0
  w:applyMapWeather({via='warp'})
  T.eq(w:battleWeather(),'RAIN','next map-header commitment resolves the new cycle stage')
  T.eq(g.save.gen3Weather,5,'native saved weather stores the resolved thunderstorm')
  T.eq((g.save.gen3Stats or{})[40],rainCount+1,'new rainy commitment increments the original statistic once')
  T.eq(w:updateGen3WeatherStage(),2,'repeated updates do not double-count elapsed days')
  os.time=function()return 22*86400 end
  T.eq(w:updateGen3WeatherStage(),1,'multi-day advances retain the original four-stage cycle')
  os.time=function()return 21*86400 end
  T.eq(w:updateGen3WeatherStage(),1,'clock rollback preserves the existing stage')
  T.eq(g.save.gen3WeatherDay,21,'clock rollback retains the existing baseline policy')
  -- Exercise the actual update entry without requiring unrelated field assets.
  os.time=function()return 22*86400 end
  local calls=0
  w.updateGen3WeatherStage=function(self)
    calls=calls+1;OW.updateGen3WeatherStage(self);error('weather-update-boundary')
  end
  local ok,why=pcall(OW.update,w,1/60)
  T.eq(ok,false);T.check(tostring(why):find('weather%-update%-boundary')~=nil)
  T.eq(calls,1,'ordinary field update commits the calendar once before other work')
  T.eq(g.save.gen3WeatherStage,2)
  w.updateGen3WeatherStage=nil
  local committed=Json.encode(g.save)
  os.time=function()error('reader polled calendar after update')end
  T.eq(w:gen3WeatherStage(),2);w:drawFieldWeather();w:battleWeather()
  T.eq(Json.encode(g.save),committed,'post-update observations stay read-only')
  os.time=originalTime
end
for _,edition in ipairs{'red','gold','platinum','black'}do
  V.set(edition)
  os.time=function()error('non-GBA calendar must stay untouched')end
  local g=require('src.core.Game');local before=Json.encode(g.save)
  T.eq(OW.gen3WeatherStage({}),0);T.eq(OW.updateGen3WeatherStage({}),0)
  T.eq(Json.encode(g.save),before,'other generations retain their own weather state')
end
os.time,math.random=originalTime,originalRandom
T.finish('GBA first-draw save immutability, committed daily weather and lifecycle advancement')
