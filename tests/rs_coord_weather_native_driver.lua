-- Prepared real-ROM coordinate-weather steps and native SAVE/CONTINUE.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local W=require('src.world.Gen3RsWeather')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(edition=='ruby'or edition=='sapphire'or edition=='emerald')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(W.available(game)and require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game);U.teleport(game,'MAP_G00_N28',13,11,'right');U.wait(90)
  local world=game.overworld
  local report={edition=edition,status='running',preparedCoordWeatherFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,steps={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(bytes==Save.encode(game.save)and rng==love.math.getRandomState(),'Coordinate-weather draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 30)
  end
  local function untilTrue(fn,n,why)
    for _=1,n do if fn()then return end;U.wait(1)end;error(why)
  end
  local function step(dir)
    local p=world.player;local x,y=p.cellX,p.cellY
    local allowed,why=require('src.world.Collision').canMove(world.map,world.cast or world.entities,p,dir)
    report.beforeStep={x=x,y=y,elevation=p.elevation,inputLocked=p.inputLocked,transitioning=world.transitioning,
      engaging=world.engaging,emote=world.emote~=nil,runner=world.runner:isRunning(),pending=#world.pendingScripts,
      topIsWorld=game.stack:top()==world,collisionAllowed=allowed,collisionWhy=why}
    persist()
    game.input:overlayPressed(dir)
    untilTrue(function()return p.moving or p.cellX~=x or p.cellY~=y end,60,'Actual weather step did not start')
    game.input:overlayReleased(dir)
    untilTrue(function()return not p.moving end,90,'Actual weather step did not finish');U.wait(6)
    assert(game.stack:top()==world and not world.runner:isRunning(),'Weather claimed the script runner or opened UI')
    assert(p.cellX==x+(dir=='left'and-1 or dir=='right'and 1 or 0)and p.cellY==y,'Weather corridor left its row')
    report.steps[#report.steps+1]={x=p.cellX,y=p.cellY,saved=game.save.gen3Weather,active=game.save.gen3WeatherActive}
  end
  local ash,clear
  for _,a in ipairs(world.map.def.coordEvents or{})do for _,c in ipairs(world.map.def.coordEvents or{})do
    if not a.script and a.var==8 and not c.script and c.var==2 and a.y==c.y and a.x-c.x==5 then
      local open=true
      for x=c.x-1,a.x+1 do if not world.map:isWalkableCell(x,a.y)then open=false end end
      -- This weather-only fixture has no party. Use the parallel boundary
      -- row outside trainer sight, rather than suppressing trainer logic.
      for _,npc in ipairs(world.npcs or{})do
        if npc.def and npc.def.gen3Trainer and npc.cellY==a.y then open=false end
      end
      if open then ash,clear=a,c;break end
    end
  end;if ash then break end end
  assert(ash and clear,'Original Route113 has no accessible ash/clear corridor')
  U.teleport(game,'MAP_G00_N28',clear.x-1,ash.y,'right');U.wait(90);world=game.overworld
  local hooks=require('src.script.MapScripts').get(world.map.id)
  assert(not hooks or not hooks.onStep,'This fixture must exercise a map without a scripted coord hook')
  assert(world.map.def.weather==2 and game.save.gen3WeatherActive==2,'Route113 must begin with its sunny header')
  report.corridor={ash={x=ash.x,y=ash.y,trigger=ash.var},clear={x=clear.x,y=clear.y,trigger=clear.var}}
  shot('route113-original-sunny-header');report.cases.scriptlessMapHasIndependentDispatch=true
  while world.player.cellX<ash.x do step('right')end;U.wait(180)
  assert(game.save.gen3Weather==7 and game.save.gen3WeatherActive==7 and world.rsWeather.engine.snapshot().ash)
  shot('route113-actual-coordinate-ash');report.cases.actualStepStartsOriginalAsh=true
  local engine=world.rsWeather.engine;local frames=engine.state.frames
  assert(not W.coordinate(world,game),'The same coordinate row fired twice in one visit')
  world:checkCoordEventHere(true)
  assert(engine.state.frames==frames,'A coordinate recheck advanced the native weather task')
  report.cases.rechecksDoNotRepeatCoordinateWeather=true
  step('left');assert(world.player.cellX>clear.x)
  local Start=require('src.ui.Gen3StartMenu');local owner=Start.new(game)
  for i,row in ipairs(owner.rows)do if row.key=='save'then owner.index=i end end
  game.stack:push(owner);press('a');local screen=game.stack:top()
  if edition~='emerald'then assert(getmetatable(screen)==require('src.ui.Gen3RsSaveMenu')and screen.phase=='confirm')end
  if edition=='emerald'then
    assert(getmetatable(screen)==require('src.render.TextBox'),'Emerald save prompt must remain owned by its Start menu')
    -- Each A first finishes the currently printing page; the write and final
    -- saved-message callback must both complete before expecting the field.
    for _=1,40 do
      if game.stack:top()==world then break end
      press('a',30)
    end
    assert(game.stack:top()==world,'Original Emerald save flow did not close')
  else
    press('a');untilTrue(function()return game.stack:top()==world end,300,'Native coordinate-weather SAVE did not finish')
    assert(screen.wrote)
  end
  local IO=require('src.core.SaveData');local bytes=assert(love.filesystem.read(IO.saveFilename(edition)))
  local saved=assert(Save.decode(bytes))
  assert(saved.gen3Weather==7 and saved.gen3WeatherActive==7)
  report.saved={x=world.player.cellX,y=world.player.cellY,weather=7,sha256=love.data.encode('string','hex',love.data.hash('sha256',bytes))}
  shot('route113-native-save-inside-ash');report.cases.nativeSaveStoresCoordinateWeather=true
  while world.player.cellX>clear.x do step('left')end;U.wait(180)
  assert(game.save.gen3Weather==2 and game.save.gen3WeatherActive==2 and not engine.snapshot().ash)
  shot('route113-actual-coordinate-clear');report.cases.actualStepClearsOriginalAsh=true
  assert(love.filesystem.read(IO.saveFilename(edition))==bytes)
  local previousSave=game.save
  game:returnToTitle()
  untilTrue(function()local top=game.stack:top();return top and top.kind=='title'and top.scene.phase=='phase3'end,
    6000,'Native return to title timed out')
  press('start',100);assert(getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu'))
  local menu=game.stack:top();assert(menu.items[1].key=='continue')
  if menu.rsNative then
    untilTrue(function()return menu.rsNative.scene.state=='input'end,300,'Native Continue menu not ready')
    shot('route113-native-continue-summary');press('a',180)
  else
    press('a',30);assert(game.stack:top().info)
    shot('route113-native-continue-summary');press('a',180)
  end
  world=game.overworld
  assert(game.stack:top()==world and game.save~=previousSave)
  assert(world.map.id=='MAP_G00_N28'and world.player.cellX==report.saved.x and world.player.cellY==report.saved.y)
  assert(world.rsWeather.engine~=engine,'A continued game reused the previous weather task')
  assert(game.save.gen3Weather==7 and game.save.gen3WeatherActive==7 and world.rsWeather.engine.snapshot().ash,
    'CONTINUE replaced coordinate ash with the sunny map header')
  assert(love.filesystem.read(IO.saveFilename(edition))==bytes,'CONTINUE changed stored save bytes')
  shot('route113-native-continued-ash');report.cases.nativeContinueRestoresCoordinateWeather=true
  local Stats=require('src.pokemon.Gen3GameStats')
  local Commands=require('src.script.Commands')
  local ctx={game=game,save=game.save,overworld=world}
  local initialRain=Stats.get(game.save,Stats.GOT_RAINED_ON)
  Commands.g3_weather(ctx,3)
  assert(game.save.gen3Weather==3 and game.save.gen3WeatherActive==7,
    'Script weather activated before doweather')
  assert(Stats.get(game.save,40)==initialRain+1,'Original saved rain transition was not counted')
  report.cases.savedAndActiveWeatherRemainSeparate=true
  Commands.g3_do_weather(ctx)
  untilTrue(function()return world.rsWeather.engine.getCurrentWeather()==3 end,900,'Native rain transition did not finish')
  shot('native-scripted-rain-counted-once')
  Commands.g3_weather(ctx,3);U.wait(90)
  assert(Stats.get(game.save,40)==initialRain+1,'Repeated request or native rain animation counted twice')
  report.cases.originalSavedRainCountedOnce=true
  Commands.g3_weather(ctx,5)
  assert(game.save.gen3Weather==5 and game.save.gen3WeatherActive==3)
  assert(Stats.get(game.save,40)==initialRain+2,'Changed original thunderstorm was not counted')
  Commands.g3_do_weather(ctx)
  untilTrue(function()return world.rsWeather.engine.getCurrentWeather()==5 end,900,'Native thunderstorm transition did not finish')
  shot('native-scripted-thunderstorm-counted-once')
  report.cases.originalThunderstormCountedOnce=true
  Commands.g3_weather(ctx,13);Commands.g3_do_weather(ctx);U.wait(90)
  assert(Stats.get(game.save,40)==initialRain+2,'Heavy rain incorrectly gained the original rain statistic')
  report.cases.originalHeavyRainDoesNotCount=true
  U.teleport(game,'MAP_G19_N01',6,7,'up');U.wait(120)
  assert(game.overworld.map.def.weather==0 and game.save.gen3Weather==0 and game.save.gen3WeatherActive==0,
    'A different map boot inherited the previous map weather')
  assert(not game.overworld.rsWeather.engine.snapshot().ash)
  shot('different-map-keeps-own-weather-header');report.cases.differentMapEntryUsesOwnHeader=true
  assert(Stats.get(game.save,40)==initialRain+2,'Indoor header changed the rain statistic')
  assert(love.filesystem.read(IO.saveFilename(edition))==bytes,'Prepared weather transitions rewrote the saved file')
  report.rainStatistics={before=initialRain,after=Stats.get(game.save,40)}
  report.status='pass';persist();print('PASS_RS_NATIVE_COORD_WEATHER');love.event.quit(0)
end
