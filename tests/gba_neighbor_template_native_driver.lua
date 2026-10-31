-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared historical-template regression, not an ordinary story checkpoint.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local edition=require('src.core.GameVersion').get();assert(edition=='ruby'or edition=='sapphire')
 local out=assert(os.getenv('EDITION_QA_OUT'));local S=require('src.core.SaveSerializer')
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 local route=game.data.maps.MAP_G00_N24;local briney
 for _,obj in ipairs(route.objects)do if obj.index==2 then briney=obj end end
 assert(briney and briney.x==21 and briney.y==24,'Unexpected own Route109 object template')
 game.save.flags[briney.eventFlag]=nil
 game.save.gen3ObjectHomes={MAP_G00_N24={[2]={x=12,y=6}}}
 local town=require('src.world.MapLoader').load(game.data,'MAP_G00_N01')
 U.teleport(game,'MAP_G00_N01',18,town.heightCells-1,'down');U.wait(30)
 local world=game.overworld
 local npc=assert(world.npcPool.MAP_G00_N24_obj_2)
 assert(npc.cellX==21 and npc.cellY==24,'Neighbor reused the historical home before its entry reset')
 local function step(dir)
  local p=world.player;local x,y=p.cellX,p.cellY
  game.input:overlayPressed(dir)
  for _=1,90 do if p.moving or p.cellX~=x or p.cellY~=y then break end;U.wait(1)end
  game.input:overlayReleased(dir)
  for _=1,90 do if not p.moving then break end;U.wait(1)end
  U.wait(8)
 end
 step('down');U.wait(60)
 assert(world.map.id=='MAP_G00_N24','Normal south seam did not enter Route109')
 assert(game.save.gen3ObjectHomes.MAP_G00_N24==nil,'Fresh route entry did not reset its templates')
 assert(world.npcPool.MAP_G00_N24_obj_2==npc,'Ordinary seam unnecessarily replaced a live neighboring actor')
 assert(npc.cellX==21 and npc.cellY==24)
 for _=1,6 do step('down')end
 for _=1,6 do step('left')end
 assert(world.player.cellX==12 and world.player.cellY==6,'Ordinary walking could not reach the previously blocked entrance')
 local captures={}
 local function shot(name)
  local before,rng=S.encode(game.save),love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Neighbor draw changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));captures[#captures+1]=name
 end
 shot('route109-original-seashore-door-clear')
 step('up');U.wait(180)
 assert(world.map.id=='MAP_G28_N00'and game.stack:top()==world,'Ordinary up input did not enter the Seashore House')
 shot('route109-entered-seashore-house')
 local report={status='pass',edition=edition,preparedFixture=true,continuousStory=false,
  staleTemplate={x=12,y=6},nativeBriney={x=21,y=24},normalSeamAndDoorInputs=true,
  liveActorOwnerPreserved=true,drawPreservesSaveRng=true,captures=captures}
 local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()
 print('PASS_NATIVE_GBA_NEIGHBOR_TEMPLATE '..edition);love.event.quit(0)
end
