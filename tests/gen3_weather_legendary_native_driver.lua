-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared field; the actual special, VM, battle transition and renderer.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local edition=V.get()
  assert(edition=='ruby'or edition=='sapphire'or edition=='emerald')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'SCEPTILE',48)}
  game.save.options.battleLayout='og'
  U.teleport(game,edition=='emerald'and'MAP_G00_N16'or'MAP_G24_N42',12,5,'up')
  U.wait(60)
  local ow=game.overworld;local species=edition=='ruby'and'GROUDON'or'KYOGRE'
  local number=edition=='ruby'and 405 or 404
  local flag='QA_LEGENDARY_SCRIPT_FINISHED'
  ow.runner:run({{'g3_set_wild',number,45,0},{'g3_special',313},{'g3_wait_state'},
    {'set_flag',flag}},{mapId=ow.map.id})
  local b
  for _=1,6000 do
    local top=game.stack:top()
    if top and top.kind=='wild'then
      b=top
      if b.phase=='menu'and not b.current and#b.queue==0 then break end
      if b.phase=='messages'then
        game.input:overlayPressed('b');U.wait(1);game.input:overlayReleased('b');U.wait(4)
      else U.wait(1)end
    else U.wait(1)end
  end
  assert(b and b.phase=='menu','Weather legendary special never reached its command menu')
  assert(b.legendary and b.enemy.mon.species==species and b.enemy.mon.level==45)
  assert(ow.runner:isRunning()and not game.save.flags[flag],'Story finished before the legendary battle')
  local S=require('src.core.SaveSerializer');local before=S.encode(game.save);local rng=love.math.getRandomState()
  assert(require('src.render.GraphicsScope').call(b.draw,b))
  assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Legendary drawing changed save/RNG')
  assert(U.shot(game,out..'/native-weather-legendary-menu.png'))
  local report={status='pass',edition=edition,preparedFixture=true,continuousStory=false,
    species=species,level=45,legendary=true,vmParkedDuringBattle=true,drawPreservesSaveRng=true,
    captures={'native-weather-legendary-menu'}}
  local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()
  print('PASS_NATIVE_WEATHER_LEGENDARY');love.event.quit(0)
end
