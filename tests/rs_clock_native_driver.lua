-- Prepared original clock input/render fixtures, separate from story progress.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local Host=require('src.ui.Gen3WallClock')
  local Native=require('src.ui.Gen3RsWallClock');local edition=require('src.core.GameVersion').get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(Native.available(game)and require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game);U.teleport(game,'MAP_G00_N11',11,9,'right');U.wait(90)
  local world=game.stack:top()
  local report={edition=edition,status='running',preparedClockFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,callbacks=0,normalPlayTimeExcluded=true}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(bytes==Save.encode(game.save)and rng==love.math.getRandomState(),'Clock draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function press(key)
    game.input:overlayPressed(key);U.wait(3);game.input:overlayReleased(key);U.wait(4)
  end
  local function otherSave()
    local copy={};for k,v in pairs(game.save)do if k~='gen3Clock'and k~='playTime'then copy[k]=v end end
    return Save.encode(copy)
  end
  for _,gender in ipairs({'boy','girl'})do
    game.save.player.gender=gender
    game.save.gen3Clock={hour=23,minute=59,setAt=os.time()}
    local original=Save.encode(game.save.gen3Clock);local unrelated=otherSave()
    local screen=Host.new(game,{view=true,onDone=function(h,m)
      assert(h==23 and m==59);report.callbacks=report.callbacks+1
    end});assert(getmetatable(screen)==Native)
    game.stack:push(screen);U.wait(60)
    assert(screen.scene.state=='view_input'and screen.scene.t.hours==23 and screen.scene.t.minutes==59)
    shot('clock-'..gender..'-native-night-view')
    game.input:overlayPressed('right');U.wait(80);game.input:overlayReleased('right');U.wait(4)
    assert(screen.scene.t.hours==23 and screen.scene.t.minutes==59,'VIEW must ignore setting input')
    shot('clock-'..gender..'-view-after-ignored-input')
    press(gender=='boy'and'a'or'b');U.wait(60)
    assert(game.stack:top()==world and original==Save.encode(game.save.gen3Clock)and unrelated==otherSave(),
      'Viewing or leaving the clock changed save fields beyond the normal playTime counter')
  end
  report.cases.bothGendersOriginalLayersHandsAndAmPm=true
  report.cases.viewIgnoresDirectionsAndNeverWritesOffset=true
  game.save.player.gender='boy'
  local male=Host.new(game,{onDone=function(h,m)
    assert(h==10 and m==0);report.callbacks=report.callbacks+1
  end})
  game.stack:push(male);U.wait(60);shot('clock-boy-native-setting')
  press('a');press('up');press('a');U.wait(60)
  assert(game.stack:top()==world and game.save.gen3Clock.hour==10 and game.save.gen3Clock.minute==0)
  report.cases.maleSettingAndNativeConfirmation=true
  game.save.player.gender='girl';game.save.options.gen3Frame=20
  game.save.gen3Clock={hour=7,minute=4,setAt=os.time()}
  local original=Save.encode(game.save.gen3Clock);local unrelated=otherSave()
  local answered
  local screen=Host.new(game,{onDone=function(h,m)answered={h,m};report.callbacks=report.callbacks+1 end})
  game.stack:push(screen);U.wait(60)
  assert(screen.scene.state=='set_input'and screen.scene.t.hours==10 and screen.scene.t.minutes==0,
    'RS setting starts at its original 10:00, not the old two-stage host selector')
  shot('clock-native-setting-default-ten')
  press('a');assert(screen.scene.state=='confirm_input'and screen.scene.confirm.cursor==1)
  shot('clock-native-confirm-default-no')
  press('a');assert(screen.scene.state=='set_input'and not screen.pending)
  assert(Save.encode(game.save.gen3Clock)==original,'Default NO wrote an offset')
  report.cases.defaultNoReturnsToSettingWithoutSave=true
  game.input:overlayPressed('right');U.wait(600)
  report.accelerated=screen.scene.t.moveSpeed
  assert(report.accelerated>60,'Held clock input never reached original acceleration thresholds')
  game.input:overlayReleased('right');U.wait(15)
  local hour,minute=screen.scene:time();assert(hour~=10 or minute~=0)
  assert(Save.encode(game.save.gen3Clock)==original and not screen.pending)
  shot('clock-native-after-accelerated-minute-hand')
  report.cases.originalHeldMinuteHandAcceleration=true
  press('a');assert(screen.scene.state=='confirm_input');press('b')
  assert(screen.scene.state=='set_input'and not screen.pending)
  report.cases.bCancelsOnlyTheConfirmation=true
  press('a');press('up');assert(screen.scene.confirm.cursor==0)
  shot('clock-native-confirm-yes-user-frame-twenty');press('a');U.wait(60)
  assert(game.stack:top()==world and answered and answered[1]==hour and answered[2]==minute)
  assert(game.save.gen3Clock.hour==hour and game.save.gen3Clock.minute==minute
    and type(game.save.gen3Clock.setAt)=='number'and unrelated==otherSave())
  assert(report.callbacks==4,'Native clock callback did not return exactly once')
  report.savedTime={hour=hour,minute=minute};shot('clock-native-setting-return')
  report.cases.confirmationWritesOnlyHostClockAndReturnsOnce=true
  report.status='pass';persist();love.event.quit(0)
end
