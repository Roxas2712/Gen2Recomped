-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared own-profile deposit fixture; it is not ordinary story progress.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(require('src.core.GameVersion').get()=='emerald')
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-emerald%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 game.save.inventory={};game.save.bagOrder={};game.save.gen3RsBagSlots=nil;game.save.pcItems={}
 local Bag=require('src.inventory.Bag');local Native=require('src.inventory.Gen3RsInventory')
 local UI=require('src.ui.Gen3BagMenu');local Qty=require('src.ui.Gen3EmeraldDepositQuantity')
 local S,IO=require('src.core.SaveSerializer'),require('src.core.SaveData')
 U.teleport(game,'MAP_G01_N01',4,2,'down');U.wait(60)
 local world=game.stack:top();local closed=0
 local report={status='running',edition='emerald',preparedFixture=true,continuousStory=false,captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(k)game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(32)end
 local function shot(name)
  local raw=S.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(raw==S.encode(game.save)and rng==love.math.getRandomState())
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 assert(Bag.add(game.save,'POTION',111,game.data));assert(Bag.add(game.save,'ORAN_BERRY',999,game.data))
 local owner=UI.new(game,{store='deposit',itemPc=true,onCancel=function()closed=closed+1 end})
 game.stack:push(owner);U.wait(40);assert(owner.emerald)
 local function pocket(key)
  for _=1,#owner.pockets do if owner.pockets[owner.pocket].key==key then return end;press('right')end
  error('Missing native pocket '..key)
 end
 pocket('ITEM');assert(owner.rows[1].id=='POTION'and owner.rows[2].qty==12)
 press('down');assert(owner:selected().rsSlot.index==2);press('a')
 local picker=game.stack:top();assert(getmetatable(picker)==Qty and picker.max==12)
 shot('native-emerald-deposit-quantity-01');press('down');assert(picker.qty==12)
 shot('native-emerald-deposit-wrap-selected-stack');press('up');press('right');assert(picker.qty==11)
 shot('native-emerald-deposit-plus-ten');press('b');assert(game.stack:top()==owner)
 assert(game.save.inventory.POTION==111 and game.save.pcItems.POTION==nil and picker.canvas==nil)
 local function result(name)
  assert(game.stack:top()~=owner);shot(name)
  for _=1,20 do if game.stack:top()==owner then break end;press('a')end
  assert(game.stack:top()==owner)
 end
 press('a');picker=game.stack:top();assert(getmetatable(picker)==Qty);press('right');press('a')
 assert(game.save.inventory.POTION==100 and game.save.pcItems.POTION==11)
 result('native-emerald-deposit-result');local rows=Native.rows(game.save,game.data,'ITEM')
 assert(rows[1].qty==99 and rows[2].qty==1);shot('native-emerald-deposit-preserves-first-stack')
 press('a');assert(getmetatable(game.stack:top())~=Qty,'Single item skips quantity selection')
 result('native-emerald-deposit-single-result')
 assert(game.save.inventory.POTION==99 and game.save.pcItems.POTION==12)
 pocket('BERRY');assert(owner:selected().id=='ORAN_BERRY');press('a')
 picker=game.stack:top();assert(getmetatable(picker)==Qty and picker.max==999)
 press('down');assert(picker.qty==999);shot('native-emerald-deposit-berry-999');press('a')
 result('native-emerald-deposit-berry-result')
 assert(game.save.inventory.ORAN_BERRY==nil and game.save.pcItems.ORAN_BERRY==999)
 assert(owner:selected().close);shot('native-emerald-deposit-last-berry-close')
 press('b');assert(game.stack:top()==world and closed==1 and owner.emeraldView==nil)
 assert(game:writeSave()==true);local disk=assert(IO.load('emerald'))
 assert(S.encode(disk.inventory)==S.encode(game.save.inventory))
 assert(S.encode(disk.pcItems)==S.encode(game.save.pcItems))
 assert(S.encode(disk.gen3RsBagSlots)==S.encode(game.save.gen3RsBagSlots))
 report.status='pass';report.actualDiskRoundTrip=true;report.selectedPhysicalStack=true
 report.ordinaryDepositInputs=true;report.drawPreservesSaveRng=true;report.fullPcParity=false
 persist();print('PASS_NATIVE_EMERALD_DEPOSIT_QUANTITY');love.event.quit(0)
end
