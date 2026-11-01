-- Per-overworld native RSE weather. Each edition imports its own resources.
-- Private presentation RNG and task state never enter saves.
local M={}
function M.translate(value,stage,spec)
  value=math.floor(tonumber(value)or 0)%256
  if value<=14 or(value==15 and spec and spec.version=='emerald')then return value end
  local key=value==20 and'route119'or(value==21 and'route123')
  return key and spec.cycles[key][(math.floor(stage or 0)%4)+1]or 0
end
function M.spec(game)
  local version=require('src.core.GameVersion').get()
  local constants=game.data.constants
  return version=='emerald'and constants.gen3EmeraldWeather or constants.gen3RsWeather
end
function M.available(game)
  local version=require('src.core.GameVersion').get()
  local assets=version=='emerald'and'src.import.Gen3EmeraldWeatherAssets'or'src.import.Gen3RsWeatherAssets'
  return require(assets).valid(M.spec(game),version)
end
local function setMode(state,value,immediate)
  local engine=state.engine;local actual=value
  if value==15 then actual=engine.startAbnormal()
  elseif state.abnormal then engine.stopAbnormal()end
  if immediate then engine.setCurrentAndNextWeatherNoDelay(actual)
  else engine.setNextWeather(actual)end
  state.value=value;state.abnormal=value==15
end
-- An observation must not create tasks, poll the calendar or write the save.
function M.current(ow,game)
  local spec=M.spec(game)
  if spec and spec.version=='emerald'then
    local state=ow.rsWeather
    if state and state.data==game.data and state.engine.state.initialized then
      return state.engine.getCurrentWeather()
    end
  end
  local value=M.translate(game.save.gen3WeatherActive,ow:gen3WeatherStage(),spec)
  if value==15 then
    return 13
  end
  return value
end
local function create(game,ow)
  local version=require('src.core.GameVersion').get()
  local Fs=require('src.import.CacheFs');local Sound=require('src.core.Sound')
  local presentation=version=='emerald'and game.data.constants.gen3EmeraldPresentation
    or game.data.constants.gen3RsPresentation
  local songs=presentation.songIds
  local audio={handles={},rain={}}
  local weatherCues={}
  for _,name in ipairs{'SE_RAIN','SE_RAIN_STOP','SE_DOWNPOUR','SE_DOWNPOUR_STOP',
    'SE_THUNDERSTORM','SE_THUNDERSTORM_STOP','SE_THUNDER','SE_THUNDER2'}do
    if songs[name]then weatherCues[songs[name]]=name end
  end
  function audio.playSe(id)
    local name=version=='emerald'and weatherCues[id]
    -- The host ambient service retains weather voice ownership and mod claims.
    -- Original thunder one-shots still follow the native weather task's clock.
    if name and name~='SE_THUNDER'and name~='SE_THUNDER2'then return end
    local source
    if name then source=Sound.playWeatherEffect(game.data,name,false)
    else source=Sound.playId(game.data,id)end
    audio.handles[id]=source
    for _,name in ipairs({'SE_RAIN','SE_DOWNPOUR','SE_THUNDERSTORM'})do
      if id==songs[name]then audio.rain[id]=source end
    end
    return source
  end
  function audio.isSePlaying()
    for _,source in pairs(audio.handles)do if source:isPlaying()then return true end end
    return false
  end
  function audio.isSpecialSePlaying()
    for _,source in pairs(audio.rain)do if source:isPlaying()then return true end end
    return false
  end
  local profile={weather=false}
  local weather={}
  for id,name in pairs(game.data.constants.gen3WeatherNames or{})do weather[name]=id end
  local packages={loaded={['src.core.game3.audio']=audio}}
  local load=require('compat.gen1-rs.Loader').new(version,{
    __package=packages,['src.import.CacheFs']=Fs,
    ['src.core.game3.dataset']={cache=function()return{read=function(_,path)return Fs.read(path)end}end},
    ['src.core.game3.audio']=audio,['src.core.game3.se_ids']=songs,
    ['src.core.game3.weather']=weather,
    ['src.core.game3.profile']={forSession=function()return profile end}})
  if version=='emerald'then
    -- Emerald reads six raw drought lookup tables in one loading step.
    -- Its original sprite palette slots select the same per-slot color maps.
    profile.weather={fixedObjectPaletteSlots=true,droughtPaletteLoadFrames=1}
  else profile.weather=load('src.core.game3.profiles.rs.weather')end
  local engine=load('src.core.game3.field_weather_rse')
  local state={engine=engine,game=game,data=game.data,version=version,audio=audio}
  function weather.setWeather(value)
    value=M.translate(value,ow:gen3WeatherStage(),M.spec(game))
    game.save.gen3Weather=value;game.save.gen3WeatherActive=value
    setMode(state,value,false)
  end
  state.coordinate=load('src.core.game3.coord_weather')
  load('src.core.game3.rng').SeedRng(os.time()%65536)
  return state
end
local function context(ow,game)
  local state=ow.rsWeather
  if not state or state.data~=game.data then state=create(game,ow);ow.rsWeather=state end
  return state
end
function M.coordinate(ow,game)
  if not M.available(game)then return false end
  local player=ow.player
  if not(player and ow.map and ow.map.def)then return false end
  local state,changed
  for index,event in ipairs(ow.map.def.coordEvents or{})do
    if event.x==player.cellX and event.y==player.cellY
      and((tonumber(event.elevation)or 0)==0 or event.elevation==player.elevation)then
      state=state or context(ow,game)
      local visit=('%s|%d,%d'):format(tostring(ow.cellSerial or 0),player.cellX,player.cellY)
      if state.coordAt~=visit then state.coordAt=visit;state.coordFired={}end
      local script=event.script
      if not state.coordFired[index]
        and state.coordinate.isWeatherEvent({scriptKey=script~=0 and script or nil,scriptPtr=script})then
        state.coordFired[index]=true
        changed=state.coordinate.run(event.var)or changed
      end
    end
  end
  return changed==true
end
function M.update(ow,game)
  if not M.available(game)then return end
  local state=context(ow,game)
  local stage=ow:gen3WeatherStage()
  local value=M.translate(game.save.gen3WeatherActive,stage,M.spec(game))
  local engine=state.engine
  if state.map~=ow.map then
    -- Abnormal weather's alternating task continues across adjacent maps.
    if not(state.abnormal and value==15)then engine.restart();state.abnormal=false end
    engine.resetCamera();setMode(state,value,true);state.map=ow.map
  elseif state.value~=value then setMode(state,value,false)end
  engine.setCamera(ow.camera.x,ow.camera.y);engine.update()
  if state.version=='emerald'then require('src.world.Gen3WeatherAudio').update(game,ow)end
end
function M.drawBelow(ow,cam,w,h)
  if ow.rsWeather then ow.rsWeather.engine.drawBelow(cam.x,cam.y,w,h)end
end
function M.draw(ow,cam,w,h)
  if ow.rsWeather then ow.rsWeather.engine.draw(cam.x,cam.y,w,h)end
end
function M.actorMask(ow,entity,draw)
  local state=ow.rsWeather;if not(state and state.engine.maskActive())then return end
  local id=entity.def and tonumber((entity.def.sprite or''):match('^SPRITE_G3_(%d+)$'))
  -- The player's currently displayed native sheet selects walking/bike/surf slots.
  if entity==ow.player then
    local sprite=entity:pose()
    local def=sprite and sprite.def
    id=tonumber((def and def.id or entity.walkId or''):match('^SPRITE_G3_(%d+)'))or id
  end
  local spec=M.spec(state.game)
  local slot=id and spec.objectPaletteSlots[id]
  state.engine.writeActorMask(state.engine.actorMaskCode(slot),draw)
end
return M
