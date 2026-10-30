-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared visual fixtures, separate from ordinary campaign saves.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local V=require('src.core.GameVersion');local edition=V.get()
 local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game);game.save.options.battleLayout='og'
 local P=require('src.pokemon.Pokemon');local S=require('src.core.SaveSerializer')
 local B=require('src.battle.BattleState');local G=require('src.battle.Gen3Battle')
 local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,
  captures={},placements={},nativeCoordinatesMatched=true}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(key,n)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(n or 4)end
 local function shot(name)
  local raw,rng=S.encode(game.save),love.math.getRandomState()
  local top=game.stack:top()
  local ok,why=require('src.render.GraphicsScope').call(top.draw,top);assert(ok,why)
  assert(raw==S.encode(game.save)and rng==love.math.getRandomState(),'Drawing changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local function settle(b)
  for _=1,6000 do
   if game.stack:top()==b and b.phase=='menu'and not b.current and #b.queue==0
    and not b.showPlayerBack and not b.showEnemyTrainer then return end
   if game.stack:top()==b and b.phase=='messages'then press('b')else U.wait(1)end
  end
  error('Prepared battle did not settle')
 end
 game.save.party={P.new(game.data,'BLASTOISE',40),P.new(game.data,'DODUO',20)}
 U.teleport(game,V.isFRLG()and'MAP_G03_N34'or'MAP_G00_N16',10,12,'up')
 local world=game.stack:top()
 local function measure(b,tag)
  local c=game.data.constants;local rows=b:isDouble()and c.gen3BattlerCoords.doubles or c.gen3BattlerCoords.singles
  for _,a in b:activeBattlers()do
   local img=b:picImage(a.sprite);assert(img:getWidth()==64 and img:getHeight()==64)
   local def=game.data.pokemon[a.mon.species]
   local body=a.isPlayer and def.backPicCoords or def.frontPicCoords
   local anchor=rows[a.position+1]
   local expectedX=anchor.x+G.fieldOffset(b)-32
   local expectedY=anchor.y+body.yOffset-(not a.isPlayer and(c.gen3Elevation or{})[a.mon.species]or 0)-32
   local x,y=G.picPlacement(b,a,img,a.sprite,1)
   local match=x==expectedX and y==expectedY
   report.nativeCoordinatesMatched=report.nativeCoordinatesMatched and match
   report.placements[#report.placements+1]={scene=tag,species=a.mon.species,position=a.position,
    actual={x,y},expected={expectedX,expectedY},matches=match}
  end
  shot(tag)
 end
 for _,species in ipairs{'SNORLAX','HAUNTER'}do
  local b=B.newWild(game,species,30);game.stack:push(b);settle(b)
  measure(b,'native-single-'..species:lower());game.stack:pop();U.wait(5)
 end
 local b=B.newWild(game,'SNORLAX',30)
 b:makeWildDouble(P.new(game.data,'HAUNTER',30));game.stack:push(b);settle(b)
 measure(b,'native-double-grounded-and-floating');game.stack:pop();U.wait(5)
 assert(game.stack:top()==world)
 -- Emerald's fresh opening suppresses area names until the introduction
 -- finishes. This separate prepared route fixture represents that later
 -- field state; it never changes the ordinary campaign checkpoint.
 if edition=='emerald'then game.save.flags.FLAG_G3_4000=nil end
 world.signLandmark=nil;world:updateMapNameSign();assert(world.mapNameSign,'Prepared map has no native popup')
 U.wait(24);shot('native-map-popup-clear')
 world.poisonFlash=8;shot('native-map-popup-poison-pulse')
 U.wait(24);shot('native-map-popup-after-poison')
 assert(report.nativeCoordinatesMatched,'Actual native battler frames differ from cartridge coordinates')
 report.drawPreservesSaveRng=true;report.status='pass';persist()
 print('PASS_NATIVE_GBA_FIELD_VISUAL_CAPTURE '..edition);love.event.quit(0)
end
