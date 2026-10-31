-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared component visuals; separate from ordinary campaign saves.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local V=require('src.core.GameVersion');local edition=V.get();assert(V.isFRLG())
 local out=assert(os.getenv('EDITION_QA_OUT'));assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 local P=require('src.pokemon.Pokemon');local S=require('src.core.SaveSerializer')
 local Native=require('src.world.Gen3FieldMove');local A=require('src.import.Gen3FrlgPlayerAssets')
 assert(A.valid(game.data.constants.gen3PlayerSprites,game.data.constants.gen3SurfBlob,edition))
 local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={},forms={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function shot(name)
  local save,rng=S.encode(game.save),love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(save==S.encode(game.save)and rng==love.math.getRandomState(),'Drawing changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 game.save.party={P.new(game.data,'BLASTOISE',40)}
 for _,gender in ipairs{'boy','girl'}do
  game.save.player.gender=gender
  U.teleport(game,'MAP_G03_N00',8,15,'down');U.wait(30)
  local world=game.stack:top();local player=world.player;player:refreshForm(game.data)
  local prefix='native-'..gender..'-'
  assert(player.walkId==nil or player.walkId==('SPRITE_G3_%03d'):format(gender=='boy'and 0 or 7))
  shot(prefix..'walk')
  game.save.onBike=true;player.onBike=true;U.wait(2);shot(prefix..'bike')
  game.save.onBike=false;player.onBike=false
  U.teleport(game,'MAP_G03_N00',8,17,'down');U.wait(30);world=game.stack:top();player=world.player
  player.surfing=true;player:refreshForm(game.data)
  assert(player.surfId==('SPRITE_G3_%03d'):format(gender=='boy'and 2 or 9),'Wrong native gender ride sheet')
  assert(player.fieldMoveId==('SPRITE_G3_%03d'):format(gender=='boy'and 3 or 10),'Wrong native field pose sheet')
  local blob=assert(player:surfBlobCard('down'));assert(blob.frames==6 and blob.paletteSource=='FRLG player OBJ palette slot 0')
  for _,facing in ipairs{'down','up','right'}do player.facing=facing;U.wait(2);shot(prefix..'surf-'..facing)end
  player.surfing=false
  U.teleport(game,'MAP_G03_N00',8,15,'down');U.wait(30);world=game.stack:top();player=world.player
  local completed=0;local shown,state=Native.show(game,game.save.party[1],function()completed=completed+1 end)
  assert(shown and player.fieldMove and player.fieldMoveSprite,'Native field presentation did not install its own pose')
  U.wait(10);assert(player.fieldMove and(player.fieldMovePose or 0)>0)
  shot(prefix..'field-move-pose');U.wait(7)
  assert(player.fieldMovePose==4,'Native FRLG pose did not reach its original held frame')
  shot(prefix..'field-move-held');U.wait(200)
  assert(game.stack:top()==world and not player.fieldMove and completed==1,'Native pose did not complete and restore')
  report.forms[gender]={surf=player.surfId,fieldMove=player.fieldMoveId,completed=true};persist()
 end
 report.drawPreservesSaveRng=true;report.status='pass';persist()
 print('PASS_NATIVE_FRLG_PLAYER_FORMS '..edition);love.event.quit(0)
end
