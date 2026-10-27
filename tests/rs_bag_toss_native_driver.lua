-- The original RS toss controller runs over the authoritative host bag.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local Bag=require('src.ui.Gen3BagMenu')
  local Action=require('src.ui.Gen3ItemMenu');local edition=require('src.core.GameVersion').get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.Gen3RsBag').tossReady(game.data.constants.gen3RsBag,edition))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game);U.teleport(game,'MAP_G00_N11',11,9,'right');U.wait(90)
  local world=game.stack:top()
  local report={edition=edition,status='running',preparedTossFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,normalPlayTimeExcluded=true}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(bytes==Save.encode(game.save)and rng==love.math.getRandomState(),'Toss draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function press(key,n)
    for _=1,n or 1 do game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(3)end
  end
  local function unrelated()
    local copy={};for k,v in pairs(game.save)do
      if k~='playTime'and k~='inventory'and k~='bagOrder'and k~='gen3RsBagSlots'then copy[k]=v end
    end
    return Save.encode(copy)
  end
  local function openToss(bag)
    press('a');local action=game.stack:top();assert(getmetatable(action)==Action)
    for _=1,bag.pocket==4 and 2 or 1 do press('down')end
    assert(action.entries[action.index].kind=='toss');press('a')
    assert(game.stack:top()==bag and bag.rsToss and bag.rsView.view.mode=='toss')
    return bag.rsView.view
  end
  for _,gender in ipairs({'boy','girl'})do
    game.save.player.gender=gender;game.save.options.gen3Frame=gender=='girl'and 20 or 1
    game.save.inventory={POTION=37,ANTIDOTE=2,CHERI_BERRY=125,CHESTO_BERRY=3,MACH_BIKE=1}
    game.save.bagOrder={'POTION','ANTIDOTE','CHERI_BERRY','CHESTO_BERRY','MACH_BIKE'}
    game.save.gen3RsBagSlots=nil
    local baseline=unrelated();local bag=Bag.new(game,{pocket='ITEM'})
    game.stack:push(bag);U.wait(30);for _=1,10 do press('up')end
    local view=openToss(bag);local before=Save.encode(game.save.inventory)
    assert(view.tossQty==1);press('down');assert(view.tossQty==37)
    press('up');assert(view.tossQty==1);press('right');assert(view.tossQty==11)
    press('left');assert(view.tossQty==1);press('right',3);press('up',6)
    assert(view.tossQty==37);press('right');assert(view.tossQty==37)
    press('left');assert(view.tossQty==27);shot('toss-'..gender..'-native-quantity')
    press('b');assert(not bag.rsToss and before==Save.encode(game.save.inventory))
    view=openToss(bag);press('up',2);press('a')
    assert(view.mode=='toss_confirm'and view.yesNoCursor==1 and view.tossQty==3)
    shot('toss-'..gender..'-native-confirm-yes')
    press('down');assert(view.yesNoCursor==2);press('a')
    assert(not bag.rsToss and before==Save.encode(game.save.inventory))
    view=openToss(bag);press('a');press('b')
    assert(not bag.rsToss and before==Save.encode(game.save.inventory))
    view=openToss(bag);press('up',2);press('a');press('a')
    assert(view.mode=='toss_done'and bag.rsToss and game.save.inventory.POTION==34)
    assert(require('src.inventory.Gen3RsInventory').consistent(game.save,game.data))
    assert(game.save.inventory.ANTIDOTE==2 and baseline==unrelated())
    shot('toss-'..gender..'-native-result-three-removed')
    press('b');view=openToss(bag);press('down')
    assert(view.tossQty==34);press('a');press('a')
    assert(view.mode=='toss_done'and not game.save.inventory.POTION and bag.index==1
      and bag:selected().id=='ANTIDOTE'and #bag.rows==2)
    assert(require('src.inventory.Gen3RsInventory').consistent(game.save,game.data))
    shot('toss-'..gender..'-complete-removal-clamped-list')
    press('b');press('b');assert(game.stack:top()==world)
    bag=Bag.new(game,{pocket='BERRY'});game.stack:push(bag);U.wait(30)
    for _=1,10 do press('up')end
    view=openToss(bag);assert(view.tossQty==1)
    press('right');assert(view.tossQty==11);press('down');assert(view.tossQty==10)
    press('left');assert(view.tossQty==1);press('down');assert(view.tossQty==125)
    shot('toss-'..gender..'-berry-three-digit-quantity')
    press('a');shot('toss-'..gender..'-berry-native-confirm');press('b')
    assert(not bag.rsToss and game.save.inventory.CHERI_BERRY==125)
    assert(baseline==unrelated()and game.save.inventory.MACH_BIKE==1)
    press('b');assert(game.stack:top()==world)
  end
  report.cases.originalQuantityWrapAndTenStepClamp=true
  report.cases.quantityCancelDoesNotChangeInventory=true
  report.cases.nativeYesNoAndBCancel=true
  report.cases.partialRemovalConsumesOnlyChosenStableId=true
  report.cases.wholeStackRemovalRefreshesAndClampsHostList=true
  report.cases.berryThreeDigitQuantityAndOriginalPrompt=true
  report.cases.bothGendersAndUserFrameTwenty=true
  report.cases.unrelatedSaveAndGameplayRngPreserved=true
  report.status='pass';persist();love.event.quit(0)
end
