-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared surfer; real directional input, WATERFALL question and HM callback.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local edition=require('src.core.GameVersion').get()
  assert(edition=='ruby' or edition=='sapphire')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  local mon=require('src.pokemon.Pokemon').new(game.data,'KYOGRE',45)
  mon.moves={{id='WATERFALL',pp=15},{id='SURF',pp=15}};game.save.party={mon}
  require('src.core.SaveData').validate(game.save,game.data)
  require('src.battle.BattleState').stampOT(game.save,mon)
  for _,move in ipairs{'SURF','WATERFALL'}do
    local gate=assert(game.data.constants.gen3FieldMoves[move])
    assert(gate.badgeFlag);game.save.flags[('FLAG_G3_%04X'):format(gate.badgeFlag)]=true
  end
  game.save.repelSteps=1000
  U.teleport(game,'MAP_G00_N08',20,68,'up');U.wait(60)
  local ow=game.overworld;local rule=assert(game.data.constants.gen3Waterfall)
  local first,last
  for y=0,ow.map.heightCells-1 do
    if ow.map:cellBehaviour(20,y)==rule.behaviour then first=first or y;last=y end
  end
  assert(first and last and last>first,'Original Ever Grande waterfall missing')
  U.teleport(game,'MAP_G00_N08',20,last+1,'up');ow=game.overworld
  ow.player.surfing=true;U.wait(30)
  local base=last+1
  local report={status='running',edition=edition,preparedFixture=true,continuousStory=false,
    nativeFall={x=20,top=first,bottom=last},captures={}}
  local function persist()
    local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()
  end
  persist()
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 16)
  end
  local function shot(name)
    local S=require('src.core.SaveSerializer');local before=S.encode(game.save);local rng=love.math.getRandomState()
    local top=game.stack:top();assert(require('src.render.GraphicsScope').call(top.draw,top))
    assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Waterfall draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  shot('native-waterfall-before-ascent')
  game.input:overlayPressed('up');U.wait(45);game.input:overlayReleased('up');U.wait(150)
  assert(ow.player.cellX==20 and ow.player.cellY==base,'D-pad bypassed native waterfall current')
  assert(not ow.player.moving and game.stack:top()==ow)
  shot('native-waterfall-dpad-pushed-back')
  -- Turning north does not yet enter the fall; A offers the original question.
  press('up',12);assert(ow.player.cellY==base and ow.player.facing=='up')
  press('a',180)
  local Choice=require('src.ui.Gen3RsChoice')
  for _=1,20 do
    if getmetatable(game.stack:top())==Choice then break end
    press('a',20)
  end
  assert(getmetatable(game.stack:top())==Choice,'Waterfall did not ask YES/NO')
  shot('native-waterfall-hm-question');press('a',1)
  local Move=require('src.world.Gen3FieldMove');local sweep
  for _=1,300 do
    local top=game.stack:top()
    if getmetatable(top)==Move then sweep=top;break end
    U.wait(1)
  end
  assert(sweep and sweep.mon==mon,'A interaction omitted the actual HM user presentation')
  U.wait(30);shot('native-waterfall-pokemon-announcement')
  for _=1,1200 do
    local top=game.stack:top()
    if top==ow and not ow.player.moving and #(ow.scriptMoves or{})==0
       and ow.player.cellY<first then break end
    if type(top.advance)=='function'then press('a',12)else U.wait(1)end
  end
  assert(game.stack:top()==ow and ow.player.cellX==20 and ow.player.cellY==first-1,
    'HM did not climb onto the upper water')
  assert(ow.player.surfing and not ow.player.inputLocked)
  assert(mon.moves[1].pp==15 and mon.moves[2].pp==15,'Field HM consumed battle PP')
  shot('native-waterfall-upper-water-after-hm')
  -- Entering from the upper water rides all the way down without another HM.
  game.input:overlayPressed('down');U.wait(12);game.input:overlayReleased('down');U.wait(400)
  assert(ow.player.cellX==20 and ow.player.cellY==base,'Descent did not reach ordinary water')
  assert(game.stack:top()==ow and not ow.player.moving and not ow.player.inputLocked)
  shot('native-waterfall-full-descent')
  report.status='pass';report.dpadCannotClimb=true;report.actualHmPresentationAndClimb=true
  report.fullDescent=true;report.drawPreservesSaveRng=true;persist()
  print('PASS_NATIVE_RS_WATERFALL');love.event.quit(0)
end
