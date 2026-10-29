-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared own-cartridge layout/input fixture; never an ordinary story save.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local V=require('src.core.GameVersion');assert(V.get()=='emerald')
 local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-emerald%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 game.save.inventory={};game.save.bagOrder={};game.save.gen3RsBagSlots=nil;game.save.player.gender='boy'
 local Bag=require('src.inventory.Bag');local UI=require('src.ui.Gen3BagMenu')
 local S=require('src.core.SaveSerializer');local IO=require('src.core.SaveData')
 U.teleport(game,'MAP_G01_N01',4,2,'down');U.wait(60)
 local world=game.stack:top();local owner;local closed=0
 local report={status='running',edition='emerald',preparedFixture=true,continuousStory=false,captures={},clockSeconds=0}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(k)
  game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(32)
 end
 local function shot(name)
  local raw=S.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(raw==S.encode(game.save)and rng==love.math.getRandomState(),'Drawing changed save or RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local function open()
  owner=UI.new(game,{onCancel=function()closed=closed+1 end});game.stack:push(owner);U.wait(40)
  assert(owner.emerald and owner:listRows()==8 and not owner:wantsEdgeBleed())
  local w,h=owner:uiSize();assert(w==240 and h==160)
 end
 local function sameExceptClock(raw)
  local a,b=assert(S.decode(raw)),assert(S.decode(S.encode(game.save)))
  local elapsed=IO.playSeconds(b)-IO.playSeconds(a);assert(elapsed>=0 and elapsed<180)
  report.clockSeconds=report.clockSeconds+elapsed;a.playTime,b.playTime=0,0
  assert(S.encode(a)==S.encode(b),'Navigation changed more than the accounted play clock')
 end
 open();assert(#owner.rows==1 and owner:selected().close)
 local before=S.encode(game.save);shot('native-emerald-bag-empty-close');press('a')
 assert(game.stack:top()==world and closed==1);sameExceptClock(before)
 local items,keys={},{}
 for id,def in pairs(game.data.items)do
  if def.pocket=='ITEM'and(tonumber(def.index)or 0)>0 and not def.keyItem
   and(tonumber(def.importance)or 0)==0 then items[#items+1]=id end
  if def.pocket=='KEY_ITEM'and(tonumber(def.registrability)or 0)>0 then keys[#keys+1]=id end
 end
 local function byIndex(a,b)return game.data.items[a].index<game.data.items[b].index end
 table.sort(items,byIndex);table.sort(keys,byIndex);assert(#items>=12 and#keys>0)
 for i=1,12 do assert(Bag.add(game.save,items[i],1,game.data),'Cannot prepare own real item '..items[i])end
 for _,entry in ipairs{{'POKE_BALL',12},{'ORAN_BERRY',999},{'TM01',1},{'HM01',1},{keys[1],1}}do
  assert(Bag.add(game.save,entry[1],entry[2],game.data))
 end
 open();before=S.encode(game.save);shot('native-emerald-bag-boy-single-quantities')
 press('a');local action=game.stack:top()
 assert(getmetatable(action)==require('src.ui.Gen3ItemMenu')and action.emeraldBag==owner)
 local index=action.index;press('left');assert(action.index==index)
 shot('native-emerald-bag-item-actions');press('b');assert(game.stack:top()==owner)
 for _=1,8 do press('down')end
 assert(owner.index==9 and owner.top==2);shot('native-emerald-bag-scroll-eight-rows')
 local function pocket(key)
  for _=1,#owner.pockets do
   if owner.pockets[owner.pocket].key==key then return end
   press('right')
  end
  error('Missing native pocket '..key)
 end
 pocket('BALL');shot('native-emerald-bag-ball-frame')
 pocket('TM_HM');shot('native-emerald-bag-tm-hm-numbers')
 assert(owner.rows[1].id=='TM01'and owner.rows[2].id=='HM01')
 press('a');action=game.stack:top();assert(action.emeraldBag==owner)
 shot('native-emerald-bag-tm-move-info');press('b');assert(game.stack:top()==owner)
 pocket('BERRY');assert(owner.rows[1].qty==999);shot('native-emerald-bag-berry-number-quantity')
 press('a');action=game.stack:top();assert(action.emeraldBag==owner and#action.entries==6)
 shot('native-emerald-bag-berry-actions');press('b');assert(game.stack:top()==owner)
 pocket('KEY_ITEM');assert(owner:selected().id==keys[1]);sameExceptClock(before)
 press('select');assert(game.save.registeredItem==keys[1]);shot('native-emerald-bag-registered-select')
 press('a');action=game.stack:top();assert(action.emeraldBag==owner)
 shot('native-emerald-bag-deselect-actions');press('b');assert(game.stack:top()==owner)
 before=S.encode(game.save);press('b');assert(game.stack:top()==world and closed==2);sameExceptClock(before)
 assert(owner.emeraldView==nil,'Closing releases the owned native canvas and quads')
 game.save.player.gender='girl';open();pocket('ITEM');before=S.encode(game.save)
 shot('native-emerald-bag-girl-own-palette');press('b')
 assert(game.stack:top()==world and closed==3 and owner.emeraldView==nil);sameExceptClock(before)
 assert(game:writeSave()==true);local disk=assert(IO.load('emerald'))
 assert(S.encode(disk.inventory)==S.encode(game.save.inventory)and disk.registeredItem==keys[1]and disk.player.gender=='girl')
 report.status='pass';report.ordinaryBagInputs=true;report.actualDiskRoundTrip=true
 report.drawPreservesSaveRng=true;report.emptyAndLongLists=true;report.maleAndFemaleOwnGraphics=true
 report.fullBagVisualParity=false;report.remainingViews={'PC quantity flow','pocket switch animation','native scroll and reorder behavior'}
 persist();print('PASS_NATIVE_EMERALD_BAG_LIST');love.event.quit(0)
end
