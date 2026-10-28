-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared team; real GameClear special, induction, credits and continuation.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local edition=require('src.core.GameVersion').get();assert(edition=='ruby' or edition=='sapphire')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'} do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  local P=require('src.pokemon.Pokemon')
  game.save.player.gender=edition=='ruby'and'girl'or'boy'
  game.save.party={}
  for _,species in ipairs{'SCEPTILE','KYOGRE','WINGULL','CASTFORM','KECLEON','TENTACOOL'}do
    game.save.party[#game.save.party+1]=P.new(game.data,species,45)
  end
  game.save.pokedex={seen={TREECKO=true,SCEPTILE=true,KYOGRE=true},caught={TREECKO=true,SCEPTILE=true,KYOGRE=true}}
  require('src.core.SaveData').validate(game.save,game.data)
  for _,mon in ipairs(game.save.party) do require('src.battle.BattleState').stampOT(game.save,mon) end
  U.teleport(game,'MAP_G15_N00',8,20,'up');U.wait(90)
  local Hof=require('src.ui.Gen3HallOfFame');local Credits=require('src.ui.Gen3Credits')
  assert(Hof.record(game).text.name=='NAME /','Original RS Hall of Fame label missing')
  assert(#Credits.record(game).pages==52,'Original RS credit page table missing')
  local report={status='running',edition=edition,preparedFixture=true,continuousStory=false,
    creditPages=52,captures={}}
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
  local ow=game.overworld
  ow.runner:run({{'g3_special',275},{'g3_wait_state'},{'set_flag','QA_RS_ENDING_FINISHED'}},{mapId=ow.map.id})
  U.wait(8)
  local screen=game.stack:top()
  assert(getmetatable(screen)==require('src.ui.Gen3RsHallOfFame'))
  assert(ow.runner:isRunning() and not game.save.flags.QA_RS_ENDING_FINISHED)
  local mons,confetti={},false
  for _=1,6000 do
    assert(game.stack:top()==screen,'Ceremony ended before the native final question')
    if screen.phase=='hold'and not mons[screen.index]then
      assert(screen.scene.getCurrentMon()._hostMon==game.save.party[screen.index],'Native ceremony changed party identity/order')
      shot('native-rs-hall-pokemon-'..screen.index);mons[screen.index]=true
    elseif screen.phase=='applause'and not confetti and#screen.scene._confetti>=20 then
      shot('native-rs-hall-team-and-confetti');confetti=true
    elseif screen.phase=='exitwait'then
      local C=screen.load('src.core.game3.constants').of()
      local pic=C:require('trainer_classes',edition=='ruby'and'TRAINER_PIC_MAY'or'TRAINER_PIC_BRENDAN')
      assert(screen.scene._player.pic==pic,'Native ceremony selected the wrong player portrait')
      shot('native-rs-hall-player-original-label');break
    end
    U.wait(1)
  end
  assert(screen.phase=='exitwait'and confetti,'Native confetti/player ceremony did not complete')
  for i=1,6 do assert(mons[i],'Missing native ceremony party member '..i)end
  assert(require('src.core.Music').current()==game.data.audio.special.hallOfFame,'Wrong Hall of Fame song')
  press('a')
  for _=1,1200 do if game.stack:top()~=screen then break end;U.wait(1)end
  local credits=game.stack:top();assert(getmetatable(credits)==require('src.ui.Gen3RsCredits'))
  assert(require('src.core.Music').current()==game.data.audio.special.credits,'Wrong RS credits song')
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
        shot('native-rs-credits-bike-scene-'..scene);scenes[scene]=true
      elseif state.showMons and not monShot and state.mons[1]and state.mons[1].scale==256 then
        shot('native-rs-credits-caught-pokemon');monShot=true
      end
    end
    if state.mainFunc=='end6'and state.endDelay<6800 and not state.m.ppu.palette:fadeActive()then
      local song=game.data.constants.gen3RsPresentation.songIds.MUS_END
      assert(require('src.core.Music').current()==('SONG_%03X'):format(song),'THE END did not play its own native song')
      shot('native-rs-credits-the-end');break
    end
    U.wait(1)
  end
  assert(state.mainFunc=='end6','Native credits never reached THE END')
  for page=1,52 do assert(pages[page],'Missing native credits page '..page)end
  for scene=0,4 do assert(scenes[scene],'Missing original bike scene '..scene)end
  assert(monShot and state.imgCounter==68,'Native caught-Pokemon slide program did not complete')
  press('a')
  for _=1,1200 do if credits.closed then break end;U.wait(1)end
  assert(credits.closed and state.mainFunc=='done','Native ending input did not finish exactly once')
  for _=1,600 do
    if game.save.flags.QA_RS_ENDING_FINISHED then break end
    local top=game.stack:top()
    if top~=ow then press('b')else U.wait(1)end
  end
  assert(game.save.flags.QA_RS_ENDING_FINISHED,'GameClear callback did not resume its script')
  assert(game.save.hallOfFame==1,'Induction must be recorded once')
  report.status='pass';report.actualGameClearSpecial=true;report.fullImportedCreditRoll=true
  report.nativeHallPartyMembers=6;report.nativeHallConfetti=true;report.nativePlayerPortrait=true
  report.playerGender=game.save.player.gender
  report.nativeBikeScenes=5;report.nativeMonSlides=state.imgCounter;report.nativeTheEndAndMusic=true
  report.drawPreservesSaveRng=true;persist();print('PASS_NATIVE_RS_ENDING');love.event.quit(0)
end
