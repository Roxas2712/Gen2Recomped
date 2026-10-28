-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared real-map fixture, not ordinary story completion.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local edition=V.get()
  assert(edition=='ruby'or edition=='sapphire')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,n)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(n or 30)end
  local function shot(name)
    local S=require('src.core.SaveSerializer');local saved=S.encode(game.save);local rng=love.math.getRandomState()
    local screen=game.stack:top();assert(require('src.render.GraphicsScope').call(screen.draw,screen))
    assert(saved==S.encode(game.save)and rng==love.math.getRandomState(),'draw changed save or RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  U.freshSave(game);local P=require('src.pokemon.Pokemon')
  game.save.party={P.new(game.data,'SCEPTILE',45),P.new(game.data,'WINGULL',29)}
  local X=require('src.import.RomExtractorGen3')
  assert(X.forcedFloorRulesReady(game.data.constants.gen3ForcedMovement),'native floor rules absent')
  U.teleport(game,'MAP_G14_N00',5,25,'up')
  local w=game.overworld;local map=w.map
  assert(map:forcedMovementAt(1,23).way=='right','original switch-four arrow is not east')
  shot('native-mossdeep-switch-before')
  -- The imported switch script changes the real floor behaviour and graphics.
  press('a',180)
  assert(game.stack:top()==w and not w.runner:isRunning(),'switch did not return to field')
  assert(map:forcedMovementAt(1,23).way=='up','native switch did not rotate the arrow north')
  shot('native-mossdeep-switch-after')
  press('a',180)
  assert(map:forcedMovementAt(1,23).way=='right','second switch use did not restore the arrow')
  -- One tap onto the western conveyor must carry the player after release.
  -- The east-facing red arrow exits onto ordinary floor beside the trainer.
  U.teleport(game,'MAP_G14_N00',1,28,'up');w=game.overworld
  shot('native-mossdeep-conveyor-before')
  press('up',12)
  local intermediate={x=w.player.cellX,y=w.player.cellY}
  U.wait(360)
  local p=w.player
  assert(p.cellX==2 and p.cellY==23,'arrow did not carry released input to the native east exit')
  assert(intermediate.x~=p.cellX or intermediate.y~=p.cellY,'test did not witness movement after release')
  shot('native-mossdeep-conveyor-after')
  report.releasedInputStart=intermediate;report.releasedInputEnd={x=p.cellX,y=p.cellY}
  report.nativeSwitchRoundTrip=true;report.drawPreservesSaveRng=true
  report.status='pass';persist();print('PASS_RS_NATIVE_FORCED_FLOORS');love.event.quit(0)
end
