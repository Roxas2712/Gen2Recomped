-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared combatants; real BAG/POTION/party inputs over imported game data.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local edition=V.get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset();U.freshSave(game);game.save.options.battleLayout='og'
  local resolve=require('src.battle.EnemyMoveChoice').resolveMove
  local protect,fake,scratch=assert(resolve(game.data,182)),assert(resolve(game.data,252)),assert(resolve(game.data,10))
  local mon=require('src.pokemon.Pokemon').new(game.data,'CHARMANDER',40)
  mon.moves={{id=protect,pp=10},{id=fake,pp=10}};mon.hp=mon.stats.hp-20
  game.save.party={mon};game.save.inventory={POTION=2};game.save.bagOrder={'POTION'}
  require('src.core.SaveData').validate(game.save,game.data)
  U.teleport(game,V.isFRLG()and'MAP_G03_N00'or'MAP_G00_N16',10,12,'up')
  local b=require('src.battle.BattleState').newWild(game,'CHARMANDER',10)
  b.enemy.mon.moves={{id=scratch,pp=20}};b.enemy.curMoves=b.enemy.mon.moves
  b.player.abilityOverride=false;b.enemy.abilityOverride=false
  local draws=0;b.rng=function(lo,hi)draws=draws+1;return lo or 0 end
  local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,wait)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 12)end
  local function settle()
    for _=1,6000 do
      if game.stack:top()==b and b.phase=='menu'and not b.current and#b.queue==0
        and not b.showPlayerBack and not b.showEnemyTrainer then return end
      if game.stack:top()==b and b.phase=='messages'then press('b',4)else U.wait(1)end
    end
    error('Item round did not return through the actual battle queue')
  end
  local function shot(name)
    local S=require('src.core.SaveSerializer');local before=S.encode(game.save)
    local rng,calls=love.math.getRandomState(),draws
    assert(require('src.render.GraphicsScope').call(b.draw,b))
    assert(before==S.encode(game.save)and rng==love.math.getRandomState()and calls==draws,
      'Native item-round drawing changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  persist();game.stack:push(b);settle()
  local before=mon.hp
  press('a');press('a',20);settle()
  assert(b.turnCount==1 and b.player.protecting and mon.hp==before,'First-round Protect control failed')
  assert(b.enemy.curMoves[1].pp==19,'Protected reply did not spend exactly one PP')
  shot('native-protect-round-one')
  press('right');press('a',60)
  assert(getmetatable(game.stack:top())==require('src.ui.Gen3BagMenu'),'BAG did not open native GBA bag')
  press('a',60)
  assert(getmetatable(game.stack:top())==require('src.ui.Gen3PartyMenu'),'POTION did not open native party target')
  press('a',60);settle()
  assert(game.save.inventory.POTION==1,'Potion did not consume exactly one item')
  assert(mon.hp>before and mon.hp<mon.stats.hp,'Previous Protect blocked the reply after healing')
  assert(not b.player.protecting and b.turnCount==2,'Item did not start exactly one new round')
  assert(b.player.turnsOut==2 and b.enemy.turnsOut==2,'Item round preserved the first-turn window')
  assert(b.enemy.curMoves[1].pp==18,'Item round did not execute exactly one enemy reply')
  shot('native-potion-reply-after-protect')
  local enemyHp=b.enemy.mon.hp
  press('left');press('a');press('right');press('a',20);settle()
  assert(b.enemy.mon.hp==enemyHp and mon.moves[2].pp==9,'Fake Out succeeded outside the first round')
  assert(b.turnCount==3 and b.enemy.curMoves[1].pp==17,'Failed Fake Out did not finish one ordinary round')
  shot('native-fake-out-correctly-fails')
  report.protectExpiresOnItem=true;report.itemAndEnemyReplyExactlyOnce=true
  report.fakeOutWindowCorrect=true;report.drawPreservesSaveRng=true;report.status='pass';persist()
  print('PASS_NATIVE_GBA_NONMOVE_ROUNDS');love.event.quit(0)
end
