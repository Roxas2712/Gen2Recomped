-- Prepared weather fixtures, separately reported from the ordinary story.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local W=require('src.world.Gen3RsWeather')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(edition=='ruby'or edition=='sapphire')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(W.available(game)and require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game);U.teleport(game,'MAP_G24_N12',17,37,'up');U.wait(120)
  local world=game.overworld
  local report={edition=edition,status='running',preparedWeatherFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,snapshots={},cycles={},audio={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(bytes==Save.encode(game.save)and rng==love.math.getRandomState(),'Weather draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  for _,name in ipairs({'SE_RAIN','SE_THUNDERSTORM','SE_DOWNPOUR','SE_RAIN_STOP'})do
    local id=assert(game.data.constants.gen3RsPresentation.songIds[name])
    local label=('SONG_%03X'):format(id)
    local synth=require('src.core.M4ASynth').newEngine(game.data,assert(game.data.audio.songs[label]),{allowLoops=false})
    local audible=false
    for _=1,44100 do local l,r=synth:sampleStereo();if l~=0 or r~=0 then audible=true;break end end
    assert(audible,'Silent original weather cue '..name)
    report.audio[name]={id=id,nonzeroPCM=true}
  end
  local engine=assert(world.rsWeather).engine
  assert(world.map.def.weather==7 and engine.snapshot().ash,'Mt. Chimney header must start native ash')
  shot('mt-chimney-native-ash');report.cases.actualMapHeaderAsh=true
  local spec=game.data.constants.gen3RsWeather
  local m=assert(engine.manifest());assert(m.family=='rse'and m.blobs.ash.w==64 and m.blobs.ash.h==128)
  assert(m.drought.tables==6 and #m.color_map_types==32)
  report.cases.originalGraphicsPalettesAndDrought=true
  for value=0,14 do
    -- Restart a prepared map's weather task, as a native map load does, so all
    -- weather states are tested independently of the previous effect's finish.
    game.save.gen3WeatherActive=value;world.rsWeather.map=nil;U.wait(240)
    local s=engine.snapshot();assert(s.curr==value and s.initialized,'Weather failed initialization '..value)
    if value==3 then assert(s.rain==24 and s.rainVisible==10)end
    if value==4 then assert(s.snow==16)end
    if value==7 then assert(s.ash)end
    if value==8 then assert(s.sandstorm and s.swirls==5)end
    if value==14 then assert(s.bubbles>0)end
    report.snapshots[tostring(value)]=s;shot(('weather-%02d'):format(value))
  end
  report.cases.allFifteenNativeWeatherStates=true
  for _,value in ipairs({20,21})do for stage=0,3 do
    game.save.gen3WeatherStage=stage;game.save.gen3WeatherDay=math.floor(os.time()/86400)
    game.save.gen3WeatherActive=value;world.rsWeather.map=nil;U.wait(180)
    local key=value==20 and'route119'or'route123';local expected=spec.cycles[key][stage+1]
    assert(engine.getCurrentWeather()==expected,'Wrong daily weather cycle')
    assert(world:battleWeather()==game.data.constants.gen3BattleWeather[world:weatherName(expected)],
      'Battle weather disagrees with the daily field cycle')
    report.cycles[#report.cycles+1]={route=value,stage=stage,weather=expected}
  end end
  report.cases.dailyCyclesAndBattleWeather=true
  game.save.gen3WeatherActive=7;world.rsWeather.map=nil;U.wait(90)
  local before=engine.state.ashOffsetY
  game.input:overlayPressed('left');U.wait(16);game.input:overlayReleased('left');U.wait(16)
  assert(engine.state.ashOffsetY~=before,'Native ash did not animate while walking')
  shot('native-ash-camera-scroll');report.cases.nativeAnimationAndCamera=true
  local frames=engine.state.frames
  game.stack:push(require('src.render.TextBox').new(game,'Ash falls.\nThe dialog stays clear.'));U.wait(90)
  assert(engine.state.frames>frames,'Dialogue stopped the native weather task')
  shot('native-ash-under-dialogue');game.stack:pop();U.wait(10)
  report.cases.dialogueLayering=true
  U.teleport(game,'MAP_G19_N01',6,7,'up');U.wait(180)
  assert(game.overworld.rsWeather.engine.getCurrentWeather()==W.translate(game.overworld.map.def.weather,
    game.overworld:gen3WeatherStage(),spec),'Indoor map retained outside ash')
  shot('indoor-weather-cleared');report.cases.mapTransitionClearsWeather=true
  report.status='pass';persist();print('PASS_RS_NATIVE_WEATHER');love.event.quit(0)
end
