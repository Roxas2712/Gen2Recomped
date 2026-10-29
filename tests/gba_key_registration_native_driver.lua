-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared own-cartridge UI fixture, not an ordinary story checkpoint.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local version=V.get()
  assert(V.isGen3())
  local rs=version=='ruby'or version=='sapphire'
  if V.isFRLG()then
    assert(require('src.import.Gen3BagRegistrationAssets').valid(game.data.constants.gen3BagScreen.registered,version),
      'Native registered-item badge is missing')
  end
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..version..'%-'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  local Bag=require('src.inventory.Bag');local UI=require('src.ui.Gen3BagMenu')
  local S=require('src.core.SaveSerializer');local IO=require('src.core.SaveData')
  local ids={}
  for id,def in pairs(game.data.items)do
    if def.pocket=='KEY_ITEM'and id~='TM_CASE'and id~='BERRY_POUCH'then ids[#ids+1]=id end
  end
  table.sort(ids,function(a,b)return game.data.items[a].index<game.data.items[b].index end)
  local registrable,quest
  for _,id in ipairs(ids)do
    local byte=assert(game.data.items[id].registrability,'Own extraction did not read registrability')
    if byte>0 then registrable=registrable or id else quest=quest or id end
  end
  assert(registrable and quest,'Own cartridge must distinguish both key-item classes')
  game.save.inventory={};game.save.bagOrder={}
  assert(Bag.add(game.save,registrable,1,game.data));assert(Bag.add(game.save,quest,1,game.data))
  U.teleport(game,V.isFRLG()and'MAP_G04_N00'or'MAP_G01_N01',4,2,'down');U.wait(60)
  local world=game.stack:top();local report={status='running',edition=version,preparedFixture=true,
    continuousStory=false,captures={},registrableId=registrable,questItemId=quest}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(k)
    game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(32)
  end
  local function shot(name)
    local raw=S.encode(game.save);local rng=love.math.getRandomState();local state=game.stack:top()
    assert(require('src.render.GraphicsScope').call(state.draw,state))
    assert(raw==S.encode(game.save)and rng==love.math.getRandomState())
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local owner=UI.new(game,{pocket='KEY_ITEM'});game.stack:push(owner);U.wait(40)
  local function select(id)
    -- RS clamps at the last row; it does not wrap down to the first item.
    -- Reach the known list start with ordinary UP input before searching.
    for _=1,#owner.rows do if owner.index==1 then break end;press('up')end
    for _=1,#owner.rows+1 do if owner:selected().id==id then return end;press('down')end
    error('Ordinary input could not find own key item')
  end
  select(quest);press('a')
  local action=game.stack:top();assert(getmetatable(action)==require('src.ui.Gen3ItemMenu'))
  local hasRegister=false;for _,row in ipairs(action.entries)do if row.kind=='register'then hasRegister=true end end
  assert(hasRegister==rs,'Quest-item REGISTER disagrees with the edition contract')
  shot('native-key-quest-actions');press('b');assert(game.stack:top()==owner)
  if not rs then
    press('select');assert(game.save.registeredItem==nil)
  end
  select(registrable)
  if rs then
    press('a');local menu=game.stack:top()
    local target;for i,row in ipairs(menu.entries)do if row.kind=='register'then target=i end end
    assert(target);press('right');assert(menu.index==target);press('a')
  else press('select')end
  assert(game.stack:top()==owner and game.save.registeredItem==registrable)
  if rs then
    press('select');assert(owner.rsSwap==owner.index and game.save.registeredItem==registrable)
    press('b');assert(owner.rsSwap==nil and game.save.registeredItem==registrable)
    report.rsSelectStartsReorder=true
  end
  shot('native-key-registered-badge');press('a');action=game.stack:top()
  local deselect=false
  for _,row in ipairs(action.entries)do
    if row.kind=='register'then
      deselect=row.label==game.data.constants.gen3ItemMenu.labels[game.data.constants.gen3ItemMenu.deselect]
    end
  end
  if not rs then assert(deselect)end
  shot(rs and'native-key-registered-action'or'native-key-deselect-action');press('b')
  assert(game:writeSave()==true);local loaded=assert(IO.load(version))
  assert(loaded.registeredItem==registrable,'Actual disk save lost registered stable ID')
  assert(S.encode(loaded.inventory)==S.encode(game.save.inventory))
  if not rs then press('select');assert(game.save.registeredItem==nil);shot('native-key-select-cleared')end
  assert(game.save.inventory[registrable]==1 and game.save.inventory[quest]==1)
  press('b');assert(game.stack:top()==world)
  report.status='pass';report.actualDiskRoundTrip=true;report.ordinaryBagInputs=true
  report.drawPreservesSaveRng=true
  persist();print('PASS_NATIVE_GBA_KEY_REGISTRATION');love.event.quit(0)
end
