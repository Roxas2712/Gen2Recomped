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
  game.save.party={P.new(game.data,'SCEPTILE',49),P.new(game.data,'KYOGRE',45)}
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
  assert(getmetatable(screen)==Hof and screen.phase=='mon' and screen.index==1)
  assert(ow.runner:isRunning() and not game.save.flags.QA_RS_ENDING_FINISHED)
  assert(require('src.core.Music').current()==game.data.audio.special.hallOfFame,'Wrong Hall of Fame song')
  shot('native-rs-hall-first-pokemon');press('a')
  assert(screen.index==2);shot('native-rs-hall-second-pokemon');press('a')
  assert(screen.phase=='player');shot('native-rs-hall-player-original-label');press('a')
  assert(screen.phase=='welcome');shot('native-rs-hall-welcome');press('a')
  local credits=game.stack:top();assert(getmetatable(credits)==Credits)
  assert(require('src.core.Music').current()==game.data.audio.special.credits,'Wrong RS credits song')
  U.wait(90);shot('native-rs-credits-first-page')
  U.wait(4500);assert(game.stack:top()==credits);shot('native-rs-credits-middle-page')
  U.wait(5200)
  assert(credits.done,'Complete imported credits roll did not finish')
  for _=1,600 do
    if game.save.flags.QA_RS_ENDING_FINISHED then break end
    local top=game.stack:top()
    if top~=ow then press('b')else U.wait(1)end
  end
  assert(game.save.flags.QA_RS_ENDING_FINISHED,'GameClear callback did not resume its script')
  assert(game.save.hallOfFame==1,'Induction must be recorded once')
  report.status='pass';report.actualGameClearSpecial=true;report.fullImportedCreditRoll=true
  report.drawPreservesSaveRng=true;persist();print('PASS_NATIVE_RS_ENDING');love.event.quit(0)
end
