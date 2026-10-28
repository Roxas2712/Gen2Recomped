-- Prepared native ride fixtures; no ordinary story progress is claimed.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local Native=require('src.ui.Gen3RsCableCar')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(edition=='ruby'or edition=='sapphire')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(Native.available(game)and require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game);U.teleport(game,'MAP_G19_N00',6,7,'up');U.wait(90)
  local world=game.overworld
  local report={edition=edition,status='running',preparedCableCarFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,callbacks=0,rides={},audio={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local scriptedMove=world.scriptMove
  world.scriptMove=function(self,entity,dir,tiles,...)
    report.moveTrace=report.moveTrace or{}
    report.moveTrace[#report.moveTrace+1]={map=self.map.id,entity=entity.id or'player',
      x=entity.cellX,y=entity.cellY,dir=dir,tiles=tiles,moving=entity.moving}
    return scriptedMove(self,entity,dir,tiles,...)
  end
  local function shot(name)
    local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(bytes==Save.encode(game.save)and rng==love.math.getRandomState(),'Cable-car draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function waitFor(fn,n,why)
    for _=1,n do if fn()then return end;U.wait(1)end;error(why or'Native ride timeout')
  end
  local function press(key)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(12)
  end
  local function stableSave()
    local copy={};for k,v in pairs(game.save)do if k~='playTime'then copy[k]=v end end
    return Save.encode(copy)
  end
  local id=assert(game.data.constants.gen3RsPresentation.songIds.MUS_CABLE_CAR)
  local label=('SONG_%03X'):format(id);local music=require('src.core.Music');local play=music.play
  music.play=function(data,key,...)
    local source=play(data,key,...)
    if data==game.data and key==label then
      assert(music.current()==label,'Native cable-car music did not play')
      report.audio.plays=(report.audio.plays or 0)+1
    end
    return source
  end
  local engine=require('src.core.M4ASynth').newEngine(game.data,assert(game.data.audio.songs[label]),{allowLoops=false})
  local signal=false;for _=1,88200 do local l,r=engine:sampleStereo();if l~=0 or r~=0 then signal=true;break end end
  assert(signal,'Silent native cable-car PCM');report.audio.index=id;report.audio.nonzeroPCM=true
  report.cases.nativeAssetsAndMusic=true
  for _,gender in ipairs({'boy','girl'})do for _,down in ipairs({false,true})do
    game.save.player.gender=gender
    local prefix=gender..(down and'-down'or'-up');local saveBefore=stableSave()
    local screen=Native.new(game,{goingDown=down,onDone=function(release)
      report.callbacks=report.callbacks+1;release()
    end})
    -- Exercise the original rare passer-by branch in the prepared fixture.
    screen.scene.random=function()return down and 0x2000 or 0 end
    local scene=screen.scene;game.stack:push(screen)
    waitFor(function()return scene.frames>=150 end,300);shot(prefix..'-native-car-and-rider')
    assert(world.map.id=='MAP_G19_N00','A view-only fixture must not warp')
    -- The cartridge ride has no A/B shortcut.
    press('a');press('b');assert(game.stack:top()==screen and not scene.done)
    waitFor(function()return scene.frames>=420 end,400);shot(prefix..'-weather-and-parallax')
    waitFor(function()return scene.frames>=590 end,250);shot(prefix..'-native-fade-out')
    waitFor(function()return game.stack:top()==world end,200)
    assert(scene.done and stableSave()==saveBefore,'Native ride changed unrelated save fields')
    local events={};for _,row in ipairs(scene.log)do events[row.what]=row.frame end
    assert(events.fade_in and events.weather and events.fade_out and events['end'])
    report.rides[prefix]={frames=scene.frames,events=events,goingDown=down,female=scene.female}
    report.cases[prefix]=true;persist()
  end end
  local function prompt(map)
    -- The actual arrival already ran its map-entry walk. Reloading that map
    -- here would repeat the entry script from a different starting square.
    assert(game.overworld.map.id==map,'Station fixture lost the actual arrival')
    world=game.overworld;U.wait(30)
    assert(world.player.cellX==6 and world.player.cellY==7,'Unexpected station return square')
    report.promptState={map=map,x=world.player.cellX,y=world.player.cellY,facing=world.player.facing,entities={}}
    for _,e in ipairs(world.entities or{})do report.promptState.entities[#report.promptState.entities+1]={
      id=e.id,x=e.cellX,y=e.cellY,passable=e.passable,moving=e.moving,localId=e.def and e.def.localId}
    end
    persist()
    press('up');press('a')
    for _=1,150 do
      if game.stack:top().screenId=='Gen3RsChoice'then return end
      press('a')
    end
    local top=game.stack:top();report.failedPrompt={screenId=top.screenId,phase=top.phase,
      x=world.player.cellX,y=world.player.cellY,facing=world.player.facing,pages=top.pages};persist()
    error('Station script did not offer its native YES/NO')
  end
  local function freeField()
    return game.stack:top()==world and not world.player.moving and not world.player.inputLocked
      and not(world.runner and world.runner:isRunning())
      and world.player.cellX==6 and world.player.cellY==7
  end
  for _,row in ipairs({{'MAP_G19_N00','MAP_G19_N01','up'},{'MAP_G19_N01','MAP_G19_N00','down'}})do
    prompt(row[1]);press('b')
    for _=1,100 do if freeField()then break end;press('b')end
    assert(freeField()and world.map.id==row[1]);shot('station-'..row[3]..'-cancel')
    report.cases[row[3]..'CancelStaysAtStation']=true
    prompt(row[1]);press('a')
    for _=1,150 do
      if getmetatable(game.stack:top())==Native then break end
      press('a')
    end
    local screen=game.stack:top();assert(getmetatable(screen)==Native,'Actual station bypassed its ride')
    local scene=screen.scene;assert(scene.goingDown==(row[3]=='down'))
    waitFor(function()return scene.frames>=240 end,350);shot('station-'..row[3]..'-actual-ride')
    assert(world.map.id==row[1],'Station changed before the ride ended')
    waitFor(function()return freeField()and world.map.id==row[2]end,1800,'Actual station ride did not return control')
    local npc=assert(world:npcByIndex(1));local home=assert(game.save.gen3ObjectHomes[world.map.id][1])
    assert(npc.cellX==6 and npc.cellY==6 and home.x==6 and home.y==7,
      'Arrival must keep the live NPC apart from the player and only write the return template')
    assert(scene.done);shot('station-'..row[3]..'-actual-arrival')
    report.rides['station-'..row[3]]={frames=scene.frames,map=world.map.id,x=world.player.cellX,y=world.player.cellY,
      npcX=npc.cellX,npcY=npc.cellY,homeX=home.x,homeY=home.y}
    report.cases[row[3]..'ActualScriptRidesAndArrives']=true;persist()
  end
  assert(report.callbacks==4 and report.audio.plays==6)
  report.status='pass';persist();print('PASS_RS_NATIVE_CABLE_CAR');love.event.quit(0)
end
