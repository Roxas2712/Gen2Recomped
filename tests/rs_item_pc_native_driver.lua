-- Prepared storage fixtures, native PC/bag inputs and authoritative host IO.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json');local S=require('src.core.SaveSerializer')
  local Native=require('src.ui.Gen3RsPlayerPC');local Model=require('src.inventory.Gen3RsInventory')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(Native.available(game)and require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game);U.teleport(game,'MAP_G00_N11',11,9,'right');U.wait(90)
  local world=game.stack:top()
  local report={edition=edition,status='running',preparedItemPcFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,callbacks=0,rootCallbacks=0,nonemptyMailboxAccepted=false}
  local scratch=love.graphics.newCanvas(240,160,{dpiscale=1})
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,n,delay)
    for _=1,n or 1 do game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(delay or 4)end
  end
  local function shot(name)
    local bytes=S.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()
      love.graphics.setCanvas(scratch);love.graphics.origin();love.graphics.setScissor();love.graphics.setShader()
      love.graphics.clear(0,0,0,0);game.stack:top():draw()
    end))
    assert(bytes==S.encode(game.save)and rng==love.math.getRandomState(),'PC draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function goods()
    local save=game.save
    return S.encode({inventory=save.inventory,bagOrder=save.bagOrder,slots=save.gen3RsBagSlots,
      pcItems=save.pcItems,pcOrder=save.pcOrder,registered=save.registeredItem})
  end
  local function open(order)
    local before=goods();local pc=require('src.ui.Gen3PlayerPC').new(game,{order=order,
      onDone=function()report.callbacks=report.callbacks+1 end})
    assert(getmetatable(pc)==Native);game.stack:push(pc);U.wait(20)
    assert(before==goods(),'Opening PC changed goods/order/schema');return pc
  end
  for _,gender in ipairs({'boy','girl'})do
    game.save.player.gender=gender;game.save.options.gen3Frame=gender=='girl'and 20 or 1
    local pc=open('bedroom');assert(pc.pc.mode=='player_pc'and #pc.ui.topOrder(pc.pc)==4)
    shot('pc-'..gender..'-original-bedroom-menu');press('up');assert(pc.pc.cursor==4)
    press('down');assert(pc.pc.cursor==1);press('down');press('a')
    assert(pc.pc.mode=='rse_msg');shot('pc-'..gender..'-original-empty-mailbox')
    press('b');assert(pc.pc.mode=='player_pc'and pc.pc.cursor==1);press('b');assert(game.stack:top()==world)
  end
  local function openRoot()
    world:openGen3PC(function()report.rootCallbacks=report.rootCallbacks+1 end)
    for _=1,40 do if game.stack:top().screenId=='Gen3RsPcRoot'then break end;press('a')end
    local root=game.stack:top();assert(root.screenId=='Gen3RsPcRoot');return root
  end
  local root=openRoot()
  assert(#root.items==3 and root.items[1].label:find('SOMEONE')and root.items[3].label:find('LOG OFF'))
  for _,row in ipairs(root.items)do assert(not row.label:find('OAK')and not row.label:find('BILL'))end
  shot('pc-original-hoenn-root')
  press('down');press('a');assert(game.stack:top().screenId=='Gen3RsPlayerPC')
  press('b');assert(game.stack:top().screenId=='Gen3RsPcRoot')
  press('a');assert(game.stack:top().screenId=='Gen3RsStorage')
  shot('pc-original-root-opens-pokemon-storage');press('b')
  assert(game.stack:top().screenId=='Gen3RsPcRoot');press('b');assert(game.stack:top()==world and report.rootCallbacks==1)
  local C=require('compat.gen1-rs.Constants').new(require('compat.gen1-rs.Loader').new(edition))
  local lanette,clear=('FLAG_G3_%04X'):format(C:flag('FLAG_SYS_PC_LANETTE')),('FLAG_G3_%04X'):format(C:flag('FLAG_SYS_GAME_CLEAR'))
  local oldLanette,oldClear=game.save.flags[lanette],game.save.flags[clear]
  game.save.flags[lanette]=true;game.save.flags[clear]=true
  root=openRoot();assert(#root.items==4 and root.items[1].label:find('LANETTE')and root.items[3].label:find('HALL OF FAME'))
  shot('pc-original-lanette-and-clear-root-gates');press('b')
  assert(game.stack:top()==world and report.rootCallbacks==2)
  game.save.flags[lanette]=oldLanette;game.save.flags[clear]=oldClear
  game.save.pcItems={POTION=125,ANTIDOTE=2,PARLYZ_HEAL=3};game.save.pcOrder={'POTION','ANTIDOTE','PARLYZ_HEAL'}
  local extra={}
  for id,d in pairs(game.data.items)do
    if d.pocket=='ITEM'and(tonumber(d.importance)or 0)==0 and not game.save.pcItems[id]
      and id~='NONE'and type(d.index)=='number'and d.index>0 then extra[#extra+1]=id end
  end
  table.sort(extra,function(a,b)return game.data.items[a].index<game.data.items[b].index end)
  for i=1,9 do game.save.pcItems[extra[i]]=i;game.save.pcOrder[#game.save.pcOrder+1]=extra[i]end
  game.save.inventory={POTION=99,ANTIDOTE=1,MACH_BIKE=1};game.save.bagOrder={'POTION','ANTIDOTE','MACH_BIKE'}
  game.save.gen3RsBagSlots=nil;game.save.registeredItem='MACH_BIKE'
  local pc=open('player');assert(#pc.ui.topOrder(pc.pc)==3)
  press('up');assert(pc.pc.cursor==1);press('a');assert(pc.pc.mode=='item_storage')
  shot('pc-original-item-storage-descriptions');press('up');assert(pc.pc.cursor==4)
  press('down');assert(pc.pc.cursor==1);press('a');local child=game.stack:top();local ui=child.ui
  assert(child.screenId=='Gen3RsItemStorage'and ui.state=='list');shot('pc-original-withdraw-list')
  press('down',8);assert(ui.scroll>0);shot('pc-original-eight-row-scroll');press('up',20)
  local before=goods();press('a');assert(ui.state=='quantity');press('down');assert(ui.quantity==125)
  press('up');press('right');assert(ui.quantity==11);shot('pc-original-withdraw-quantity')
  press('b');assert(ui.state=='list'and before==goods())
  press('a');press('right');press('down');press('a')
  assert(ui.state=='remove'and game.save.inventory.POTION==109 and game.save.pcItems.POTION==115)
  assert(pc.tx.store.items[1].qty==125 and Model.consistent(game.save,game.data))
  shot('pc-original-withdraw-result-atomic-stores')
  assert(game:writeSave(),'Own prepared modal save failed')
  local IO=require('src.core.SaveData');local disk=S.decode(assert(love.filesystem.read(IO.saveFilename(edition))))
  assert(disk.pcItems.POTION==115 and disk.inventory.POTION==109 and Model.consistent(disk,game.data))
  press('b');assert(ui.state=='list'and pc.tx.store.items[1].qty==115 and game.save.inventory.POTION==109)
  local keepBag=S.encode({inventory=game.save.inventory,bagOrder=game.save.bagOrder,slots=game.save.gen3RsBagSlots})
  game.save.inventory={POTION=99*20};game.save.bagOrder={'POTION'};game.save.gen3RsBagSlots=nil
  before=goods();press('a');press('a');assert(ui.state=='error'and ui.quantity==0 and before==goods())
  shot('pc-original-full-bag-refusal');press('b')
  local keep=S.decode(keepBag);game.save.inventory=keep.inventory;game.save.bagOrder=keep.bagOrder;game.save.gen3RsBagSlots=keep.slots
  press('select');press('down',2);shot('pc-original-select-move');press('select')
  assert(ui.state=='list'and game.save.pcOrder[1]=='ANTIDOTE'and game.save.pcOrder[2]=='POTION')
  press('b');assert(game.stack:top()==pc and pc.pc.mode=='item_storage'and pc.pc.cursor==1)
  press('down');press('a');local bag=game.stack:top()
  assert(bag.store=='deposit'and bag.rsPcTransaction==pc.tx and bag.rs)
  U.wait(30);press('up',20);press('down')
  while bag:selected().id~='POTION'or bag:selected().qty~=10 do
    assert(not bag:selected().close,'Missing second Potion stack');press('down')
  end
  press('a');local view=bag.rsView.view;assert(view.mode=='deposit'and view.tossQty==1)
  press('down');assert(view.tossQty==10);press('up');press('up',2);assert(view.tossQty==3)
  shot('pc-original-deposit-selected-stack-quantity');press('a')
  assert(view.mode=='deposit_done'and game.save.inventory.POTION==106 and game.save.pcItems.POTION==118)
  assert(bag.rows[1].qty==99 and Model.consistent(game.save,game.data))
  shot('pc-original-deposit-result');press('b');assert(not bag.rsDeposit)
  game.save.pcItems.POTION=999;before=goods();press('a');press('a')
  assert(view.mode=='message'and before==goods());shot('pc-original-999-stack-refusal')
  press('start');assert(view.mode=='list'and not bag.rsDeposit)
  press('right',4,20);assert(bag.pocket==5 and bag:selected().id=='MACH_BIKE')
  press('a');assert(view.mode=='deposit_done'and game.save.pcItems.MACH_BIKE==1
    and not game.save.inventory.MACH_BIKE and not game.save.registeredItem)
  shot('pc-original-key-deposit-and-registration-clear');press('b');press('b')
  assert(game.stack:top()==pc and pc.pc.cursor==2)
  press('down');press('a');child=game.stack:top();ui=child.ui;assert(ui._toss)
  press('down');assert(pc.tx.store.items[ui.scroll+ui.row+1].id==game.data.items.POTION.index)
  before=goods();press('a');press('a');assert(ui.state=='yesno'and ui.yesCursor==1)
  shot('pc-original-toss-confirmation');press('down');press('a');assert(ui.state=='list'and before==goods())
  press('a');press('up',2);press('a');press('a')
  assert(ui.state=='remove'and game.save.pcItems.POTION==996);shot('pc-original-toss-result')
  press('b');assert(ui.state=='list'and pc.tx.store.items[ui.scroll+ui.row+1].qty==996)
  press('down',30)
  while pc.tx.store.items[ui.scroll+ui.row+1]==nil do press('up')end
  while pc.tx.store.items[ui.scroll+ui.row+1].id~=game.data.items.MACH_BIKE.index do press('down')end
  before=goods();press('a');assert(ui.state=='error'and before==goods())
  shot('pc-original-important-item-toss-refusal');press('b');press('b')
  assert(game.stack:top()==pc and pc.pc.cursor==3)
  local keepPc=S.encode({items=game.save.pcItems,order=game.save.pcOrder})
  game.save.pcItems={};game.save.pcOrder={};pc.tx:refresh();press('a')
  assert(pc.pc.mode=='rse_msg');shot('pc-original-empty-storage-message');press('b')
  assert(pc.pc.mode=='item_storage'and pc.pc.cursor==1)
  local restored=S.decode(keepPc);game.save.pcItems=restored.items;game.save.pcOrder=restored.order;pc.tx:refresh()
  press('b');assert(pc.pc.mode=='player_pc');press('down',5);assert(pc.pc.cursor==3)
  press('a');assert(game.stack:top()==world and report.callbacks==3)
  local Start=require('src.ui.Gen3StartMenu');local owner=Start.new(game)
  for i,row in ipairs(owner.rows)do if row.key=='save'then owner.index=i end end
  game.stack:push(owner);press('a');local saveMenu=game.stack:top()
  assert(getmetatable(saveMenu)==require('src.ui.Gen3RsSaveMenu'));press('a')
  assert(saveMenu.phase=='overwrite');press('a')
  for _=1,180 do if game.stack:top()==world then break end;U.wait(1)end
  assert(game.stack:top()==world and saveMenu.wrote)
  local bytes=assert(love.filesystem.read(IO.saveFilename(edition)));disk=assert(S.decode(bytes))
  assert(disk.pcItems.POTION==996 and disk.pcItems.MACH_BIKE==1 and disk.inventory.POTION==106)
  assert(Model.consistent(disk,game.data));shot('pc-field-after-save')
  report.cases.originalBedroomAndPlayerRows=true
  report.cases.nativeHoennRootNamesAndNoProfessorRow=true
  report.cases.rootPlayerAndPokemonStorageReturn=true
  report.cases.originalLanetteAndGameClearRootGates=true
  report.cases.bothGenderFramesAndEmptyMailbox=true
  report.cases.originalDescriptionsAndEightRowScroll=true
  report.cases.withdrawQuantityAndCancel=true
  report.cases.withdrawAtomicBeforeResultAcknowledgement=true
  report.cases.modalHostSaveDoesNotDuplicateGoods=true
  report.cases.fullPhysicalBagRefusalPreservesPc=true
  report.cases.selectInsertionOrderPersists=true
  report.cases.depositConsumesSelectedPhysicalStack=true
  report.cases.pc999OverflowIsAtomic=true
  report.cases.keyDepositClearsOnlyVanishedRegistration=true
  report.cases.tossNoCancelAndConfirmedQuantity=true
  report.cases.importantPcItemsProtected=true
  report.cases.emptyPcReturnsToStorage=true
  report.cases.scriptCallbacksReturnOnce=true
  report.cases.nativeSavePersistsBothStores=true
  report.status='pass';persist();love.event.quit(0)
end
