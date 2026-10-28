-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared RS gym: actual map scripts, directional inputs, restore and fall.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local edition=require('src.core.GameVersion').get()
  assert(edition=='ruby' or edition=='sapphire')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'} do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'SCEPTILE',48)}
  require('src.core.SaveData').validate(game.save,game.data)
  require('src.battle.BattleState').stampOT(game.save,game.save.party[1])
  U.teleport(game,'MAP_G15_N00',8,20,'up');U.wait(90)
  local C=require('src.script.Gen3Commands');local S=require('src.core.SaveSerializer')
  local firstBarrier=game.overworld.map:blockAt(8,15)
  local ow=game.overworld;local report={status='running',edition=edition,
    preparedFixture=true,continuousStory=false,captures={},nativeIceSounds={}}
  local Sound=require('src.core.Sound');local play=Sound.playSe
  Sound.playSe=function(data,key,...)
    local source=play(data,key,...)
    if key=='SE_ICE_CRACK' or key=='SE_ICE_BREAK' then
      assert(source,'Native ice sound did not reach an audio source')
      report.nativeIceSounds[#report.nativeIceSounds+1]=key
    end
    return source
  end
  local function persist()
    local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()
  end
  local function shot(name)
    local before=S.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
    assert(require('src.render.GraphicsScope').call(top.draw,top))
    assert(before==S.encode(game.save) and rng==love.math.getRandomState(),'Ice draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function step(dir)
    assert(game.stack:top()==ow and not ow.runner:isRunning())
    local x,y=ow.player.cellX,ow.player.cellY
    game.input:overlayPressed(dir)
    for _=1,60 do
      U.wait(1);if ow.player.moving or ow.player.cellX~=x or ow.player.cellY~=y then break end
    end
    game.input:overlayReleased(dir)
    for _=1,120 do if not ow.player.moving then break end;U.wait(1) end
    U.wait(8)
  end
  for _,dir in ipairs{'up','right','up','left','left','up','right'} do step(dir) end
  U.wait(100)
  assert(C.getVar(game.save,0x4022)==9,'Original first gate did not unlock')
  assert(#report.nativeIceSounds==7,'Expected seven native cracking sounds')
  shot('native-rs-first-ice-solved')
  ow:captureSave(game.save)
  local savedBytes=S.encode(game.save);local savedParty=S.encode(game.save.party)
  game:restoreSave(assert(S.decode(savedBytes)));U.wait(120);ow=game.overworld
  assert(C.getVar(game.save,0x4022)==9,'Continue reset native ice progress')
  for _,xy in ipairs{{8,19},{9,19},{9,18},{8,18},{7,18},{7,17},{8,17}} do
    assert(ow.map:cellBehaviour(xy[1],xy[2])==39,'Continue lost a native cracked tile')
  end
  assert(S.encode(game.save.party)==savedParty,'Restore changed party')
  shot('native-rs-ice-after-continue')
  -- A fresh visit starts TRANSITION before LOAD checks the stair counter.
  -- Checking LOAD first accidentally left the previously opened stairs up.
  U.teleport(game,'MAP_G15_N00',8,20,'up');U.wait(90);ow=game.overworld
  assert(C.getVar(game.save,0x4022)==1)
  assert(ow.map:blockAt(8,15)==firstBarrier,'Fresh entry left the solved stair gate open')
  shot('native-rs-solved-ice-fresh-entry')
  game:restoreSave(assert(S.decode(savedBytes)));U.wait(120);ow=game.overworld
  assert(C.getVar(game.save,0x4022)==9)
  step('left');U.wait(1);shot('native-rs-ice-break-before-fall')
  U.wait(180)
  assert(ow.map.id=='MAP_G15_N01','Original ice fall did not reach the basement')
  assert(report.nativeIceSounds[#report.nativeIceSounds]=='SE_ICE_BREAK')
  shot('native-rs-ice-fall-basement')
  U.teleport(game,'MAP_G15_N00',8,20,'up');U.wait(90);ow=game.overworld
  assert(C.getVar(game.save,0x4022)==1,'Fresh entry did not reset the native puzzle')
  for id=0x4001,0x400A do assert(C.getVar(game.save,id)==0,'Fresh visit kept an old ice row') end
  assert(ow.map:cellBehaviour(8,19)==38,'Fresh entry kept a cracked tile')
  shot('native-rs-ice-fresh-entry-reset')
  Sound.playSe=play
  report.status='pass';report.continuePreservesIce=true;report.originalFallAndReset=true
  report.drawPreservesSaveRng=true;persist();print('PASS_NATIVE_RS_ICE_CONTINUE');love.event.quit(0)
end
