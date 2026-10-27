-- Prepared inventory; real bag input and final renderer, not a story proof.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local edition=V.get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,wait)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 24)end
  local function shot(name)
    local S=require('src.core.SaveSerializer');local before=S.encode(game.save);local rng=love.math.getRandomState()
    local ok,why=require('src.render.GraphicsScope').call(function()game.stack:top():draw()end)
    assert(ok,why)
    assert(S.encode(game.save)==before and love.math.getRandomState()==rng,'Drawing changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'))
    report.captures[#report.captures+1]=name;persist()
  end
  persist();U.freshSave(game);game.save.options.battleLayout='og'
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'PIKACHU',25)}
  local Bag=require('src.inventory.Bag');assert(Bag.add(game.save,'POKE_BALL',8,game.data));assert(Bag.add(game.save,'POTION',3,game.data))
  U.teleport(game,V.isFRLG()and'MAP_G03_N00'or'MAP_G00_N16',10,12,'up')
  local Menu=require('src.ui.Gen3BagMenu')
  -- Enter through the actual START menu rather than a separate render canvas.
  local function fieldBag()
    press('start');local start=game.stack:top()
    assert(start.screenId=='Gen3StartMenu')
    for _=1,12 do if start.rows[start.index].key=='bag'then break end;press('down',8)end
    assert(start.rows[start.index].key=='bag');press('a',40)
    local bag=game.stack:top();assert(getmetatable(bag)==Menu);return bag
  end
  local bag=fieldBag();assert(bag.pocket==1)
  for _=1,V.isFRLG()and 2 or 1 do press('right',40)end
  assert(bag.pockets[bag.pocket].key=='BALL');shot('native-field-bag-balls-selected')
  press('b',30);assert(game.stack:top().screenId=='Gen3StartMenu');press('b',30)
  bag=fieldBag();shot('native-field-bag-balls-reopened')
  assert(bag.pockets[bag.pocket].key=='BALL','Field bag forgot its last pocket')
  press('b',30);press('b',30);assert(game.stack:top()==game.overworld)
  local b=require('src.battle.BattleState').newWild(game,'ZIGZAGOON',5);game.stack:push(b)
  local function menu()
    for _=1,4000 do
      if game.stack:top()==b and b.phase=='menu'and not b.current and #b.queue==0 then return end
      if game.stack:top()==b and b.phase=='messages'then press('b',4)else U.wait(1)end
    end
    error('Battle did not return to action menu')
  end
  menu();press('right',8);press('a',50)
  bag=game.stack:top();assert(getmetatable(bag)==Menu)
  shot('native-battle-bag-balls-reopened');assert(bag.pockets[bag.pocket].key=='BALL')
  local turns=b.turnCount;local balls=game.save.inventory.POKE_BALL;local rng=love.math.getRandomState()
  press('b',40);menu()
  assert(b.turnCount==turns and game.save.inventory.POKE_BALL==balls and love.math.getRandomState()==rng,
    'Cancel spent a turn, ball or RNG')
  press('a',50);bag=game.stack:top();assert(getmetatable(bag)==Menu)
  shot('native-battle-bag-balls-after-cancel');assert(bag.pockets[bag.pocket].key=='BALL')
  press('b',40);menu()
  report.cancelPreservesTurnBallRng=true;report.drawPreservesSaveRng=true
  report.status='pass';persist();print('PASS_NATIVE_GBA_BAG_REOPEN');love.event.quit(0)
end
