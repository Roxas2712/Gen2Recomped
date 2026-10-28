-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared imported-trainer fixtures; ordinary menu inputs and final renderer.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local edition=V.get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset()
  local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,wait)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 12)end
  local function shot(name,b)
    local S=require('src.core.SaveSerializer');local before=S.encode(game.save)
    local rng=love.math.getRandomState();local calls=b.phazeDraws
    assert(require('src.render.GraphicsScope').call(b.draw,b))
    assert(before==S.encode(game.save)and rng==love.math.getRandomState()and calls==b.phazeDraws,
      'Drawing changed save or battle RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local resolve=require('src.battle.EnemyMoveChoice').resolveMove
  local splash=assert(resolve(game.data,150));local roar=assert(resolve(game.data,46))
  local wind=assert(resolve(game.data,18));local P=require('src.pokemon.Pokemon')
  local B=require('src.battle.BattleState')
  local keys={};for id,t in pairs(game.data.trainers)do
    local party=t.parties and t.parties[1]
    if type(party)=='table'and#party>=2 and not t.doubleBattle then keys[#keys+1]=id end
  end;table.sort(keys);local trainer=assert(keys[1])
  local function settle(b)
    for _=1,6000 do
      if b.phase=='menu'and not b.current and#b.queue==0 and not b.showPlayerBack and not b.showEnemyTrainer then return end
      if b.phase=='messages'then press('b',4)else U.wait(1)end
    end
    error('Native phazing did not return to the command menu')
  end
  report.trainer=trainer
  for _,kind in ipairs{'enemy-roar','player-whirlwind','double-roar'}do
    U.freshSave(game);game.save.options.battleLayout='og'
    local party={}
    for i,species in ipairs{'CHARMANDER','SQUIRTLE','BULBASAUR'}do
      local m=P.new(game.data,species,50);m.moves={{id=kind=='player-whirlwind'and wind or splash,pp=20}}
      party[i]=m
    end
    game.save.party=party
    U.teleport(game,V.isFRLG()and'MAP_G03_N00'or'MAP_G00_N16',10,12,'up')
    local b=B.newTrainer(game,trainer,1)
    -- Fix actor levels/available actions in the prepared fixture; the
    -- imported move records, effect dispatch and menus remain unchanged.
    for _,m in ipairs(b.enemyParty)do m.level=50;m.moves={{id=splash,pp=20}}end
    local oldFoe=b.enemy.mon
    if kind~='player-whirlwind'then
      b.enemy.mon.moves={{id=roar,pp=20}};b.enemy.curMoves=b.enemy.mon.moves
    else b.enemy.curMoves=b.enemy.mon.moves end
    if kind=='double-roar'then
      b.double=true;b:sendOutSecondPair();b:syncSides()
      local right=b:battlerAt(3);right.mon.moves={{id=splash,pp=20}};right.curMoves=right.mon.moves
    end
    b.phazeDraws=0
    b.rng=function(lo,hi)
      if lo==0 and hi==65535 then
        b.phazeDraws=b.phazeDraws+1
        return kind=='player-whirlwind'and 1 or 2 -- reserve slot2 / player slot3
      end
      return lo or 0
    end
    game.stack:push(b);settle(b);shot('native-'..kind..'-before',b)
    local oldOwn=b.player;local originalOwnHp=oldOwn.mon.hp
    press('a');press('a',20)
    if kind=='double-roar'then press('a');press('a',20)end
    settle(b)
    if kind=='player-whirlwind'then
      assert(b.enemy.mon==b.enemyParty[2]and b.enemy.mon~=oldFoe,'Whirlwind kept the old opponent')
      assert(b.player.mon==party[1]and b.enemyIndex==2,'Whirlwind changed the wrong party/slot')
      assert(party[1].moves[1].pp==19,'Whirlwind did not spend its own PP exactly once')
    else
      local got=false
      for _,a in b:activeBattlers()do if a.isPlayer and a.mon==party[3]then got=true end end
      assert(got,'Enemy Roar never sent the reserve into its targeted slot')
      assert(oldOwn.mon.hp==originalOwnHp,'Phazing changed outgoing HP')
      assert(b.enemy.mon.moves[1].pp==19,'Roar did not spend its own PP exactly once')
    end
    assert(b.phazeDraws>=1,'Native phazing never reached its full-slot selection draw')
    shot('native-'..kind..'-after',b);game.stack:pop();U.wait(20)
  end
  report.drawPreservesSaveRng=true;report.bothDirectionsAndDouble=true
  report.status='pass';persist();print('PASS_GEN3_NATIVE_PHAZING');love.event.quit(0)
end
