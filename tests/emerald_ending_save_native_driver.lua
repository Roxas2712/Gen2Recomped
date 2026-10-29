-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared team; failed writes, automatic League save, full ending and actual CONTINUE.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local edition=require('src.core.GameVersion').get();assert(edition=='emerald')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'} do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  local P=require('src.pokemon.Pokemon')
  game.save.player.gender='girl'
  game.save.party={}
  for _,species in ipairs{'SCEPTILE','KYOGRE','WINGULL','CASTFORM','KECLEON','TENTACOOL'}do
    game.save.party[#game.save.party+1]=P.new(game.data,species,45)
  end
  game.save.pokedex={seen={TREECKO=true,SCEPTILE=true,KYOGRE=true},caught={TREECKO=true,SCEPTILE=true,KYOGRE=true}}
  require('src.core.SaveData').validate(game.save,game.data)
  for _,mon in ipairs(game.save.party) do require('src.battle.BattleState').stampOT(game.save,mon) end
  U.teleport(game,'MAP_G15_N00',8,20,'up');U.wait(90)
  local Hof=require('src.ui.Gen3HallOfFame');local Credits=require('src.ui.Gen3Credits')
  assert(#Credits.record(game).pages==57,'Original Emerald credit page table missing')
  local report={status='running',edition=edition,preparedFixture=true,continuousStory=false,
    creditPages=57,captures={}}
  local function persist()
    local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()
  end
  local function shot(name)
    local S=require('src.core.SaveSerializer');local before=S.encode(game.save);local rng=love.math.getRandomState()
    local top=game.stack:top();assert(require('src.render.GraphicsScope').call(top.draw,top))
    assert(before==S.encode(game.save) and rng==love.math.getRandomState(),'Ending draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function press(key)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(8)
  end
  local IO=require('src.core.SaveData');local Save=require('src.core.SaveSerializer')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  local function disk()return love.filesystem.read(IO.saveFilename(edition))end
  assert(game:writeSave()==true);local original=disk();assert(original)
  local actualWrite=game.writeSave;local mode='false';local attempts=0
  local Sound=require('src.core.Sound');local play=Sound.playId;local saveSounds=0;local applauseSounds=0
  local saveSe=game.data.constants.gen3EmeraldPresentation.songIds.SE_SAVE
  local applauseSe=assert(game.data.constants.gen3EmeraldPresentation.songIds.SE_APPLAUSE)
  Sound.playId=function(data,id,...)
    if id==saveSe then saveSounds=saveSounds+1 end
    local source=play(data,id,...)
    if id==applauseSe then assert(source,'Native Hall applause did not create audio');applauseSounds=applauseSounds+1 end
    return source
  end
  game.writeSave=function(g)
    local hall=g.stack:top();assert(hall.savingDrawn and hall.saveEnding,'League IO preceded rendered saving')
    attempts=attempts+1
    if mode=='false'then return false elseif mode=='error'then error('Prepared League IO failure')end
    return actualWrite(g)
  end
  local ow=game.overworld
  ow.runner:run({{'g3_special',275},{'g3_wait_state'},{'set_flag','QA_EMERALD_ENDING_FINISHED'}},{mapId=ow.map.id})
  U.wait(8)
  local screen=game.stack:top()
  assert(getmetatable(screen)==require('src.ui.Gen3EmeraldHallOfFame'))
  assert(ow.runner:isRunning() and not game.save.flags.QA_EMERALD_ENDING_FINISHED)
  local update=screen.update;local savingPath=out..'/native-emerald-league-saving-message.png';local armed=false
  screen.update=function(self,dt)
    if self.scene.phase()=='trysave'then
      local f=io.open(savingPath,'rb')
      if f then f:close();self.update=update
      else
        if not armed then
          armed=true;game.capturePath=savingPath
          report.captures[#report.captures+1]='native-emerald-league-saving-message';persist()
        end
        return
      end
    end
    return update(self,dt)
  end
  local mons,confetti={},false
  local failures={}
  for _=1,6000 do
    assert(game.stack:top()==screen,'Ceremony ended before the native final question')
    if screen.saveFailure and screen.failureDrawn and not failures[mode]then
      assert(disk()==original and saveSounds==0,'Failed League write changed durable bytes or played save fanfare')
      assert(screen.scene.phase()=='savewait','Failed write advanced the ceremony')
      shot('native-emerald-league-write-'..mode..'-failure');failures[mode]=true
      mode=mode=='false'and'error'or'actual';press('a')
    elseif screen.phase=='hold'and not mons[screen.index]then
      assert(screen.scene.getCurrentMon()._hostMon==game.save.party[screen.index],'Native ceremony changed party identity/order')
      shot('native-emerald-hall-pokemon-'..screen.index);mons[screen.index]=true
    elseif screen.phase=='applause'and not confetti and#screen.scene._confetti>=20 then
      shot('native-emerald-hall-team-and-confetti');confetti=true
    elseif screen.phase=='exitwait'then
      local C=screen.load('src.core.game3.constants').of()
      local pic=C:require('trainer_classes','TRAINER_PIC_MAY')
      assert(screen.scene._player.pic==pic,'Native ceremony selected the wrong player portrait')
      shot('native-emerald-hall-player-original-label');break
    end
    U.wait(1)
  end
  assert(failures['false']and failures.error and attempts==3 and saveSounds==1 and screen.saved)
  local durable=assert(Save.decode(assert(disk())))
  assert(IO.hasChampionSaveWarp(durable))
  assert(durable.hallOfFame==1 and durable.gen3Stats[10]==1,'Automatic save duplicated induction')
  assert(type(durable.gen3HallOfFameTeams)=='table'and#durable.gen3HallOfFameTeams==1,'League retries duplicated or discarded the Hall team')
  assert(#durable.gen3HallOfFameTeams[1]==6,'Actual Hall record did not retain all six team members')
  assert(screen.phase=='exitwait'and confetti,'Native confetti/player ceremony did not complete')
  for i=1,6 do assert(mons[i],'Missing native ceremony party member '..i)end
  assert(require('src.core.Music').current()==game.data.audio.special.hallOfFame,'Wrong Hall of Fame song')
  press('a')
  for _=1,1200 do if game.stack:top()~=screen then break end;U.wait(1)end
  local credits=game.stack:top();assert(getmetatable(credits)==require('src.ui.Gen3EmeraldCredits'))
  assert(require('src.core.Music').current()==game.data.audio.special.credits,'Wrong Emerald credits song')
  local state=credits.state;local man=state.m:manifest('data/generated/gba/credits_rse/manifest.lua')
  local pageOf={};for i,p in ipairs(man.pages)do pageOf[p]=i end
  local pages,scenes,monShot={},{},false
  for _=1,40000 do
    assert(game.stack:top()==credits,'Credits finished before the native THE END screen')
    if state.text then pages[assert(pageOf[state.text])]=true end
    local task=state.m.tasks:get(state.mainId)
    local scene=task and task.data[7]
    if not state.m.ppu.palette:fadeActive()and state.text and state.mainFunc=='main'then
      if not state.showMons and not scenes[scene]then
        shot('native-emerald-credits-bike-scene-'..scene);scenes[scene]=true
      elseif state.showMons and not monShot and state.mons[1]and state.mons[1].scale==256 then
        shot('native-emerald-credits-caught-pokemon');monShot=true
      end
    end
    if state.mainFunc=='end6'and state.endDelay<6800 and not state.m.ppu.palette:fadeActive()then
      local song=game.data.constants.gen3EmeraldPresentation.songIds.MUS_END
      assert(require('src.core.Music').current()==('SONG_%03X'):format(song),'THE END did not play its own native song')
      shot('native-emerald-credits-the-end');break
    end
    U.wait(1)
  end
  assert(state.mainFunc=='end6','Native credits never reached THE END')
  for page=1,57 do assert(pages[page],'Missing native credits page '..page)end
  for scene=0,4 do assert(scenes[scene],'Missing original bike scene '..scene)end
  assert(monShot and state.imgCounter==71,'Native caught-Pokemon slide program did not complete')
  press('a')
  for _=1,1200 do if credits.closed then break end;U.wait(1)end
  assert(credits.closed and state.mainFunc=='done','Native ending input did not finish exactly once')
  assert(not ow.runner:isRunning()and not game.save.flags.QA_EMERALD_ENDING_FINISHED,'Old League script continued behind title')
  assert(game.stack:top().screenId=='TitleState','THE END did not return to title')
  local title=game.stack:top()
  for _=1,2400 do if title.scene.phase=='phase3'then break end;U.wait(1)end
  assert(title.scene.phase=='phase3','Native title never became ready for START')
  shot('native-emerald-after-league-title');press('start')
  for _=1,1200 do
    if getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu')then break end
    U.wait(1)
  end
  local menu=game.stack:top();assert(getmetatable(menu)==require('src.ui.Gen3MainMenu'))
  assert(menu.rsNative,'Ending must return through the original Emerald common menu')
  assert(menu.items[menu.index].key=='continue','Automatic League save did not offer CONTINUE')
  U.wait(90);shot('native-emerald-league-continue-menu')
  local leagueSave=game.save;press('a')
  if game.stack:top()==menu and menu.info then
    assert(game.save==leagueSave,'Continue preview adopted the save before confirmation')
    assert(Save.encode(menu.info.party)==Save.encode(durable.party),'Host Continue preview changed the party')
    shot('native-emerald-league-continue-preview');press('a')
  end
  for _=1,1200 do
    if game.stack:top()==game.overworld and game.save~=leagueSave then break end
    U.wait(1)
  end
  assert(game.stack:top()==game.overworld and game.save~=leagueSave,'Actual CONTINUE did not load the durable save')
  local home=assert(require('src.core.Gen3EmeraldEndingSave').home(game.data,game.save))
  local player=game.save.player
  assert(player.map==home.map and player.x==home.x and player.y==home.y,'CONTINUE missed native bedroom')
  assert(not IO.hasChampionSaveWarp(game.save))
  assert(Save.encode(game.save.party)==Save.encode(durable.party),'CONTINUE changed champion party')
  assert(game.save.hallOfFame==1 and game.save.gen3Stats[10]==1)
  assert(Save.encode(game.save.gen3HallOfFameTeams)==Save.encode(durable.gen3HallOfFameTeams),'Actual CONTINUE changed compact Hall history')
  assert(disk()and IO.hasChampionSaveWarp(Save.decode(disk())),'CONTINUE rewrote durable League snapshot')
  shot('native-emerald-league-continue-bedroom')
  game.writeSave=actualWrite;Sound.playId=play
  report.automaticLeagueSave=true;report.failedWritesPreserveDisk=true;report.writeAttempts=attempts
  report.saveSounds=saveSounds;report.nativeTitleAndHostContinue=true;report.correctGenderBedroom=true
  assert(applauseSounds==1,'Original Hall applause must play once')
  report.nativeApplauseSounds=applauseSounds;report.originalMainMenuDirectContinue=true
  report.status='pass';report.actualGameClearSpecial=true;report.fullImportedCreditRoll=true
  report.nativeHallPartyMembers=6;report.nativeHallConfetti=true;report.nativePlayerPortrait=true
  report.playerGender=game.save.player.gender
  report.nativeBikeScenes=5;report.nativeMonSlides=state.imgCounter;report.nativeTheEndAndMusic=true
  report.drawPreservesSaveRng=true;persist();print('PASS_NATIVE_EMERALD_LEAGUE_SAVE_TITLE_CONTINUE');love.event.quit(0)
end
