-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared parties; imported trainer, real input and final renderer.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local edition=require('src.core.GameVersion').get()
  assert(edition=='ruby'or edition=='sapphire')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,wait)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 12)end
  local function shot(name)
    local S=require('src.core.SaveSerializer');local saved=S.encode(game.save);local rng=love.math.getRandomState()
    local b=game.stack:top();assert(require('src.render.GraphicsScope').call(b.draw,b))
    assert(saved==S.encode(game.save)and rng==love.math.getRandomState(),'Drawing changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  U.freshSave(game);game.save.options.battleLayout='og'
  local P=require('src.pokemon.Pokemon')
  game.save.party={P.new(game.data,'SCEPTILE',46),P.new(game.data,'WINGULL',29)}
  U.teleport(game,'MAP_G14_N00',9,4,'up')
  local B=require('src.battle.BattleState');local N=require('src.battle.Gen3Battle')
  local function menu(b)
    for _=1,4000 do
      if b.phase=='menu'and not b.current and #b.queue==0 and not b.showPlayerBack and not b.showEnemyTrainer then return end
      if b.phase=='messages'then press('b',4)else U.wait(1)end
    end
    error('Battle did not settle at its action menu')
  end
  local b=B.newWild(game,'LUNATONE',42);game.stack:push(b);menu(b)
  shot('native-rs-single-positions');game.stack:pop()
  b=B.newTrainer(game,'TATE_LIZA',1);game.stack:push(b);menu(b);assert(b:isDouble())
  local coords=assert(game.data.constants.gen3BattlerCoords)
  assert(#coords.singles==4 and #coords.doubles==4,'Imported position rows absent')
  local placed={}
  local expected={{0,49},{168,4},{58,70},{120,-3}}
  for id=0,3 do
    local battler=assert(b:battlerAt(id));local img=assert(b:picImage(battler.sprite))
    local scale=B.resolveBattleScale(game.data,battler.isPlayer and'back'or'front',battler.sprite,battler.mon.species)
    local x,y=N.picPlacement(b,battler,img,battler.sprite,scale)
    assert(x==expected[id+1][1]and y==expected[id+1][2],
      'RS sprite must use original frame centre and front/back offset')
    placed[id+1]={x=x,y=y,species=battler.mon.species}
  end
  assert(placed[1].x~=placed[3].x and placed[2].x~=placed[4].x,'Native double sprites overlap at one anchor')
  shot('native-rs-double-left-command')
  press('a');assert(b.phase=='moveSelect');press('a');assert(b.phase=='targetSelect')
  shot('native-rs-double-first-target');press('right');shot('native-rs-double-second-target')
  U.wait(8);shot('native-rs-double-second-target-blink')
  press('a');assert(b.phase=='menu'and b:menuBattler()==b:battlerAt(2),'Second battler did not receive its own command')
  shot('native-rs-double-right-command');press('b');assert(b.phase=='menu'and b:menuBattler()==b:battlerAt(0))
  shot('native-rs-double-back-to-left')
  report.placements=placed;report.nativeRows=coords;report.drawPreservesSaveRng=true
  report.secondBattlerCommandAndCancel=true;report.status='pass';persist()
  print('PASS_RS_NATIVE_BATTLER_POSITIONS');love.event.quit(0)
end
