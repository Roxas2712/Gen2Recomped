-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared transaction fixture; original shop entry and ordinary bag input.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local v=V.get();local frlg=V.isFRLG()
  assert(v=='emerald'or frlg);local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..v..'%-'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  local Bag=require('src.inventory.Bag');local S=require('src.core.SaveSerializer')
  local IO=require('src.core.SaveData');local UI=require('src.ui.Gen3BagSale')
  assert(UI.available(game));game.save.inventory={};game.save.bagOrder={};game.save.money=1000
  for _,entry in ipairs{{'POTION',frlg and 12 or 150},{'ANTIDOTE',1},{'ORAN_BERRY',999},
    {'MASTER_BALL',1},{'TM01',2},{'HM01',1}}do assert(Bag.add(game.save,entry[1],entry[2],game.data))end
  if frlg then
    for _,entry in ipairs{{'TM39',1},{'HM03',1},{'TM03',1},{'TM_CASE',1},{'BERRY_POUCH',1}}do
      assert(Bag.add(game.save,entry[1],entry[2],game.data))
    end
  end
  U.teleport(game,frlg and'MAP_G04_N00'or'MAP_G01_N01',4,2,'down');U.wait(60)
  local world=game.stack:top();local report={status='running',edition=v,preparedFixture=true,
    continuousStory=false,captures={},cases={},clockSeconds=0}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(k)
    game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(32)
  end
  local function shot(name)
    local raw=S.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
    assert(require('src.render.GraphicsScope').call(top.draw,top))
    assert(raw==S.encode(game.save)and rng==love.math.getRandomState())
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function unchanged(raw)
    local a,b=assert(S.decode(raw)),assert(S.decode(S.encode(game.save)))
    local dt=IO.playSeconds(b)-IO.playSeconds(a);assert(dt>=0 and dt<180)
    report.clockSeconds=report.clockSeconds+dt;a.playTime,b.playTime=0,0
    assert(S.encode(a)==S.encode(b),'Sale cancellation changed more than the accounted play clock')
  end
  local quit=0;local menu=require('src.ui.ShopMenu').new(game,{'POTION'},function()quit=quit+1 end)
  game.stack:push(menu);U.wait(30);press('down');press('a')
  local root=game.stack:top();assert(getmetatable(root)==require('src.ui.Gen3BagMenu')and root.sell)
  shot('native-sale-shop-opens-bag')
  local function select(owner,id,slot)
    for _=1,#owner.rows do if owner.index==1 then break end;press('up')end
    for _=1,#owner.rows+1 do
      local r=owner:selected();if r and r.id==id and(not slot or r.rsSlot and r.rsSlot.index==slot)then return end
      press('down')
    end
    error('Ordinary sale cursor could not reach '..id)
  end
  select(root,'POTION',not frlg and 2 or nil);press('a')
  local sale=game.stack:top();assert(getmetatable(sale)==UI and sale.max==(frlg and 12 or 51))
  local before=S.encode(game.save);press('right');assert(sale.qty==11)
  shot('native-sale-quantity-ten-step');press('b');assert(game.stack:top()==root);unchanged(before)
  press('a');sale=game.stack:top();press('a');assert(sale.mode=='confirm')
  before=S.encode(game.save);press('down');shot('native-sale-confirm-no');press('a')
  assert(game.stack:top()==root);unchanged(before)
  press('a');sale=game.stack:top();press('up');press('up');press('a')
  assert(sale.mode=='confirm'and sale.qty==3);shot('native-sale-confirm-three')
  local cash=game.save.money;local unit=math.floor(game.data.items.POTION.price/2)
  press('a');assert(sale.mode=='done'and game.save.money==cash+3*unit)
  assert(game.save.inventory.POTION==(frlg and 9 or 147));shot('native-sale-result-three');press('b')
  assert(game.stack:top()==root and root:selected().qty==(frlg and 9 or 48))
  if not frlg then
    local rows=require('src.inventory.Gen3RsInventory').rows(game.save,game.data,'ITEM')
    assert(rows[1].qty==99 and rows[2].qty==48)
  end
  select(root,'ANTIDOTE');press('a');sale=game.stack:top();assert(sale.mode=='confirm')
  shot('native-sale-single-skips-quantity');press('b');assert(game.stack:top()==root)
  local function pocket(key)
    for _=1,#root.pockets do if root.pockets[root.pocket].key==key then return end;press('right')end
    error('Missing own sale pocket '..key)
  end
  pocket('BALL');select(root,'MASTER_BALL');before=S.encode(game.save);press('a');sale=game.stack:top()
  assert(sale.mode=='cant');shot('native-sale-zero-price-refused');press('a');unchanged(before)
  local berry,tm
  if frlg then
    pocket('KEY_ITEM');select(root,'BERRY_POUCH');press('a');berry=game.stack:top()
    assert(getmetatable(berry)==require('src.ui.Gen3BerryPouch')and berry.sell)
    for _,row in ipairs(berry.rows)do assert(row.id~='BERRY_POUCH','The container is not a berry')end
  else pocket('BERRY');berry=root end
  select(berry,'ORAN_BERRY');before=S.encode(game.save);press('a');sale=game.stack:top()
  assert(getmetatable(sale)==UI and sale.max==(frlg and 99 or 999));press('down');assert(sale.qty==sale.max)
  shot('native-sale-berry-limit');press('b');unchanged(before)
  if frlg then
    press('b');assert(game.stack:top()==root);select(root,'TM_CASE');press('a');tm=game.stack:top()
    assert(getmetatable(tm)==require('src.ui.Gen3TMCase')and tm.sell)
    for i,id in ipairs{'HM01','HM03','TM01','TM03','TM39'}do assert(tm.rows[i].id==id)end
    assert(tm.rows[6].close);shot('native-sale-tm-case-order')
  else pocket('TM_HM');tm=root end
  select(tm,'TM01');press('a');sale=game.stack:top();assert(sale.mode=='quantity'and sale.max==2)
  shot('native-sale-tm-quantity');press('b')
  select(tm,'HM01');before=S.encode(game.save);press('a');sale=game.stack:top()
  assert(sale.mode=='cant');shot('native-sale-hm-refused');press('b');unchanged(before)
  if frlg then press('b');assert(game.stack:top()==root)end
  press('b');assert(game.stack:top()==menu);press('b');assert(game.stack:top()==world and quit==1)
  assert(game:writeSave()==true);local disk=assert(IO.load(v))
  assert(S.encode(disk.inventory)==S.encode(game.save.inventory)and disk.money==game.save.money)
  report.status='pass';report.ordinaryShopBagInputs=true;report.actualDiskRoundTrip=true
  report.drawPreservesSaveRng=true;report.cases.selectedStack=true;report.cases.cancelImmutable=true
  report.cases.zeroPriceAndHmRefused=true;report.cases.tmAndBerrySalesReachable=true
  if frlg then report.cases.nativeMachineOrder=true end
  persist();print('PASS_NATIVE_GBA_BAG_SALE');love.event.quit(0)
end
