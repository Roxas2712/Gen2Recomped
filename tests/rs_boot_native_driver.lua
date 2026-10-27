-- Real import/renderer/audio lifecycle. This never bypasses native scene ticks.
return function(game)
  local helper=os.getenv('RS_BOOT_QA_HELPERS')
  local U = helper and assert(loadfile(helper))() or require('tests.drivers.util')
  local V = require('src.core.GameVersion')
  local Music = require('src.core.Music')
  local Json = require('src.link.Json')
  local version = V.get()
  assert(version == 'ruby' or version == 'sapphire')
  local spec = assert(game.data.constants.gen3RsPresentation)
  assert(spec.version == version)
  assert(game.data.field.boot.screens.splash == 'Gen3RsIntro')
  assert(game.data.field.boot.screens.title == 'Gen3RsTitle')
  local root = assert(os.getenv('RS_BOOT_QA_OUT')or os.getenv('EDITION_QA_OUT'))
  local report = {edition=version, phases={}, audio={}, captures={}, status='running'}
  local function persist()
    local f = assert(io.open(root..'/result.json','w'))
    f:write(Json.encode(report));f:close()
  end
  local scene = assert(game.stack:top())
  assert(scene.kind == 'intro')
  scene.scene.rng.SeedRng(0)
  local Serializer=require('src.core.SaveSerializer')
  local saveBefore = Serializer.encode(game.save)
  local before=Serializer.decode(saveBefore)
  local nativeStep=game._step
  local expectedClock=game.save.playTime or 0
  local clockSteps=0
  game._step=function(self,dt)
    local old=self.save.playTime or 0
    local r=nativeStep(self,dt)
    local now=self.save.playTime or 0
    assert(now==old or now==old+dt,'Unexpected play-time mutation')
    if now==old+dt then expectedClock=expectedClock+dt;clockSteps=clockSteps+1 end
    return r
  end
  local heard, captures = {}, {}
  for tick=1,6000 do
    local top = game.stack:top()
    if top and top.kind == 'title' then break end
    assert(top and top.kind == 'intro', 'Unexpected state during RS movie')
    local phase = top.scene.phase
    if not heard[phase] then
      heard[phase]=true;report.phases[#report.phases+1]=phase
    end
    local cue = Music.current()
    if cue then report.audio[cue]=true end
    if (phase == 'scene1' and top.scene.counter == 620)
      or (phase == 'scene2' and top.scene.counter == 1400)
      or (phase == 'scene3' and top.scene.counter == 600) then
      if not captures[phase] then
        captures[phase]=true
        local snap=top.scene:snapshot();snap:encode('png',version..'-'..phase..'-native.png');snap:release()
        assert(U.shot(game,root..'/'..version..'-'..phase..'-window.png'))
        report.captures[#report.captures+1]=phase
      end
    end
    U.wait(1)
    if tick%120==0 then persist() end
  end
  local title=assert(game.stack:top())
  assert(title.kind == 'title','Full native intro did not reach title')
  for _=1,1000 do
    if title.scene.phase=='phase3' then break end
    U.wait(1)
  end
  assert(title.scene.phase=='phase3','Native title did not finish its entrance')
  assert(title.scene.man.legendary==(version=='sapphire' and 'kyogre' or 'groudon'))
  assert(Music.current()==('SONG_%03X'):format(spec.songIds.MUS_TITLE),'Title music missing')
  report.audio[Music.current()]=true
  assert(report.audio[('SONG_%03X'):format(spec.songIds.MUS_INTRO)],'Intro music missing')
  assert(report.audio[('SONG_%03X'):format(spec.songIds.MUS_INTRO_BATTLE)],'Intro battle music missing')
  local snap=title.scene:snapshot();snap:encode('png',version..'-title-native.png');snap:release()
  assert(U.shot(game,root..'/'..version..'-title-window.png'))
  report.captures[#report.captures+1]='title'
  local after=Serializer.decode(Serializer.encode(game.save))
  assert(game.save.playTime==expectedClock,'Native play clock lost ticks')
  report.nativeClockSteps=clockSteps;report.nativeClockSeconds=expectedClock-(before.playTime or 0)
  after.playTime=before.playTime
  assert(Serializer.encode(after)==saveBefore,'Movie changed save state beyond native play time')
  for _,name in ipairs({'MUS_INTRO','MUS_INTRO_BATTLE','MUS_TITLE','MUS_VS_WILD','MUS_VICTORY_WILD'}) do
    local def=assert(game.data.audio.songs[('SONG_%03X'):format(assert(spec.songIds[name]))])
    local engine=require('src.core.M4ASynth').newEngine(game.data,def,{allowLoops=false})
    local signal=false
    for _=1,44100 do local l,r=engine:sampleStereo();if l~=0 or r~=0 then signal=true;break end end
    assert(signal,'Imported song has no audible PCM: '..name)
    report.audio[name]='nonzero PCM'
  end
  U.tap(game,'start');U.wait(100)
  assert(getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu'),'Start did not open menu')
  U.tap(game,'b');U.wait(30)
  assert(game.stack:top().kind=='title','B did not restore a live native title')
  for _=1,1000 do
    if game.stack:top().scene.phase=='phase3' then break end
    U.wait(1)
  end
  assert(game.stack:top().scene.phase=='phase3','Restored title entrance did not complete')
  U.tap(game,'start');U.wait(100)
  assert(getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu'),'Second title entry lost input')
  report.fullIntro=true;report.nativeTitle=true;report.realMenuInput=true
  report.menuCancelAndReentry=true
  report.saveUnchanged=true;report.status='pass';persist()
  game._step=nativeStep
  print('[rs-boot] PASS '..version..' native intro/title/audio/menu')
  love.event.quit(0)
end
