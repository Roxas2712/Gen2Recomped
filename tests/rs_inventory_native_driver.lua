-- Prepared slot fixture, real RS bag/party/save controllers and final renderer.
return function(game)
  local U=require('tests.drivers.util');local S=require('src.core.SaveSerializer')
  local J=require('src.link.Json');local Model=require('src.inventory.Gen3RsInventory')
  local HostBag=require('src.inventory.Bag');local Bag=require('src.ui.Gen3BagMenu')
  local Action=require('src.ui.Gen3ItemMenu');local edition=require('src.core.GameVersion').get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game);U.teleport(game,'MAP_G00_N11',11,9,'right');U.wait(90)
  local world=game.stack:top()
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'TREECKO',12)}
  game.save.inventory={POTION=100,REPEL=100,CHERI_BERRY=999}
  game.save.bagOrder={'POTION','REPEL','CHERI_BERRY'};game.save.gen3RsBagSlots=nil
  local report={edition=edition,status='running',preparedInventoryFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,normalPlayTimeExcluded=true}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,n)
    for _=1,n or 1 do game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(4)end
  end
  local function shot(name)
    local before=S.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Inventory draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local bag=Bag.new(game,{pocket='ITEM'});game.stack:push(bag);U.wait(30)
  assert(#bag.rows==5 and bag.rows[1].qty==99 and bag.rows[2].qty==1)
  assert(not game.save.gen3RsBagSlots,'Opening old bag performed an implicit save migration')
  shot('inventory-native-duplicate-stacks')
  press('down');press('select');press('up');press('a')
  assert(not bag.rsSwap and bag.rows[1].qty==1 and bag.rows[2].qty==99)
  assert(Model.consistent(game.save,game.data));shot('inventory-native-swapped-duplicate-stacks')
  press('down');press('a');assert(getmetatable(game.stack:top())==Action)
  press('down');press('a');local view=bag.rsView.view
  assert(view.mode=='toss'and view._rsBag.toss.qty==99)
  press('up',2);press('a');shot('inventory-native-second-stack-toss-confirm')
  press('a');assert(view.mode=='toss_done')
  assert(bag.rows[1].qty==1 and bag.rows[2].qty==96 and game.save.inventory.POTION==97)
  assert(Model.consistent(game.save,game.data));shot('inventory-native-second-stack-only-removed')
  press('b');press('down',2);assert(bag:selected().id=='REPEL'and bag:selected().qty==1)
  press('a');press('a')
  assert(game.save.repelSteps==100 and game.save.inventory.REPEL==99)
  for _=1,120 do if game.stack:top()==bag then break end;press('a')end
  assert(game.stack:top()==bag and #bag.rows==4 and bag.rows[3].id=='REPEL'and bag.rows[3].qty==99)
  assert(Model.consistent(game.save,game.data));shot('inventory-native-selected-repel-consumed')
  press('up',20);press('down');assert(bag:selected().id=='POTION'and bag:selected().qty==96)
  press('a');press('right');local action=game.stack:top()
  assert(getmetatable(action)==Action and action.entries[action.index].kind=='give');press('a')
  local party=game.stack:top();assert(party.pickOnly and party.onSwitch)
  U.wait(60)
  press('a');assert(game.save.party[1].item=='POTION'and game.save.inventory.POTION==96)
  for _=1,120 do if game.stack:top()==bag then break end;press('a')end
  assert(game.stack:top()==bag and bag.rows[1].qty==1 and bag.rows[2].qty==95)
  assert(Model.consistent(game.save,game.data));shot('inventory-native-selected-stack-give')
  press('b');assert(game.stack:top()==world)
  bag=Bag.new(game,{pocket='BERRY'});game.stack:push(bag);U.wait(30)
  assert(bag:selected().qty==999);shot('inventory-native-nine-hundred-ninety-nine-berries')
  local before=S.encode(game.save)
  assert(not HostBag.add(game.save,'CHERI_BERRY',1,game.data))
  assert(before==S.encode(game.save),'Berry overflow changed save')
  press('b');assert(game.stack:top()==world)
  -- Save through the original START -> SAVE flow in this isolated profile.
  local Start=require('src.ui.Gen3StartMenu');local owner=Start.new(game)
  for i,row in ipairs(owner.rows)do if row.key=='save'then owner.index=i end end
  game.stack:push(owner);press('a');local screen=game.stack:top()
  assert(getmetatable(screen)==require('src.ui.Gen3RsSaveMenu')and screen.phase=='confirm')
  shot('inventory-native-save-with-physical-slots');press('a')
  for _=1,180 do if game.stack:top()==world then break end;U.wait(1)end
  assert(game.stack:top()==world and screen.wrote)
  local IO=require('src.core.SaveData');local bytes=assert(love.filesystem.read(IO.saveFilename(edition)))
  local restored=assert(S.decode(bytes))
  assert(Model.consistent(restored,game.data))
  assert(S.encode(restored.gen3RsBagSlots)==S.encode(game.save.gen3RsBagSlots))
  local rows=Model.rows(restored,game.data,'ITEM')
  assert(rows[1].qty==1 and rows[2].qty==95 and rows[3].qty==99)
  local priorSave=game.save
  game:returnToTitle()
  local ready=false
  for _=1,6000 do
    local top=game.stack:top()
    if top and top.kind=='title'and top.scene.phase=='phase3'then ready=true;break end
    U.wait(1)
  end
  assert(ready,'Prepared return to native title timed out')
  game.input:overlayPressed('start');U.wait(1);game.input:overlayReleased('start');U.wait(100)
  assert(getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu'))
  assert(game.stack:top().items[1].key=='continue');press('a');U.wait(30)
  assert(game.stack:top().info);shot('inventory-native-continue-summary')
  press('a');U.wait(120)
  assert(game.stack:top()==game.overworld and game.save~=priorSave)
  assert(Model.consistent(game.save,game.data))
  assert(S.encode(game.save.gen3RsBagSlots)==S.encode(restored.gen3RsBagSlots))
  assert(love.filesystem.read(IO.saveFilename(edition))==bytes,'CONTINUE changed stored save bytes')
  bag=Bag.new(game,{pocket='ITEM'});game.stack:push(bag);U.wait(30)
  assert(bag.rows[1].qty==1 and bag.rows[2].qty==95 and bag.rows[3].qty==99)
  shot('inventory-native-continued-physical-slots');press('b')
  report.cases.legacyReadDoesNotMigrate=true
  report.cases.duplicateStacksAndPhysicalSelectSwap=true
  report.cases.tossConsumesSelectedSecondStackOnly=true
  report.cases.useConsumesSelectedLastRepelStack=true
  report.cases.giveConsumesSelectedSecondStackOnly=true
  report.cases.berry999AndOverflowAtomic=true
  report.cases.nativeSavePreservesPartialDuplicateSlots=true
  report.cases.nativeContinueReloadsPhysicalSlotsWithoutDiskWrites=true
  report.cases.stableHostIdsAndStoredAggregateConsistent=true
  report.status='pass';persist();love.event.quit(0)
end
