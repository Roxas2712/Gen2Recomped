-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared combatants; real imported moves, ordinary input and final renderer.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local V=require('src.core.GameVersion');local edition=V.get()
 local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(V.isGen3() and love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 assert(require('src.import.RomImporter').readyReport(edition).ok)
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'} do love[event]=function()end end
 game.input:reset()
 local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={},cases={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(key,wait)
  game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 8)
 end
 local function shot(name,b)
  local S=require('src.core.SaveSerializer');local saved=S.encode(game.save)
  local rng=love.math.getRandomState()
  assert(require('src.render.GraphicsScope').call(b.draw,b))
  assert(saved==S.encode(game.save) and rng==love.math.getRandomState(),'Drawing changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local resolve=require('src.battle.EnemyMoveChoice').resolveMove
 local outrage=assert(resolve(game.data,200));local splash=assert(resolve(game.data,150))
 assert(game.data.moves[outrage].gen3Effect==27,'Imported OUTRAGE lost its original effect')
 local P=require('src.pokemon.Pokemon');local B=require('src.battle.BattleState')
 persist()
 for roll=0,1 do
  U.freshSave(game);game.save.options.battleLayout='og';game.save.options.animations=true
  local mon=P.new(game.data,'RAYQUAZA',70)
  local initialPP=math.min(10,assert(tonumber(game.data.moves[outrage].pp)))
  mon.moves={{id=outrage,pp=initialPP}};game.save.party={mon}
  U.teleport(game,V.isFRLG() and'MAP_G03_N00'or'MAP_G00_N16',10,12,'up')
  local b=B.newWild(game,'BLISSEY',100)
  b.enemy.mon.moves={{id=splash,pp=40}};b.enemy.curMoves=b.enemy.mon.moves
  local row={duration=roll+2,move=outrage,initialPP=initialPP,endTurns={},animationStarts=0,animations={}}
  report.cases[#report.cases+1]=row
  local tick=b.gen3BattlerCountersTick
  b.gen3BattlerCountersTick=function(self,actor,...)
   local before=actor.thrashTurns;local confused=actor.confusedTurns
   local result=tick(self,actor,...)
   if actor==self.player and before then
    row.endTurns[#row.endTurns+1]={before=before,after=actor.thrashTurns or 0,
     confusedBefore=confused or 0,confusedAfter=actor.confusedTurns or 0,pp=mon.moves[1].pp}
   end
   return result
  end
  assert(b.gen3Anim,'Native GBA animation player is missing')
  local start=b.gen3Anim.start
  b.gen3Anim.start=function(self,id,player,...)
   local accepted=start(self,id,player,...)
   if accepted and player and id==outrage then
    row.animationStarts=row.animationStarts+1
    row.animations[#row.animations+1]={turn=b.turnCount,frames=self.total or 0}
   end
   return accepted
  end
  local nativeRng=b.rng
  b.rng=function(lo,hi)
   if lo==0 and hi==1 then return roll end
   -- Stable successful, noncritical fixture; the imported damage formula,
   -- action queue and animation script still run normally.
   if hi==65535 or lo==85 and hi==100 then return hi end
   return nativeRng(lo,hi)
  end
  game.stack:push(b)
  local function complete(turn)
   for _=1,12000 do
    assert(game.stack:top()==b,'Prepared rampage left its battle unexpectedly')
    if b.phase=='menu' and not b.current and #b.queue==0 and not b.showPlayerBack
     and not b.showEnemyTrainer and not b:menuLockedAction(b.player)
     and (b.turnCount or 0)==turn then return end
    if b.phase=='messages'then press('b',4)else U.wait(1)end
   end
   error('Native rampage did not return to its ordinary decision menu')
  end
  complete(0);shot('native-rampage-'..row.duration..'-ready',b)
  press('a');assert(b.phase=='moveSelect');press('a',1)
  local captured=0
  for _=1,16000 do
   assert(not b.result and mon.hp>0 and b.enemy.mon.hp>0,'Prepared combatant fainted before fatigue')
   if row.animationStarts>captured and b.gen3AnimPlaying then
    captured=row.animationStarts;U.wait(6)
    shot('native-rampage-'..row.duration..'-attack-'..captured,b)
   end
   if #row.endTurns==row.duration and b.phase=='menu' and not b.current and #b.queue==0 then break end
   if b.phase=='messages'then press('b',4)else U.wait(1)end
  end
  complete(row.duration)
  assert(#row.endTurns==row.duration and row.animationStarts==row.duration,'Original duration/animation count differs')
  assert(captured==row.duration,'A continuation animation never reached the final renderer')
  assert(mon.moves[1].pp==initialPP-1,'A normal locked continuation spent another selected PP')
  assert(b.enemy.mon.hp<b.enemy.mon.stats.hp,'Imported OUTRAGE did not damage its target')
  for n,event in ipairs(row.endTurns) do
   assert(event.before==row.duration-n+1 and event.after==row.duration-n,'Native countdown changed outside end turn')
   assert(event.confusedBefore==0,'Fatigue appeared before the native end-turn counter')
   assert((event.confusedAfter>0)==(n==row.duration),'Fatigue appeared on the wrong original round')
  end
  assert(not b.player.thrashMove and not b.player.thrashTarget and b.player.confusedTurns,'Native lock did not release into fatigue')
  row.finalPP=mon.moves[1].pp;row.fatigue=b.player.confusedTurns
  shot('native-rampage-'..row.duration..'-unlocked-fatigue',b)
 end
 report.drawPreservesSaveRng=true;report.realImportedMoves=true;report.ordinaryMoveSelection=true
 report.status='pass';persist();print('PASS_GEN3_RAMPAGE_NATIVE '..edition);love.event.quit(0)
end
