-- Prepared real-ROM battles; ordinary battle input, no continuous-story claim.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local edition=V.get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(V.isGen3()and love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local report={edition=edition,status='running',preparedBattleFixture=true,continuousStory=false,captures={},nativeBindingMoves={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  persist()
  local ids={}
  for id,move in pairs(game.data.moves)do
    local n=tonumber(move.index or move.numId)
    if n then ids[n]=id end
  end
  for _,n in ipairs({20,35,83,128,250,328})do
    local def=assert(game.data.moves[assert(ids[n])])
    assert(def.gen3Effect==42 and def.effect=='TRAPPING_EFFECT','Imported binding effect mismatch '..n)
    report.nativeBindingMoves[#report.nativeBindingMoves+1]={index=n,id=def.id,effect=def.gen3Effect}
  end
  U.freshSave(game);game.save.options.battleLayout='og';game.save.options.battleAnimations=false
  local P=require('src.pokemon.Pokemon')
  local mon=P.new(game.data,'CHARMANDER',30)
  mon.hp,mon.stats.hp=400,400;mon.moves={{id=assert(ids[33]),pp=10}}
  game.save.party={mon}
  local kanto=edition=='firered'or edition=='leafgreen'
  U.teleport(game,kanto and'MAP_G03_N00'or'MAP_G00_N16',10,kanto and 10 or 12,'down')
  local b=require('src.battle.BattleState').newWild(game,'CHARMANDER',30)
  b:syncSides();b.enemy.mon.hp,b.enemy.mon.stats.hp=400,400
  b.enemy.curMoves={{id=assert(ids[20]),pp=10}};b.enemy.mon.moves=b.enemy.curMoves
  b.player.curStats.speed,b.enemy.curStats.speed=100,200
  b.player.abilityOverride,b.enemy.abilityOverride=false,false
  b.phase,b.queue,b.frame,b.menuIndex,b.moveIndex='menu',{},0,1,1
  b.rng=function(lo)return lo or 0 end
  game.stack:push(b)
  local function press(key)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(4)
  end
  local function shot(name)
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function complete(turn)
    for _=1,2500 do
      if b.phase=='menu'and(b.turnCount or 0)==turn and not b.current and #b.queue==0
        and(not b.introSlide or b.introSlide<=0)then return end
      if b.phase=='messages'then press('b')else U.wait(1)end
    end
    error('Native binding turn did not return to menu: '..tostring(b.phase))
  end
  complete(0)
  press('a');assert(b.phase=='moveSelect','Native FIGHT is not ready: '..tostring(b.phase));press('a');complete(1)
  assert(require('src.battle.Gen3PartialTrap').active(b.player),'Real imported BIND did not bind')
  assert(not b.enemy.trappingTurns and not b.player.boundTurns,'Gen1 forced lock leaked into GBA')
  assert(mon.moves[1].pp==9 and b.enemy.curMoves[1].pp==9,'First ordinary turn did not spend both move PP')
  report.firstTurn={playerHP=mon.hp,enemyHP=b.enemy.mon.hp,duration=b.player.gbaWrapTurns,pp=mon.moves[1].pp}
  shot('native-bind-command-menu')
  press('a');assert(b.phase=='moveSelect','Bound FIGHT must open the actual move list')
  shot('native-bind-independent-move-selection')
  press('a');complete(2)
  assert(mon.moves[1].pp==8 and b.enemy.curMoves[1].pp==8,'Bound victim did not execute and pay for next selected move')
  assert(b.enemy.mon.hp<report.firstTurn.enemyHP,'Bound victim did not damage its opponent')
  report.secondTurn={playerHP=mon.hp,enemyHP=b.enemy.mon.hp,duration=b.player.gbaWrapTurns,pp=mon.moves[1].pp}
  shot('native-bind-next-turn-complete')
  -- Flannery's ordinary battle exposed White Smoke blocking her own cost.
  -- Repeat the actual imported move through normal input with noncritical RNG.
  U.teleport(game,kanto and'MAP_G03_N00'or'MAP_G00_N16',10,kanto and 10 or 12,'down')
  mon=P.new(game.data,'TORKOAL',28)
  mon.hp,mon.stats.hp=400,400;mon.moves={{id=assert(ids[315]),pp=5}};game.save.party={mon}
  b=require('src.battle.BattleState').newWild(game,'GROVYLE',34)
  b:syncSides();b.enemy.mon.hp,b.enemy.mon.stats.hp,b.enemy.shownHP=1000,1000,1000
  b.enemy.curMoves={{id=assert(ids[317]),pp=10}};b.enemy.mon.moves=b.enemy.curMoves
  b.player.curStats.speed,b.enemy.curStats.speed=200,100
  assert(require('src.battle.Abilities').of(b.player)=='WHITE_SMOKE','Torkoal must retain its ROM ability')
  b.rng=function(lo,hi)if lo==1 and hi==100 then return 1 end;if hi==65535 then return 35 end;return hi or lo end
  b.phase,b.queue,b.frame,b.menuIndex,b.moveIndex='menu',{},0,1,1;game.stack:push(b);complete(0)
  press('a');press('a');complete(1)
  report.nativeSelfCostFirst={spatk=b.player.stages.spatk,lastMove=b.player.lastMove,enemyHP=b.enemy.mon.hp,pp=mon.moves[1].pp,
    move=mon.moves[1].id};persist()
  assert(b.player.stages.spatk==-2,'Native first Overheat cost: '..tostring(b.player.stages.spatk)..' last='..tostring(b.player.lastMove)..' hp='..tostring(b.enemy.mon.hp))
  local first=1000-b.enemy.mon.hp;local before=b.enemy.mon.hp
  assert(first>0 and mon.moves[1].pp==4 and(b.player.stages.speed or 0)==0,'Native first Overheat/White Smoke protection failed')
  shot('native-overheat-own-stat-cost')
  press('a');press('a');complete(2)
  local second=before-b.enemy.mon.hp
  assert(b.player.stages.spatk==-4 and mon.moves[1].pp==3,'Native repeat Overheat cost/PP failed')
  assert(second>0 and second<first,'Actual second Overheat did not become weaker')
  assert((b.player.stages.speed or 0)==0,'White Smoke must block the opponent\'s 100% Rock Tomb stat drop')
  assert(b.enemy.curMoves[1].pp==8,'Opponent must actually execute both imported Rock Tomb attacks')
  report.nativeSelfCost={ability='WHITE_SMOKE',firstDamage=first,secondDamage=second,spatk=-4,pp=3,opponentRockTombBlocked=true}
  shot('native-overheat-second-turn-weaker')
  report.independentMoveSelection=true;report.realImportedMoves=true;report.nativeRenderer=true
  report.status='pass';persist();print('PASS_GEN3_PARTIAL_TRAP_NATIVE '..edition);love.event.quit(0)
end
