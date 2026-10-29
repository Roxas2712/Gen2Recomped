-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared own-cartridge fixture; actual action menu, input, renderer and IO.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local version=V.get()
  assert(version=='emerald'or version=='firered'or version=='leafgreen')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..version..'%-'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  local Bag=require('src.inventory.Bag');local S=require('src.core.SaveSerializer')
  local IO=require('src.core.SaveData');local UI=require('src.ui.Gen3BagToss')
  assert(UI.available(game),'Own native toss text/fonts are incomplete')
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'MAGIKARP',5)}
  game.save.inventory={};game.save.bagOrder={}
  for id,qty in pairs{POTION=12,ANTIDOTE=1,ORAN_BERRY=999}do
    assert(Bag.add(game.save,id,qty,game.data),'Could not prepare own bag item '..id)
  end
  game.save.options.gen3Frame=1
  U.teleport(game,version=='emerald'and'MAP_G01_N01'or'MAP_G04_N00',4,2,'down');U.wait(60)
  local world=game.stack:top()
  local report={status='running',edition=version,preparedFixture=true,continuousStory=false,
    captures={},cases={},clockSeconds=0}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(8)
  end
  local function shot(name)
    local before=S.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
    assert(require('src.render.GraphicsScope').call(top.draw,top))
    assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Native bag toss draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function unchanged(raw)
    local a,b=assert(S.decode(raw)),assert(S.decode(S.encode(game.save)))
    local dt=IO.playSeconds(b)-IO.playSeconds(a);assert(dt>=0 and dt<120)
    report.clockSeconds=report.clockSeconds+dt;a.playTime,b.playTime=0,0
    assert(S.encode(a)==S.encode(b),'Cancel changed a persistent field other than the accounted play clock')
  end
  local function bag(id,berry)
    local owner
    if berry and version~='emerald'then owner=require('src.ui.Gen3BerryPouch').new(game,{})
    else owner=require('src.ui.Gen3BagMenu').new(game,{pocket=berry and'BERRY'or'ITEM'})end
    game.stack:push(owner);U.wait(10)
    for _=1,#owner.rows+1 do
      local row=owner.rows[owner.index];if row and row.id==id then break end;press('down')
    end
    assert(owner.rows[owner.index].id==id,'Ordinary bag cursor could not select '..id)
    return owner
  end
  local function toss(owner)
    press('a');local menu=game.stack:top()
    assert(getmetatable(menu)==require('src.ui.Gen3ItemMenu'),'Original item action menu missing')
    local target;for i,row in ipairs(menu.entries)do if row.kind=='toss'then target=i end end
    assert(target,'Selected ordinary item has no TOSS action')
    local cols=menu.columns
    if (menu.index-1)%cols~=(target-1)%cols then press('right')end
    for _=1,menu.rows do
      if menu.index==target then break end;press('down')
    end
    assert(menu.index==target,'Ordinary action input did not reach TOSS')
    press('a');local state=game.stack:top();assert(getmetatable(state)==UI and state.owner==owner)
    return state
  end
  local owner=bag('POTION');local state=toss(owner);local before=S.encode(game.save)
  assert(state.mode=='quantity'and state.qty==1);press('down');assert(state.qty==1)
  press('right');press('right');assert(state.qty==3);shot('native-bag-toss-quantity-three')
  press('b');assert(game.stack:top()==owner);unchanged(before)
  state=toss(owner);before=S.encode(game.save);press('a');assert(state.mode=='confirm')
  press('down');assert(state.index==2);shot('native-bag-toss-confirm-no')
  press('a');assert(game.stack:top()==owner);unchanged(before)
  state=toss(owner);before=S.encode(game.save);press('a');press('b')
  assert(game.stack:top()==owner);unchanged(before)
  state=toss(owner);press('right');press('right');press('a');shot('native-bag-toss-confirm-yes')
  press('a');assert(state.mode=='done'and not state.committed and game.save.inventory.POTION==12)
  shot('native-bag-toss-result-three');press('a');assert(game.stack:top()==owner)
  assert(state.committed and game.save.inventory.POTION==9)
  assert(owner.rows[owner.index].qty==9,'Bag did not rebuild the actual item count');press('b')
  assert(game.stack:top()==world)
  owner=bag('ANTIDOTE');state=toss(owner);assert(state.mode=='confirm'and state.max==1)
  before=S.encode(game.save);shot('native-bag-toss-single-skips-quantity');press('b');unchanged(before)
  state=toss(owner);press('a');assert(state.mode=='done'and game.save.inventory.ANTIDOTE==1)
  press('b');assert(state.committed and game.stack:top()==owner and game.save.inventory.ANTIDOTE==nil)
  assert(owner.rows[owner.index]and owner.rows[owner.index].id~='ANTIDOTE','Last-item removal left a stale bag row/cursor')
  press('b')
  game.save.options.gen3Frame=version=='emerald'and 20 or 10
  owner=bag('ORAN_BERRY',true);state=toss(owner);before=S.encode(game.save)
  -- The boundary view is a prepared UI selection, not an inventory mutation.
  state.qty=999;state:refreshMessage();shot('native-bag-toss-berry-999-last-frame')
  press('up');assert(state.qty==999);press('b');unchanged(before);press('b')
  assert(game.stack:top()==world and game.save.inventory.ORAN_BERRY==999 and game.save.inventory.ANTIDOTE==nil)
  assert(game:writeSave()==true);local loaded=assert(IO.load(version))
  assert(S.encode(loaded.inventory)==S.encode(game.save.inventory),'Actual save/load lost the selected toss result')
  report.cases={quantityCancelPreservesSave=true,noPreservesSave=true,bPreservesSave=true,
    selectedQuantityCommittedOnce=true,nativeCountAndFrames=true,threeDigitBerryAndPouch=true,
    oneItemSkipsQuantity=true,lastItemRemovalAndCursorValid=true,bagRebuildAndReturn=true,actualDiskRoundTrip=true}
  report.drawPreservesSaveRng=true;report.status='pass';persist()
  print('PASS_NATIVE_GBA_BAG_TOSS');love.event.quit(0)
end
