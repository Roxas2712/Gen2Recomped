-- Prepared native shop transactions; normal story lineage is separate.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json');local S=require('src.core.SaveSerializer')
  local Native=require('src.ui.Gen3RsShop');local out=assert(os.getenv('EDITION_QA_OUT'))
  local edition=require('src.core.GameVersion').get();assert(Native.available(game))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed',
    'gamepadreleased','joystickpressed','joystickreleased','joystickaxis','joystickhat',
    'touchpressed','touchreleased','touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset()
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local report={edition=edition,status='running',preparedShopFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,callbacksReturned=0,purchaseEffects=0,tvShowsAccepted=false}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  persist();U.freshSave(game);game.save.inventory={POKE_BALL=2,GREAT_BALL=2,HM01=1}
  game.save.bagOrder={'POKE_BALL','GREAT_BALL','HM01'};game.save.money=10000
  U.teleport(game,'MAP_G09_N12',3,3,'left');U.wait(120)
  local world=game.stack:top();local inv,order=game.save.inventory,game.save.bagOrder
  local audio=require('src.core.Sound');local play=audio.playId
  audio.playId=function(data,id,...)
    local source=play(data,id,...)
    if data==game.data and id==95 then assert(source,'Missing native purchase sound');report.purchaseEffects=report.purchaseEffects+1 end
    return source
  end
  local function shot(name)
    local before=S.encode(game.save);local rng=love.math.getRandomState();local cam=world.camera
    local x,y=cam.x,cam.y
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Shop draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));assert(cam.x==x and cam.y==y,'Shop draw moved the saved world camera')
    report.captures[#report.captures+1]=name;persist()
  end
  local function press(key,count)
    for _=1,count or 1 do game.input:overlayPressed(key);U.wait(3);game.input:overlayReleased(key);U.wait(50)end
  end
  local menu=require('src.ui.Gen3ShopMenu').counter(game,{stock={'POKE_BALL','GREAT_BALL','POTION','SUPER_POTION',
    'ANTIDOTE','PARLYZ_HEAL','AWAKENING','BURN_HEAL','ICE_HEAL','REPEL'},onQuit=function()report.callbacksReturned=report.callbacksReturned+1 end})
  assert(getmetatable(menu)==Native);local shop=menu.shop;U.wait(60);assert(shop.state=='root')
  shot('shop-native-root');press('a');assert(shop.state=='list');shot('shop-native-eight-row-stock')
  press('down',10);assert(shop.scroll+shop.row==10);shot('shop-native-scrolled-cancel')
  press('b');assert(shop.state=='root');press('a');assert(shop.state=='list'and shop.row==0)
  report.cases.eightRowsScrollAndCancel=true
  press('a');assert(shop.state=='qty'and shop.qty==1);press('down');assert(shop.qty==50)
  shot('shop-native-quantity-wrap');press('up');assert(shop.qty==1);press('right');press('down');assert(shop.qty==10)
  shot('shop-native-quantity-ten');press('a');assert(shop.state=='confirm');shot('shop-native-buy-confirmation')
  press('b');assert(shop.state=='list'and inv.POKE_BALL==2 and game.save.money==10000)
  report.cases.quantityAndCancelNoMutation=true
  press('a');press('right');press('down');press('a');press('a')
  assert(shop.state=='msg'and inv.POKE_BALL==12 and game.save.money==8000)
  assert(game.save.gen3Stats[38]==1 and not inv.PREMIER_BALL)
  shot('shop-native-purchased-ten');press('a')
  assert(shop.state=='msg'and inv.PREMIER_BALL==1);shot('shop-native-premier-ball-gift');press('a')
  assert(shop.state=='list');report.cases.tenPokeBallsGrantPremier=true
  local money=game.save.money;inv.POKE_BALL=99
  press('a');press('a');press('a');assert(shop.state=='msg'and game.save.money==money-200 and inv.POKE_BALL==100)
  assert(game.save.gen3Stats[38]==2)
  local Model=require('src.inventory.Gen3RsInventory');local slots=Model.rows(game.save,game.data,'BALL')
  assert(#slots==4 and slots[1].qty==99 and slots[4].qty==1 and Model.consistent(game.save,game.data))
  shot('shop-native-ninety-nine-splits-stack');press('a');money=game.save.money
  inv.POKE_BALL=99*14;game.save.gen3RsBagSlots=nil
  press('a');press('a');press('a');assert(shop.state=='msg'and game.save.money==money and inv.POKE_BALL==99*14)
  assert(game.save.gen3Stats[38]==2);shot('shop-native-full-pocket-refused');press('a')
  inv.POKE_BALL=12;game.save.gen3RsBagSlots=nil
  report.cases.fullPocketNoCharge=true;report.cases.fullStackSplitsWithoutItemLoss=true
  game.save.money=0;press('a');assert(shop.state=='msg'and inv.POKE_BALL==12)
  shot('shop-native-insufficient-money');press('a');game.save.money=money
  report.cases.insufficientMoneyNoCharge=true
  -- Independent prepared sale: 99/12 duplicate stacks. The native sale must
  -- offer only the selected twelve and leave the first ninety-nine alone.
  inv.POKE_BALL=111;game.save.gen3RsBagSlots=nil
  press('b');assert(shop.state=='root');press('down');press('a')
  local bag=game.stack:top();assert(bag.sell and bag.onSell and menu.shop.state=='sell')
  assert(menu.fade.t==0 and not menu.fade.active,'Private shop fade did not continue while the bag owned input')
  press('right');press('down');assert(bag:selected().id=='POKE_BALL'and bag:selected().qty==12)
  assert(bag.rows[1].qty==99);shot('shop-native-sell-bag')
  press('a');local sale=game.stack:top();assert(sale.screenId=='Gen3RsShopSale'and sale.flow.state=='qty')
  assert(bag.rsSaleActive,'Native sale must deactivate the underlying bag list cursor')
  assert(menu.fade.t==0,'Sale must not be covered by a suspended black fade')
  shot('shop-native-sell-quantity');press('right');assert(sale.flow.qty==11);press('left');press('a')
  assert(sale.flow.state=='confirm');shot('shop-native-sell-confirmation');press('b')
  assert(game.stack:top()==bag and inv.POKE_BALL==111 and game.save.money==money)
  assert(not bag.rsSaleActive,'Native sale must restore bag selection on cancel')
  report.cases.sellCancelNoMutation=true
  press('a');sale=game.stack:top();press('a');press('a')
  assert(sale.flow.state=='done'and inv.POKE_BALL==110 and game.save.money==money+100)
  slots=Model.rows(game.save,game.data,'BALL')
  assert(slots[1].qty==99 and slots[2].qty==11);report.cases.saleConsumesSelectedPhysicalStack=true
  shot('shop-native-sold-one');press('b');assert(game.stack:top()==sale,'RS sale acknowledgement incorrectly accepts B')
  press('a');assert(game.stack:top()==bag);report.cases.saleUpdatesHostBagAndMoney=true
  press('right');assert(bag:selected().id=='HM01');press('a');sale=game.stack:top()
  assert(sale.flow.state=='cant');shot('shop-native-hm-refused');press('b')
  assert(game.stack:top()==bag and inv.HM01==1);report.cases.unsellableItemPreserved=true
  press('b');assert(game.stack:top()==menu and shop.state=='root');press('b')
  assert(game.stack:top()==world and report.callbacksReturned==1)
  assert(game.save.inventory==inv and game.save.bagOrder==order)
  for id in pairs(inv)do assert(type(id)=='string','Native numeric ID persisted into host bag')end
  assert(report.purchaseEffects==3,'Expected two buys and one sell purchase sound')
  assert(Model.consistent(game.save,game.data),'Sale did not persist authoritative slots')
  report.cases.callbacksAndStableHostIds=true
  menu=require('src.ui.Gen3ShopMenu').counter(game,{stock={},onQuit=function()report.callbacksReturned=report.callbacksReturned+1 end})
  press('a');assert(menu.shop.state=='list'and #menu.shop._items==0)
  shot('shop-native-empty-cancel');press('a');assert(menu.shop.state=='root');press('b')
  assert(game.stack:top()==world and report.callbacksReturned==2);report.cases.emptyStockHasOnlyCancel=true
  menu=require('src.ui.Gen3ShopMenu').counter(game,{stock={'TM01'},onQuit=function()report.callbacksReturned=report.callbacksReturned+1 end})
  press('a');press('a');assert(menu.shop.state=='qty')
  shot('shop-native-tm-quantity');press('b');press('b');press('b')
  assert(game.stack:top()==world and report.callbacksReturned==3 and not inv.TM01)
  report.cases.machineStockUsesNativeItemView=true
  local D=require('src.world.Gen3Decorations');local item
  for _,d in ipairs(assert(D.record(game.data)).list)do if d.price==10000 then item=d.id;break end end
  assert(item,'No native10000 decoration fixture');game.save.money=20000;local owned=D.count(game.save,item)
  menu=require('src.ui.Gen3ShopMenu').new(game,{mode='buy',kind='decoration',shopMode=1,stock={item},
    onQuit=function()report.callbacksReturned=report.callbacksReturned+1 end});game.stack:push(menu)
  assert(menu.shop.state=='root');shot('shop-native-decoration-root');press('a')
  shot('shop-native-decoration-price10000');press('a');assert(menu.shop.state=='confirm')
  shot('shop-native-decoration-confirm');press('a')
  assert(menu.shop.state=='msg'and game.save.money==10000 and D.count(game.save,item)==owned+1)
  shot('shop-native-decoration-purchased');press('a');assert(menu.shop.state=='list')
  press('b');press('b');assert(game.stack:top()==world and report.callbacksReturned==4)
  assert(report.purchaseEffects==4);report.cases.decorationPriceAndInventory=true
  report.status='pass';persist();love.event.quit(0)
end
