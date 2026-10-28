-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared fixture; original boulder script, ordinary inputs, final renderer.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local edition=V.get()
  assert(edition=='ruby'or edition=='sapphire')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,wait)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 16)end
  local function shot(name)
    local S=require('src.core.SaveSerializer');local saved=S.encode(game.save);local rng=love.math.getRandomState()
    local b=game.stack:top();assert(require('src.render.GraphicsScope').call(b.draw,b))
    assert(saved==S.encode(game.save)and rng==love.math.getRandomState(),'Drawing changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local P=require('src.pokemon.Pokemon')
  for _,named in ipairs{true,false}do
    U.freshSave(game)
    local mon=P.new(game.data,'KECLEON',30);mon.nickname=named and'A%PLAYER'or nil
    mon.moves={{id='STRENGTH',pp=15}};game.save.party={mon}
    game.save.flags.FLAG_G3_080A=true -- native RS badge04 gate
    U.teleport(game,'MAP_G24_N28',5,12,'up')
    local world=game.overworld;assert(world:gen3HasBadge('STRENGTH'))
    assert(not game.save.flags.FLAG_G3_0829)
    press('a',90)
    local found=false;local expected=named and'A%PLAYER'or'KECLEON'
    for _=1,80 do
      local top=game.stack:top()
      local pages=top.pages and top.pages[top.pageIndex]
      local text=pages and table.concat(pages,' ')
      if text and text:find(expected..' used STRENGTH.',1,true)then
        U.wait(180);shot(named and'native-strength-custom-name'or'native-strength-species-name')
        found=true;break
      end
      if top.screenId=='Gen3RsChoice'then assert(top.index==1);press('a',90)
      elseif top.pages then press('a',90)else U.wait(120)end
    end
    assert(found,'Original Strength script omitted its selected Pokemon name')
    for _=1,30 do
      if game.stack:top()==world and not world.runner:isRunning()then break end
      press('a',90)
    end
    assert(game.stack:top()==world and not world.runner:isRunning())
    assert(game.save.flags.FLAG_G3_0829,'Original script did not activate Strength')
    assert(mon.moves[1].pp==15,'Field Strength spent battle PP')
    local boulder
    for _,e in ipairs(world.entities)do if e.def and e.def.localId==1 then boulder=e end end
    assert(boulder and boulder.cellX==5 and boulder.cellY==11)
    press('left',30);press('up',30);press('right',90)
    assert(boulder.cellX==6 and boulder.cellY==11,'Ordinary push did not move the boulder')
  end
  report.drawPreservesSaveRng=true;report.originalStrengthFlagAndPush=true
  report.status='pass';persist();print('PASS_RS_STRENGTH_NAMES');love.event.quit(0)
end
