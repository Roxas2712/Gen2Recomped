-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared own-cartridge integration acceptance, never an ordinary campaign.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local V=require('src.core.GameVersion');local edition=V.get()
 local out=assert(os.getenv('EDITION_QA_OUT'));local S=require('src.core.SaveSerializer')
 assert(require('src.import.RomImporter').readyReport(edition).ok,'Fresh import is incomplete')
 local record=assert(game.data.constants.gen3Pickup,'Fresh import omitted Pickup tables')
 assert(record.edition==edition and record.romSha1==V.info(edition).sha1)
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 U.teleport(game,V.isFRLG()and'MAP_G04_N00'or'MAP_G01_N01',4,2,'down');U.wait(60)
 local species
 for id,def in pairs(game.data.pokemon)do
  if def.abilities and def.abilities[1]=='PICKUP'then species=id;break end
 end
 assert(species,'Own species data has no Pickup ability')
 local P=require('src.pokemon.Pokemon');local Battle=require('src.battle.BattleState')
 local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,
  freshOwnImport=true,cases={},captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function shot(name)
  local before,rng=S.encode(game.save),love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Pickup party draw changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 for _,case in ipairs{{name='common',level=1,roll=0},{name='last-slot',level=100,roll=99}}do
  local mon=P.new(game.data,species,case.level);mon.item=nil;mon.abilitySlot=1
  game.save.party={mon}
  local world=game.stack:top();local calls=0
  local battle=Battle.newWild(game,'PIKACHU',5)
  battle.rng=function(lo,hi)
   assert(lo==0 and hi==65535);calls=calls+1;return calls==1 and 0 or case.roll
  end
  battle.result='win';game.stack:push(battle);battle:finish();U.wait(180)
  assert(calls==2 and game.stack:top()==world,'Pickup did not finish once with two original raw rolls')
  local item=assert(mon.item,'No original Pickup item was awarded')
  assert(game.data.items[item],'Pickup persisted a numeric/unknown held item')
  local index=game.data.items[item].index
  local expected=record.style=='fixed'and(case.roll==0 and record.items[1]or record.items[#record.items])
    or(case.roll==0 and record.common[1]or record.rare[10])
  assert(index==expected,'Native party holds the wrong imported table entry')
  local party=require('src.ui.Gen3PartyMenu').new(game,{})
  game.stack:push(party);U.wait(100);shot('pickup-'..case.name..'-held-party')
  local before=game.save.inventory[item]or 0
  party:takeItem(mon);U.wait(120)
  assert(mon.item==nil and game.save.inventory[item]==before+1,'Ordinary Take handler did not transfer the found item exactly once')
  shot('pickup-'..case.name..'-take-result')
  report.cases[#report.cases+1]={name=case.name,level=case.level,species=species,
   item=item,index=index,rngCalls=calls,normalTakeHandler=true};persist()
  game.input:overlayPressed('a');U.wait(1);game.input:overlayReleased('a');U.wait(60)
  game.input:overlayPressed('b');U.wait(1);game.input:overlayReleased('b');U.wait(60)
  assert(game.stack:top()==world,'Party Take did not return to the same field owner')
 end
 report.drawPreservesSaveRng=true;report.status='pass';persist()
 print('PASS_NATIVE_GBA_PICKUP '..edition);love.event.quit(0)
end
