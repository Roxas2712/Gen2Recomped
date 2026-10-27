-- Actual imported FR/LG boot, audio, new game and save flow.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local V=require('src.core.GameVersion');local Music=require('src.core.Music')
  local Serialize=require('src.core.SaveSerializer');local Save=require('src.core.SaveData')
  local edition=V.get();local leaf=edition=='leafgreen'
  assert(V.isFRLG(edition) and love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'))
  -- Hidden SDL windows can receive desktop typing. Only this owned QA
  -- process ignores physical events; all test buttons use the overlay API.
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed',
    'gamepadreleased','joystickpressed','joystickreleased','joystickaxis','joystickhat',
    'touchpressed','touchreleased','touchmoved','mousepressed','mousereleased'})do
    love[event]=function()end
  end
  game.input:reset()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local report={status='running',edition=V.get(),captures={},phases={},audio={},fullStoryTested=false}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local screen=assert(game.stack:top());local saved=Serialize.encode(game.save);local rng=love.math.getRandomState()
    local ok,why=require('src.render.GraphicsScope').call(screen.draw,screen);assert(ok,why)
    assert(Serialize.encode(game.save)==saved,'LeafGreen draw changed save')
    assert(love.math.getRandomState()==rng,'LeafGreen draw consumed gameplay RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function waitTitle()
    for _=1,1400 do local s=game.stack:top();if s and s.phase=='run'then return end;U.wait(1)end
    error('Native title did not reach RUN')
  end
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 1)
  end
  persist()
  local boot=game.data.field.boot
  report.splash=boot.screens.splash;report.title=boot.screens.title;report.newGame=boot.screens.newGame
  shot('initial-screen')
  local ready=require('src.import.RomImporter').readyReport(edition)
  report.ready=ready;persist();assert(ready.ok,'Fresh LeafGreen import is not complete')
  assert(#(ready.gaps or {})==0,'LeafGreen still expects obsolete generic presentation files')
  assert(boot.screens.splash=='Gen3IntroFRLG','LeafGreen uses a generic intro fallback')
  assert(boot.screens.title=='Gen3TitleFRLG','LeafGreen uses a generic title fallback')
  assert(boot.screens.newGame=='Gen3OakSpeechFRLG','LeafGreen uses a generic professor speech')
  local title=assert(game.data.constants.gen3FRLGTitle)
  assert(title.effect==(leaf and'leaves'or'flames') and title.cry==(leaf and'VENUSAUR'or'CHARIZARD'))
  assert(game.data.pokemon[title.cry] and game.data.maps.MAP_G00_N00)
  local introClass=require('src.ui.Gen3IntroFRLG');local titleClass=require('src.ui.Gen3TitleFRLG')
  local seen,ages,captured={},{},{}
  local saveBefore=Serialize.encode(game.save);local oldSave=Serialize.decode(saveBefore)
  local step=game._step;local expected=game.save.playTime or 0;local clockSteps=0
  game._step=function(self,dt)
    local old=self.save.playTime or 0;local result=step(self,dt);local now=self.save.playTime or 0
    assert(now==old or now==old+dt,'Unexpected play-time mutation')
    if now==old+dt then expected=expected+dt;clockSteps=clockSteps+1 end
    return result
  end
  for _=1,10000 do
    local screen=assert(game.stack:top())
    if getmetatable(screen)==titleClass then break end
    assert(getmetatable(screen)==introClass,'Unexpected screen during LeafGreen movie')
    local phase=screen.phase
    if not seen[phase]then seen[phase]=true;report.phases[#report.phases+1]=phase end
    ages[phase]=(ages[phase]or 0)+1
    local cue=Music.current();if cue then report.audio[cue]=true end
    local at={card=50,gf=90,scene1=25,scene2=60,scene3=180}
    if at[phase]and ages[phase]>=at[phase]and not captured[phase]then captured[phase]=true;shot('intro-'..phase)end
    if phase=='gf'and screen.gf.cb=='logo'and screen.gf.state==4 and screen.gf.timer>=20 and not captured.gfLogo then
      captured.gfLogo=true;shot('game-freak-logo')
    end
    U.wait(1)
  end
  for _,phase in ipairs({'card','gf','scene1','scene2','scene3'})do assert(captured[phase],'Missing full intro phase '..phase)end
  assert(captured.gfLogo,'Native GAME FREAK logo was not captured')
  local screen=assert(game.stack:top());assert(getmetatable(screen)==titleClass,'Full movie did not reach title')
  waitTitle();assert(screen.phase=='run');assert(Music.current()=='SONG_116','LeafGreen title cue missing')
  assert(report.audio.SONG_141 and report.audio.SONG_115,'FR/LG movie must play both native cues');shot(leaf and'venusaur-title'or'charizard-title')
  local after=Serialize.decode(Serialize.encode(game.save));assert(game.save.playTime==expected)
  after.playTime=oldSave.playTime;assert(Serialize.encode(after)==saveBefore,'Movie mutated save beyond play time')
  game._step=step;report.nativeClockSteps=clockSteps
  local audio=game.data.audio
  for name,id in pairs({gameFreak='SONG_141',introFight='SONG_115',title='SONG_116',wild=audio.battle.wild,
      trainer=audio.battle.trainer,victory=audio.battle.trainerWin})do
    local def=assert(audio.songs[id],'Missing LeafGreen cue '..name)
    local engine=require('src.core.M4ASynth').newEngine(game.data,def,{allowLoops=false});local signal=false
    for _=1,88200 do local l,r=engine:sampleStereo();if l~=0 or r~=0 then signal=true;break end end
    assert(signal,'Silent LeafGreen PCM '..name);report.audio[name]={id=id,nonzeroPcm=true}
  end
  press('start',150);assert(getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu'))
  shot('main-menu');press('b',1);waitTitle()
  assert(getmetatable(game.stack:top())==titleClass and game.stack:top().phase=='run','B did not restore live title')
  assert(Music.current()=='SONG_116');shot('title-after-menu-cancel')
  press('start',150);local menu=game.stack:top();assert(getmetatable(menu)==require('src.ui.Gen3MainMenu'))
  for i,row in ipairs(menu.items)do if row.key=='newGame'then menu.index=i end end
  press('a',100);assert(getmetatable(game.stack:top())==require('src.ui.Gen3OakSpeechFRLG'))
  local speech=game.stack:top();shot('controls-guide')
  local oakSeen,pikaSeen=false,false
  for _=1,2500 do
    if game.overworld and game.stack:top()==game.overworld then break end
    if speech.phase=='pikachu'and speech.black==0 and not pikaSeen then pikaSeen=true;shot('pikachu-guide')end
    if speech.phase=='oak'and speech.pic=='oak'and speech.picAlpha==1 and speech.black==0 and not oakSeen then
      oakSeen=true;shot('oak-portrait')
    end
    press('a',2)
  end
  assert(oakSeen and pikaSeen,'Native new game skipped Pikachu/Oak presentation')
  local world=game.overworld;assert(world and game.stack:top()==world,'Oak/name flow did not reach field')
  U.wait(60);shot('new-game-field')
  local x,y=world.player.cellX,world.player.cellY;local moved=false
  for _,key in ipairs({'down','left','right','up'})do
    game.input:overlayPressed(key);U.wait(30);game.input:overlayReleased(key);U.wait(20)
    if x~=world.player.cellX or y~=world.player.cellY then moved=true;break end
  end
  assert(moved,'Fresh LeafGreen field movement is blocked');shot('field-after-movement')
  assert(Save.save(game.save,game.mods));assert(Save.saveFileExists(edition))
  assert(not Save.saveFileExists(leaf and'firered'or'leafgreen'),'FR/LG wrote the other edition save')
  local loaded=assert(Save.load(edition))
  assert(loaded.version==edition and loaded.player.name==game.save.player.name)
  report.startMap=world.map.id;report.playerName=game.save.player.name
  local savedX,savedY=game.save.player.x,game.save.player.y
  game:returnToTitle();waitTitle();assert(getmetatable(game.stack:top())==titleClass)
  press('start',150);menu=game.stack:top();assert(getmetatable(menu)==require('src.ui.Gen3MainMenu'))
  local found=false;for i,row in ipairs(menu.items)do if row.key=='continue'then menu.index=i;found=true end end
  assert(found,'Saved LeafGreen game has no CONTINUE row');shot('continue-panel');press('a',120)
  assert(game.overworld and game.stack:top()==game.overworld,'CONTINUE did not restore field')
  assert(game.save.player.name==loaded.player.name and game.overworld.map.id==report.startMap)
  assert(game.overworld.player.cellX==savedX and game.overworld.player.cellY==savedY,'CONTINUE lost saved coordinates')
  shot('continued-field');report.continueThroughTitle=true
  report.fullIntro=true;report.nativeTitleAssets=true;report.nativeTitleController=true;report.menuCancelAndReentry=true
  report.newGame=true;report.movement=true;report.saveReload=true;report.drawSaveAndRngImmutable=true
  report.status='pass';persist();print('PASS_FRLG_EXPERIENCE_BOOT '..edition);love.event.quit(0)
end
