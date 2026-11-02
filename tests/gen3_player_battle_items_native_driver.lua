-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Explicit prepared fixtures; imported effect bytes, ordinary BAG/A inputs.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local V=require('src.core.GameVersion');local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(V.isGen3() and love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset()
 local report={edition=V.get(),status='running',preparedFixture=true,continuousStory=false,cases={},captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(key,n)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(n or 12)end
 local function shot(name)
  local S=require('src.core.SaveSerializer');local before=S.encode(game.save);local rng=love.math.getRandomState()
  local top=game.stack:top();assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'draw modified SAVE/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local P,B=require('src.pokemon.Pokemon'),require('src.battle.BattleState')
 local splash=assert(require('src.battle.EnemyMoveChoice').resolveMove(game.data,150))
 local rows={{'X_ATTACK','attack'},{'X_DEFEND','defense'},{'X_SPEED','speed'},
  {'X_SPECIAL','spatk'},{'X_ACCURACY','accuracy'},{'DIRE_HIT','focusEnergy'},{'GUARD_SPEC','mist'}}
 persist()
 for _,row in ipairs(rows)do
  local id,stat=unpack(row);assert(game.data.items[id],'missing imported item '..id)
  local record=assert(game.data.constants.gen3ItemEffects[id]);assert(record.bytes and #record.bytes>=6)
  U.freshSave(game);game.save.options.battleLayout='og';game.save.options.animations=true
  local mon=P.new(game.data,'RAYQUAZA',70);mon.moves={{id=splash,pp=40}};mon.happiness=70
  game.save.party={mon};game.save.inventory={[id]=2}
  U.teleport(game,V.isFRLG()and'MAP_G03_N00'or'MAP_G00_N16',10,12,'up')
  local b=B.newWild(game,'BLISSEY',100);b.enemy.mon.moves={{id=splash,pp=40}};b.enemy.curMoves=b.enemy.mon.moves
  game.stack:push(b)
  local function menu(turn)
   for _=1,12000 do
    if game.stack:top()==b and b.phase=='menu'and not b.current and #b.queue==0
     and not b.showPlayerBack and not b.showEnemyTrainer and (b.turnCount or 0)==turn then return end
    if game.stack:top()==b and b.phase~='messages'then U.wait(1)else press('b',4)end
   end
   report.waitFailure={expectedTurn=turn,actualTurn=b.turnCount or 0,phase=b.phase,
    queue=#b.queue,shownPlayerBack=b.showPlayerBack,shownEnemyTrainer=b.showEnemyTrainer}
   persist();error('battle did not return to expected turn '..turn)
  end
  local function selectBagItem()
   if (b.menuIndex-1)%2==0 then press('right')end
   if b.menuIndex>2 then press('up')end
   assert(b.menuIndex==2);press('a',90)
   local bag=game.stack:top();assert(getmetatable(bag)==require('src.ui.Gen3BagMenu'))
   for _=1,5 do if bag.pocket==1 then break end;press('left',25)end
   for _=1,#bag.rows do if bag:selected().id==id then break end;press('down')end
   assert(bag:selected().id==id);shot('tonic-'..id..'-bag');press('a',60)
  end
  menu(0);shot('tonic-'..id..'-ready');selectBagItem();menu(1)
  assert(game.save.inventory[id]==1,'native bag did not consume exactly one item')
  assert(not b.player.xAccuracy and b.player.stages.special==nil,'legacy G1 state leaked into GBA')
  if stat=='focusEnergy'then assert(b.player.focusEnergy)
  elseif stat=='mist'then assert(b.sides[1].gen3MistTurns==4 and not b.sides[2].gen3MistTurns)
  else assert(b.player.stages[stat]==1);assert(stat~='spatk'or not b.player.stages.spdef)end
  shot('tonic-'..id..'-used')
  -- A saturated stat is an explicit second prepared condition, not story play.
  if stat~='focusEnergy'and stat~='mist'then b.player.stages[stat]=6 end
  local friendship=mon.happiness;selectBagItem()
  for _=1,80 do
   local top=game.stack:top()
   if getmetatable(top)==require('src.ui.Gen3BagMenu')then break end
   press('b',6)
  end
  assert(game.save.inventory[id]==1 and mon.happiness==friendship,'failed item changed bag/friendship')
  assert(b.turnCount==1,'failed item spent an ordinary battle turn')
  shot('tonic-'..id..'-refused')
  report.cases[#report.cases+1]={item=id,bytes=record.bytes,consumed=1,failedKept=true,
   failedTurnUnchanged=true,stage=stat,friendshipAfter=mon.happiness};persist()
 end
 report.drawPreservesSaveRng=true;report.realImportedItems=true;report.ordinaryBagSelection=true
 report.status='pass';persist();print('PASS_GEN3_PLAYER_BATTLE_ITEMS '..V.get());love.event.quit(0)
end
