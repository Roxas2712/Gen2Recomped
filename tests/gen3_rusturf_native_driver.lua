-- Prepared real-cartridge field fixture; this is not ordinary story progress.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local edition=require('src.core.GameVersion').get()
  assert(edition=='ruby'or edition=='sapphire'or edition=='emerald')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  local rule=assert(game.data.constants.gen3Rusturf,'Native two-rock story rule missing from fresh import')
  assert(#rule.rocks==2 and #rule.states==2)
  local report={edition=edition,status='running',preparedRusturfFixture=true,continuousStory=false,
    fullStoryAccepted=false,captures={},cases={},rule=rule}
  local function persist()
    local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()
  end
  local function shot(name)
    assert(U.shot(game,out..'/'..name..'.png'))
    report.captures[#report.captures+1]=name;persist()
  end
  local function press(key,n)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(n or 90)
  end
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  for which=1,2 do
    game.input:reset();U.freshSave(game)
    local mon=require('src.pokemon.Pokemon').new(game.data,'SCEPTILE',36)
    mon.moves={{id='ROCK_SMASH',pp=15}};game.save.party={mon}
    local gate=assert(game.data.constants.gen3FieldMoves.ROCK_SMASH)
    game.save.flags[('FLAG_G3_%04X'):format(gate.badgeFlag)]=true
    -- Real event-coordinate rows establish the approach variant; neither
    -- the tunnel state nor the removed-rock flags are injected here.
    U.teleport(game,rule.map,which==1 and 25 or 23,which==1 and 5 or 4,which==1 and'left'or'right')
    U.wait(120);local world=game.overworld
    assert(game.stack:top()==world and not world.runner:isRunning())
    assert(not game.save.inventory.HM04)
    shot('rusturf-rock-'..which..'-before');press('a',120)
    local received=false;local sawAward=false;local frames=0
    for _=1,180 do
      local top=game.stack:top()
      assert(not(top and top.trainer),'Rusturf rock incorrectly started a trainer battle')
      assert(not(top and top.enemy),'A story rock must skip wild encounters')
      if game.save.inventory.HM04==1 then received=true end
      if top and top.pages then
        local text={};for _,page in ipairs(top.pages)do text[#text+1]=type(page)=='table'and table.concat(page,' ')or tostring(page)end
        if table.concat(text,' '):find('HM04',1,true)then sawAward=true end
        press('a',120)
      elseif top and(top.screenId=='Gen3RsChoice'
          or getmetatable(top)==require('src.ui.ChoiceBox'))then
        press('a',120)
      elseif top==world then
        if received and not world.runner:isRunning()then break end
        U.wait(120)
      else U.wait(30)end
      frames=frames+1
    end
    assert(received and game.save.inventory.HM04==1,'Original rock-smash/frame script did not award HM04')
    assert(game.stack:top()==world and not world.runner:isRunning(),'Original couple scene did not finish')
    assert(mon.moves[1].pp==15,'Field ROCK SMASH must not spend battle PP')
    report.cases['rock'..which]={nativeHmAward=true,finishedOriginalScene=true,fieldPpPreserved=true,
      awardTextObserved=sawAward,storyState=game.save.gen3Vars[rule.var],iterations=frames}
    shot('rusturf-rock-'..which..'-scene-complete')
    U.teleport(game,rule.map,25,5,'left');U.wait(180)
    assert(game.save.flags[rule.rocks[which]],'The smashed tunnel rock returned on map entry')
    assert(game.save.flags[rule.openedFlag],'Original scene did not set its native opened flag')
    assert(game.save.inventory.HM04==1,'Reentry duplicated or lost the original HM')
    report.cases['rock'..which].reentryPreservesOpenTunnel=true
    shot('rusturf-rock-'..which..'-reentry')
    -- Opening one passage leaves the other rock in place on the cartridge.
    -- Breaking it after the couple leaves must not rearm the reward scene.
    U.teleport(game,rule.map,which==1 and 23 or 25,which==1 and 4 or 5,which==1 and'right'or'left')
    U.wait(120);world=game.overworld;press('a',120)
    for _=1,100 do
      local top=game.stack:top()
      assert(not(top and top.enemy),'No rock encounter is defined on the tunnel map')
      if top and top.pages then press('a',120)
      elseif top and(top.screenId=='Gen3RsChoice'or getmetatable(top)==require('src.ui.ChoiceBox'))then press('a',120)
      elseif top==world and not world.runner:isRunning()then break
      else U.wait(60)end
    end
    assert(game.stack:top()==world and not world.runner:isRunning(),'Remaining rock did not finish normally')
    assert(game.save.gen3Vars[rule.var]==rule.openedState,'Remaining rock restarted the completed couple scene')
    assert(game.save.inventory.HM04==1,'Remaining rock duplicated the original HM')
    for _,flag in ipairs(rule.rocks)do assert(game.save.flags[flag],'Remaining rock was not actually smashed')end
    report.cases['rock'..which].remainingRockDoesNotRepeatReward=true
    shot('rusturf-rock-'..which..'-remaining-rock-no-repeat')
  end
  report.status='pass';persist();print('PASS_GEN3_RUSTURF_NATIVE '..edition);love.event.quit(0)
end
