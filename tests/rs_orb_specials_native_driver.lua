-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared field, real VM special/waitstate rows, native music and renderer.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local edition=require('src.core.GameVersion').get();assert(edition=='ruby'or edition=='sapphire')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset()
  local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function until_(check,label,max)
    for _=1,max or 2000 do if check()then return end;U.wait(1)end
    error(label)
  end
  local function shot(name)
    local S=require('src.core.SaveSerializer');local before=S.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(game.overworld.draw,game.overworld))
    assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Orb drawing changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  U.freshSave(game)
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'SCEPTILE',48)}
  U.teleport(game,'MAP_G24_N36',17,41,'up');U.wait(60)
  local world=game.overworld;local Music=require('src.core.Music')
  assert(Music.current(),'Prepared field music never started')
  world.runner:run({{'g3_special',0x114C},{'g3_wait_state'}},{mapId=world.map.id})
  until_(function()return not world.runner:isRunning()end,'RS music fade did not resume its VM')
  assert(Music.current()==nil,'Orb fade continued while map music was playing')
  report.nativeMapMusicStopped=true
  for result=0,1 do
    game.save.gen3Vars=game.save.gen3Vars or{}
    game.save.gen3Vars[0x800D]=result
    world.runner:run({{'g3_special',0x1119},{'g3_wait_state'}},{mapId=world.map.id})
    until_(function()return world.g3Orb~=nil end,'Original RS orb special never started')
    U.wait(40)
    assert(world.g3Orb.state=='grow'and world.g3Orb.cx==104)
    assert(world.runner:isRunning(),'Growing orb failed to hold the VM')
    local prefix=result==0 and'native-rs-red-orb-'or'native-rs-blue-orb-'
    shot(prefix..'growing')
    until_(function()return not world.runner:isRunning()end,'Orb growth did not resume its VM')
    assert(world.g3Orb.state=='shake'and world.g3Orb.radius==161)
    U.wait(8);shot(prefix..'full-shake')
    world.runner:run({{'g3_special',0x111A},{'g3_wait_state'}},{mapId=world.map.id})
    U.wait(64)
    assert(world.g3Orb and world.g3Orb.state=='fade'and world.g3Orb.eva<12)
    assert(world.runner:isRunning(),'Orb fade failed to hold the VM')
    shot(prefix..'fading')
    until_(function()return not world.runner:isRunning()end,'Orb fade did not resume its VM')
    assert(not world.g3Orb and not world.g3FxWaiter)
    assert(require('src.world.Gen3ScreenFx').pan(world)==nil,'Orb left the camera displaced')
    shot(prefix..'restored')
  end
  report.drawPreservesSaveRng=true;report.vmGrowthFadeAndCleanup=true
  report.status='pass';persist();print('PASS_RS_ORB_SPECIALS');love.event.quit(0)
end
