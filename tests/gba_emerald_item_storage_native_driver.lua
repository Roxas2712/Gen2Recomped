-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared own-profile PC fixture; it is not ordinary story progress.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local out=assert(os.getenv('EDITION_QA_OUT'));assert(require('src.core.GameVersion').get()=='emerald')
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-emerald%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 game.save.inventory={};game.save.bagOrder={};game.save.gen3RsBagSlots=nil
 game.save.pcItems={POTION=12,ANTIDOTE=3,ORAN_BERRY=999};game.save.pcOrder={'POTION','ANTIDOTE','ORAN_BERRY'}
 local Bag=require('src.inventory.Bag');assert(Bag.add(game.save,'POTION',98,game.data))
 local extra={}
 for id,def in pairs(game.data.items)do
  if def.pocket=='ITEM'and(tonumber(def.index)or 0)>0 and not def.keyItem
   and(tonumber(def.importance)or 0)==0 and not game.save.pcItems[id]then extra[#extra+1]=id end
 end
 table.sort(extra,function(a,b)return game.data.items[a].index<game.data.items[b].index end)
 assert(#extra>=10)
 for i=1,10 do local id=extra[i];game.save.pcItems[id]=1;game.save.pcOrder[#game.save.pcOrder+1]=id end
 U.teleport(game,'MAP_G01_N01',4,2,'down');U.wait(60);local world=game.stack:top()
 local M=require('src.ui.Gen3EmeraldItemStorage');local S,IO=require('src.core.SaveSerializer'),require('src.core.SaveData')
 local report={status='running',edition='emerald',preparedFixture=true,continuousStory=false,captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(k)game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(32)end
 local function shot(name)
  local raw=S.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(raw==S.encode(game.save)and rng==love.math.getRandomState())
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local Commands=require('src.script.Gen3Commands');local resumes,yields=0,0
 local ctx={game=game,save=game.save,runner={resume=function()resumes=resumes+1 end,
  yield=function()yields=yields+1 end}}
 Commands.SPECIALS[265](ctx);local root=game.stack:top()
 assert(root.emeraldPcPresenter and #root.items==3);shot('emerald-center-pc-root')
 press('down');press('a');assert(game.stack:top()==world and game.save.gen3Vars[Commands.VAR_RESULT]==1)
 assert(resumes==1 and yields==1,'Root must resume its script owner exactly once')
 game.save.options.gen3Frame=20
 Commands.SPECIALS[265](ctx);shot('emerald-center-pc-last-frame');press('b')
 assert(game.stack:top()==world and game.save.gen3Vars[Commands.VAR_RESULT]==Commands.MULTI_B_PRESSED)
 assert(resumes==2 and yields==2,'Root B must preserve the raw cartridge cancel result')
 game.save.options.gen3Frame=1
 game.stack:push(require('src.ui.Gen3PlayerPC').new(game,{order='bedroom'}));U.wait(20)
 shot('emerald-player-pc-menu')
 press('a');local menu=game.stack:top();shot('emerald-item-storage-menu')
 press('a');local withdraw=game.stack:top()
 assert(getmetatable(withdraw)==M and withdraw.ui.state=='list'and menu.hidden);shot('native-emerald-pc-withdraw-list')
 press('a');assert(withdraw.ui.state=='quantity');shot('native-emerald-pc-quantity-001')
 press('right');assert(withdraw.ui.quantity==11);shot('native-emerald-pc-plus-ten');press('b')
 assert(game.save.pcItems.POTION==12 and game.save.inventory.POTION==98)
 press('a');press('right');press('a');assert(withdraw.ui.state=='remove')
 assert(game.save.pcItems.POTION==1 and game.save.inventory.POTION==109)
 shot('native-emerald-pc-withdraw-result');press('a');assert(game.save.pcItems.POTION==1)
 press('a');assert(withdraw.ui.state=='remove'and game.save.pcItems.POTION==nil)
 shot('native-emerald-pc-single-withdraw-result');press('a')
 assert(game.save.inventory.POTION==110 and withdraw.ui.state=='list')
 for _=1,8 do press('down')end
 assert(withdraw.ui.scroll>0);shot('native-emerald-pc-long-list-scroll')
 for _=1,8 do press('up')end
 local before=S.encode(game.save.pcItems);press('select');assert(withdraw.ui.state=='swap')
 shot('native-emerald-pc-select-reorder');press('down');press('down');press('a')
 assert(game.save.pcOrder[1]=='ORAN_BERRY'and S.encode(game.save.pcItems)==before)
 press('b');assert(game.stack:top()==menu and withdraw.canvas==nil and not menu.hidden)
 press('down');press('down');press('a');local toss=game.stack:top()
 assert(getmetatable(toss)==M and toss.ui._toss)
 press('a');press('down');assert(toss.ui.quantity==999);shot('native-emerald-pc-berry-999')
 press('b');assert(game.save.pcItems.ORAN_BERRY==999)
 press('a');press('right');press('a');assert(toss.ui.state=='yesno')
 shot('native-emerald-pc-toss-yes-no');press('down');press('a');assert(game.save.pcItems.ORAN_BERRY==999)
 press('a');press('right');press('a');press('a');assert(toss.ui.state=='remove')
 assert(game.save.pcItems.ORAN_BERRY==988);shot('native-emerald-pc-toss-result');press('a')
 assert(game.save.pcItems.ORAN_BERRY==988)
 press('b');assert(game.stack:top()==menu and toss.canvas==nil)
 press('b');press('b');assert(game.stack:top()==world)
 assert(game:writeSave()==true);local disk=assert(IO.load('emerald'))
 for _,key in ipairs{'inventory','pcItems','pcOrder','gen3RsBagSlots'}do assert(S.encode(disk[key])==S.encode(game.save[key]))end
 report.status='pass';report.actualDiskRoundTrip=true;report.nativePcMenuRoutes=true
 report.realWithdrawTossReorderCallbacks=true;report.drawPreservesSaveRng=true;report.fullPcParity=false
 persist();print('PASS_NATIVE_EMERALD_ITEM_STORAGE');love.event.quit(0)
end
