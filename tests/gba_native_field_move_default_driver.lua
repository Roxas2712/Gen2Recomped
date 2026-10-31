-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared original-art presentation acceptance; never an ordinary campaign.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local V=require('src.core.GameVersion');local Native=require('src.world.Gen3FieldMove')
 local S=require('src.core.SaveSerializer');local edition=V.get()
 local out=assert(os.getenv('EDITION_QA_OUT'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 local mon=require('src.pokemon.Pokemon').new(game.data,V.isFRLG()and'BLASTOISE'or'SCEPTILE',40)
 local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,cases={},captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function shot(name)
  local before,rng=S.encode(game.save),love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Field-move draw changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local function waitFor(fn,frames,message)
  for _=1,frames do if fn()then return end;U.wait(1)end
  error(message)
 end
 for _,kind in ipairs{'outdoors','indoors'}do
  local map=V.isFRLG()and(kind=='outdoors'and'MAP_G03_N00'or'MAP_G04_N01')
    or(kind=='outdoors'and'MAP_G00_N16'or'MAP_G01_N00')
  U.teleport(game,map,4,4,'down');U.wait(30)
  local world=game.stack:top();local done=0
  assert(world.map and world.map.id==map)
  local shown,state=Native.show(game,mon,function()done=done+1 end)
  assert(shown and state.effect and state.options.presentation=='cartridge','Ordinary default did not admit the cartridge band')
  assert(state.effect.outdoors==(kind=='outdoors'),'Imported map kind selected the wrong strip')
  local row={kind=kind,map=map,presentation=state.options.presentation,defaultOptions=true}
  report.cases[#report.cases+1]=row;persist()
  U.wait(2);shot('native-default-field-'..kind..'-pose')
  waitFor(function()local fx=state.effect;return fx and fx.sprite and fx.sprite.state=='wait'end,
    160,'Original band did not carry the Pokemon to its held position')
  shot('native-default-field-'..kind..'-band')
  waitFor(function()return state.effect and state.effect.phase==5 end,160,'Original band never entered its closing phase')
  shot('native-default-field-'..kind..'-closing')
  waitFor(function()return state.done end,160,'Original field move never completed')
  assert(done==1 and game.stack:top()==world and not world.player.fieldMove,'Field-move completion did not return control exactly once')
  row.completed=true;row.frames=state.frame;persist()
 end
 report.drawPreservesSaveRng=true;report.status='pass';persist()
 print('PASS_NATIVE_GBA_FIELD_DEFAULT '..edition);love.event.quit(0)
end
