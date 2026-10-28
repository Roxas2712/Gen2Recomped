-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared dark cave; actual START/party inputs, field sweep and text.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local edition=V.get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  local mon=require('src.pokemon.Pokemon').new(game.data,'KECLEON',30)
  local move=assert(require('src.battle.EnemyMoveChoice').resolveMove(game.data,148))
  mon.moves={{id=move,pp=20}};game.save.party={mon}
  local gate=assert(game.data.constants.gen3FieldMoves.FLASH)
  if gate.badgeFlag then game.save.flags[('FLAG_G3_%04X'):format(gate.badgeFlag)]=true end
  local keys={};for id,def in pairs(game.data.maps)do if def.requiresFlash then keys[#keys+1]=id end end
  table.sort(keys);local id=assert(keys[1],'No imported dark cave')
  local warp=assert(game.data.maps[id].warps[1])
  U.teleport(game,id,warp.x,warp.y,'up');U.wait(60)
  require('src.world.Gen3Flash').setLit(game,false)
  require('src.world.Gen3Flash').defaultFor(game,true)
  local report={status='running',edition=edition,preparedFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 12)
  end
  local function shot(name)
    local S=require('src.core.SaveSerializer');local before=S.encode(game.save);local rng=love.math.getRandomState()
    local top=game.stack:top();assert(require('src.render.GraphicsScope').call(top.draw,top))
    assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Field menu draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local Start=require('src.ui.Gen3StartMenu');local Party=require('src.ui.Gen3PartyMenu')
  shot('native-before-party-flash')
  press('start');local menu=game.stack:top();assert(getmetatable(menu)==Start)
  local target;for i,row in ipairs(menu.rows)do if row.key=='pokemon'then target=i end end
  assert(target)
  for _=1,math.abs(target-menu.index)do press(target>menu.index and'down'or'up')end
  press('a',30);assert(getmetatable(game.stack:top())==Party)
  press('a');press('a',30)
  for _,state in ipairs(game.stack.states)do assert(getmetatable(state)~=Start,'Field action recreated START')end
  shot('native-party-flash-presentation')
  for _=1,2000 do
    local top=game.stack:top()
    assert(getmetatable(top)~=Start,'Completed field action returned to START')
    if top==game.overworld and require('src.world.Gen3Flash').lit(game)then break end
    if type(top.advance)=='function'then press('a',20)else U.wait(1)end
  end
  assert(game.stack:top()==game.overworld and#game.stack.states==1,'FLASH did not return directly to the map')
  assert(require('src.world.Gen3Flash').lit(game),'Actual FLASH callback never lit the cave')
  U.wait(240);shot('native-after-party-flash-field')
  assert(mon.moves[1].pp==20,'Field FLASH spent battle PP')
  report.status='pass';report.directFieldReturn=true;report.drawPreservesSaveRng=true;persist()
  print('PASS_NATIVE_FIELD_MENU_RETURN');love.event.quit(0)
end
