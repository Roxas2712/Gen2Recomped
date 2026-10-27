-- Prepared native confirmations; ordinary story acceptance is separate.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local Native=require('src.ui.Gen3RsChoice')
  local Choice=require('src.ui.ChoiceBox');local Text=require('src.render.TextBox')
  local out=assert(os.getenv('EDITION_QA_OUT'));local edition=require('src.core.GameVersion').get()
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(Native.available(game)and require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  local mon=require('src.pokemon.Pokemon').new(game.data,'GROVYLE',22)
  mon.moves={{id='CUT',pp=30},{id='PURSUIT',pp=20},{id='ABSORB',pp=20},{id='QUICK_ATTACK',pp=30}}
  game.save.party={mon};U.teleport(game,'MAP_G00_N11',11,9,'right');U.wait(90)
  local world=game.stack:top()
  local report={edition=edition,status='running',preparedYesNoFixture=true,continuousStory=false,
    cases={},captures={},drawSaveAndRngPreserved=true,callbacks=0}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(bytes==Save.encode(game.save)and rng==love.math.getRandomState(),'Confirmation draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function press(key)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(1)
  end
  local function reachChoice()
    for _=1,100 do
      if getmetatable(game.stack:top())==Native then return game.stack:top()end
      U.tap(game,'b');U.wait(30)
    end
    error('Native confirmation was never reached')
  end
  local result
  local function answer(value)result=value;report.callbacks=report.callbacks+1 end
  local s=Choice.new(game,answer);game.stack:push(s);U.wait(2)
  assert(getmetatable(s)==Native and s.yesNo and s.scene.left==20 and s.scene.top==8 and s.index==1)
  shot('yesno-field-yes');press('down');assert(s.index==2)
  shot('yesno-field-no');press('a');assert(result==false and game.stack:top()==world and report.callbacks==1)
  report.cases.fieldNativeLabelsBoundsAndFalse=true
  s=Choice.new(game,answer,{defaultNo=true});game.stack:push(s);U.wait(2)
  assert(s.index==2);press('left');assert(s.index==2);press('right');assert(s.index==2)
  shot('yesno-default-no');press('b');assert(result==false and report.callbacks==2 and game.stack:top()==world)
  report.cases.defaultNoHorizontalIgnoredAndBCancel=true
  game.stack:push(Text.new(game,'Would you like to save\nthe game?',nil,{choice=answer}))
  s=reachChoice();shot('yesno-native-over-retained-dialogue');press('a')
  assert(result==true and report.callbacks==3 and game.stack:top()==world)
  report.cases.dialogueCallbackClosesBothLayers=true
  local Party=require('src.ui.Gen3PartyMenu');local party=Party.new(game,{keepOpen=true})
  game.stack:push(party);U.wait(60)
  s=Choice.new(game,answer);game.stack:push(s);U.wait(2)
  assert(s.scene.left==23 and s.scene.top==8 and Native.yesNoStyle(game)=='party')
  shot('yesno-native-party-window');press('b');assert(game.stack:top()==party and report.callbacks==4)
  game.stack:pop();assert(game.stack:top()==world);report.cases.partyGeometryAndReturn=true
  local Battle=require('src.battle.BattleState');local battle=Battle.newWild(game,'POOCHYENA',5)
  game.stack:push(battle);U.wait(120)
  for _=1,40 do if battle.phase=='menu'then break end;U.tap(game,'b');U.wait(30)end
  assert(battle.phase=='menu'and game.stack:top()==battle,'Prepared battle must finish its actual send-out')
  s=Choice.new(game,answer);game.stack:push(s);U.wait(2)
  assert(s.scene.style=='battle'and s.scene.left==24 and s.scene.top==9)
  shot('yesno-native-battle-window');press('down');shot('yesno-native-battle-no')
  press('b');assert(game.stack:top()==battle and report.callbacks==5)
  report.cases.battleGeometryAndReturn=true
  local learned
  local Learn=require('src.ui.Gen3MoveLearnMenu')
  game.stack:push(Learn.new(game,mon,'SCREECH',function(value)learned=value end))
  s=reachChoice();assert(s.scene.style=='battle');shot('yesno-native-learn-move')
  press('b');s=reachChoice();assert(s.scene.style=='battle');shot('yesno-native-stop-learning')
  press('a')
  for _=1,40 do if game.stack:top()==battle then break end;U.tap(game,'b');U.wait(30)end
  assert(learned==false and game.stack:top()==battle and mon.moves[4].id=='QUICK_ATTACK')
  report.cases.stopLearningReturnsFalseWithoutChangingMoves=true
  game.stack:pop();assert(game.stack:top()==world)
  local Sound=require('src.core.Sound');local original=Sound.playId;local sounds=0
  Sound.playId=function(...)sounds=sounds+1;return original(...)end
  s=Choice.new(game,answer,{noSound=true});game.stack:push(s);press('down');press('a')
  Sound.playId=original;assert(sounds==0 and report.callbacks==6)
  report.cases.silentPromptRetainsPolicy=true
  local Start=require('src.ui.Gen3StartMenu');local start=Start.new(game)
  game.stack:push(start);start:startSave();s=game.stack:top()
  assert(getmetatable(s)==require('src.ui.Gen3RsSaveMenu')and s.phase=='confirm')
  shot('yesno-native-save-prompt')
  press('b');assert(game.stack:top()==start and not start.savePanel)
  game.stack:pop();assert(game.stack:top()==world)
  report.cases.saveCancelReturnsToStartMenu=true
  report.status='pass';persist();love.event.quit(0)
end
