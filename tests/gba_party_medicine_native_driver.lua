-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared renderer baseline; successful capture is not a visual parity verdict.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local V=require('src.core.GameVersion');local edition=V.get()
 assert(edition=='emerald'or V.isFRLG())
 local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 U.teleport(game,V.isFRLG()and'MAP_G04_N00'or'MAP_G01_N01',4,2,'down');U.wait(60)
 local P=require('src.pokemon.Pokemon');local S=require('src.core.SaveSerializer')
 local Party=require('src.ui.Gen3PartyMenu');local Bag=require('src.ui.Gen3BagMenu')
 local world=game.stack:top();game.save.party={}
 for _,entry in ipairs{{'BULBASAUR',18},{'PIKACHU',12},{'PIDGEY',15},{'GEODUDE',16},{'MAGIKARP',10},{'CATERPIE',6}}do
  game.save.party[#game.save.party+1]=P.new(game.data,entry[1],entry[2])
 end
 local first,second=game.save.party[1],game.save.party[2]
 first.hp=first.stats.hp-15;second.status='PAR'
 game.save.inventory={POTION=3,PARLYZ_HEAL=2};game.save.gen3RsBagSlots=nil;game.save.bagOrder={'POTION','PARLYZ_HEAL'}
 local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,
  baselineCapture=true,visualParityAccepted=false,captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(k,n)game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(n or 30)end
 local function shot(name)
  local raw=S.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(raw==S.encode(game.save)and rng==love.math.getRandomState(),'Party draw changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local party=Party.new(game,{});game.stack:push(party);U.wait(90)
 report.nativePartyPresenter=party.rsNative~=nil or party.gbaNative~=nil
 assert(party.gbaNative,'Native field party presenter missing')
 shot('party-six-members-lead');press('right');assert(party.index==2)
 shot('party-status-second-member');press('a');assert(party.submenu)
 shot('party-native-actions');press('b');assert(not party.submenu)
 press('b');assert(game.stack:top()==world)
 local bag=Bag.new(game,{});game.stack:push(bag);U.wait(90)
 assert(bag:selected().id=='POTION');press('a');press('a',90)
 local picker=game.stack:top();assert(getmetatable(picker)==Party and picker.keepOpen)
 shot('party-medicine-target');press('a',360)
 assert(first.hp==first.stats.hp and second.status=='PAR'and game.save.inventory.POTION==2)
 assert(getmetatable(game.stack:top())==require('src.render.TextBox'))
 shot('party-medicine-result');press('a',60);assert(game.stack:top()==bag)
 -- Status medicine must retain the same picker through its own native result.
 while bag:selected().id~='PARLYZ_HEAL'do press('down')end
 press('a');press('a',90);picker=game.stack:top()
 assert(getmetatable(picker)==Party and picker.keepOpen and picker.gbaNative)
 press('right');assert(picker.index==2);press('a',180)
 assert(second.status==nil and game.save.inventory.PARLYZ_HEAL==1)
 assert(game.stack:top().gbaPartyOwner==picker)
 shot('party-paralysis-second-result');press('a',60);assert(game.stack:top()==bag)
 press('b',60);assert(game.stack:top()==world)
 report.status='pass';report.functionalMedicinePass=true;report.drawPreservesSaveRng=true
 persist();print('PASS_GBA_PARTY_BASELINE_CAPTURE '..edition);love.event.quit(0)
end
