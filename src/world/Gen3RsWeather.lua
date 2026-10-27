-- Per-overworld native RS weather. Private RNG and module state never enter saves.
local M={}
function M.translate(value,stage,spec)
  value=math.floor(tonumber(value)or 0)%256
  if value<=14 then return value end
  local key=value==20 and'route119'or(value==21 and'route123')
  return key and spec.cycles[key][(math.floor(stage or 0)%4)+1]or 0
end
function M.available(game)
  local version=require('src.core.GameVersion').get()
  return require('src.import.Gen3RsWeatherAssets').valid(game.data.constants.gen3RsWeather,version)
end
local function create(game,ow)
  local version=require('src.core.GameVersion').get()
  local Fs=require('src.import.CacheFs');local Sound=require('src.core.Sound')
  local songs=game.data.constants.gen3RsPresentation.songIds
  local audio={handles={},rain={}}
  function audio.playSe(id)
    local source=Sound.playId(game.data,id);audio.handles[id]=source
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
  profile.weather=load('src.core.game3.profiles.rs.weather')
  local engine=load('src.core.game3.field_weather_rse')
  local state={engine=engine,game=game,data=game.data,version=version,audio=audio}
  function weather.setWeather(value)
    value=M.translate(value,ow:gen3WeatherStage(),game.data.constants.gen3RsWeather)
    game.save.gen3Weather=value;game.save.gen3WeatherActive=value
    engine.setNextWeather(value);state.value=value
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
  local value=M.translate(game.save.gen3WeatherActive,stage,game.data.constants.gen3RsWeather)
  local engine=state.engine
  if state.map~=ow.map then
    engine.restart();engine.resetCamera();engine.setCurrentAndNextWeatherNoDelay(value)
    state.map=ow.map;state.value=value
  elseif state.value~=value then engine.setNextWeather(value);state.value=value end
  engine.setCamera(ow.camera.x,ow.camera.y);engine.update()
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
  local spec=state.data.constants.gen3RsWeather
  local slot=id and spec.objectPaletteSlots[id]
  state.engine.writeActorMask(state.engine.actorMaskCode(slot),draw)
end
return M
