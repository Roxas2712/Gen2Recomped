-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared warp components; ordinary Mansion failure is retained separately.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local V=require('src.core.GameVersion');local edition=V.get();assert(V.isFRLG())
 local out=assert(os.getenv('EDITION_QA_OUT'));assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 local S=require('src.core.SaveSerializer')
 game.save.party={require('src.pokemon.Pokemon').new(game.data,'BLASTOISE',40)}
 local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,stairs={},captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(k)game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(150)end
 local function shot(name)
  local save,rng=S.encode(game.save),love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top));assert(save==S.encode(game.save)and rng==love.math.getRandomState())
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 for _,row in ipairs{{'MAP_G01_N59',10,13,0xEC,'right'},
  {'MAP_G01_N05',3,8,0xED,'left'},{'MAP_G01_N06',2,2,0xEE,'right'},
  {'MAP_G01_N59',25,27,0xEF,'left'}}do
  local map,x,y,b,dir=unpack(row);U.teleport(game,map,x,y,dir);U.wait(90)
  local world=game.stack:top();assert(world.map:cellBehaviour(x,y)==b and world.map:arrowWarpDirAt(x,y)==dir)
  local w=assert(world.map:warpAtCell(x,y));local destination=w.def.destMap
  press('up');assert(world.map.id==map,'A wrong-direction press activated a side stair')
  U.teleport(game,map,x,y,dir);U.wait(90);world=game.stack:top()
  press(dir);assert(world.map.id==destination,'Normal directional input did not take its original side stair')
  local name=('native-stair-%02x-%s-arrival'):format(b,dir);shot(name)
  report.stairs[#report.stairs+1]={map=map,x=x,y=y,behavior=b,direction=dir,destination=destination,
   arrival={x=world.player.cellX,y=world.player.cellY},wrongDirectionIgnored=true};persist()
 end
 report.drawPreservesSaveRng=true;report.status='pass';persist()
 print('PASS_NATIVE_FRLG_DIRECTIONAL_STAIRS '..edition);love.event.quit(0)
end
