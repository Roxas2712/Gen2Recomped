-- Actual final-render and medicine inputs; prepared fixtures, no story claim.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local edition=V.get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(V.isGen3()and love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local report={edition=edition,status='running',preparedBattleFixture=true,continuousStory=false,
    captures={},referencePixelParity=false}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 4)
  end
  persist();U.freshSave(game)
  game.save.options.battleLayout='og';game.save.options.battleAnimations=false
  local mon=require('src.pokemon.Pokemon').new(game.data,'SCEPTILE',39)
  mon.stats.hp=114;mon.hp=44;mon.status='PSN';mon.nickname='AAAAAAAAAA'
  game.save.party={mon};game.save.inventory={ANTIDOTE=1};game.save.bagOrder={'ANTIDOTE'}
  U.teleport(game,V.isFRLG()and'MAP_G03_N00'or'MAP_G00_N16',10,12,'up')
  local b=require('src.battle.BattleState').newWild(game,'ROSELIA',27)
  b:syncSides();b.enemy.curMoves={{id='SPLASH',pp=40}};b.enemy.mon.moves=b.enemy.curMoves
  game.stack:push(b)
  local function complete()
    for _=1,2000 do
      if b.phase=='menu'and not b.current and #b.queue==0 and not b.showPlayerBack then return end
      if b.phase=='messages'then press('b')else U.wait(1)end
    end
    error('Native battle did not reach its command menu')
  end
  complete()
  local Native=require('src.battle.Gen3Battle')
  local x,y=Native.healthboxGeometry(b,0);assert(x==126 and y==72)
  x,y=Native.healthboxGeometry(b,1);assert(x==12 and y==14)
  local S=require('src.core.SaveSerializer');local before,rng=S.encode(game.save),love.math.getRandomState()
  love.graphics.push('all');b:draw();love.graphics.pop()
  assert(S.encode(game.save)==before and love.math.getRandomState()==rng,'Drawing changed gameplay data')
  shot('native-gba-hud-poison-level39-long-name')
  assert(require('src.battle.Gen3NativeHealthbox').available(b),'Native healthbox assets not selected')
  mon.level=100;U.wait(2);shot('native-gba-hud-level100')
  mon.level=1;U.wait(2);shot('native-gba-hud-level1');mon.level=39
  for _,status in ipairs({'PAR','SLP','FRZ','BRN'})do
    mon.status=status;b.player.shownStatus=status;U.wait(2);shot('native-gba-hud-status-'..status)
  end
  mon.status='PSN';b.player.shownStatus='PSN'
  report.levelGlyphCode=0x105;report.untrimmedNativeSmallFont=true
  press('right');press('a',30);assert(game.stack:top().screenId=='Gen3BagMenu')
  assert(game.stack:top():selected().id=='ANTIDOTE')
  press('a',30);assert(game.stack:top().screenId=='Gen3PartyMenu');press('a',8)
  assert(game.stack:top()==b,'GBA medicine must retain its battle presentation owner')
  assert(not mon.status and not b.player.shownStatus,'Status badge survived successful cure')
  assert(not game.save.inventory.ANTIDOTE,'Antidote count did not update once')
  shot('native-gba-hud-cured-battle-message');complete()
  assert(b.enemy.curMoves[1].pp==39 and mon.hp==44,'Medicine did not execute exactly one harmless enemy reply')
  shot('native-gba-hud-cured-command-menu')
  game.stack:pop()
  game.save.party={mon,require('src.pokemon.Pokemon').new(game.data,'NUMEL',30)}
  local trainers={}
  for id,t in pairs(game.data.trainers)do
    if t.doubleBattle and t.parties and t.parties[1]and #t.parties[1]>=2 then trainers[#trainers+1]=id end
  end
  table.sort(trainers);assert(#trainers>0,'No actual double trainer imported')
  b=require('src.battle.BattleState').newTrainer(game,trainers[1],1)
  assert(b:isDouble());game.stack:push(b)
  for _=1,3000 do
    if b.phase=='menu'and not b.current and #b.queue==0 and not b.showPlayerBack and not b.showEnemyTrainer then break end
    if b.phase=='messages'then press('b')else U.wait(1)end
  end
  assert(b.phase=='menu'and b:battlerAt(2)and b:battlerAt(3),'Native double intro did not admit all four battlers')
  for id,status in ipairs({'PSN','PAR','BRN','SLP'})do
    local battler=b:battlerAt(id-1);battler.mon.status=status;battler.shownStatus=status
  end
  U.wait(2);shot('native-gba-hud-four-double-panels')
  report.nativeDoubleTrainer=trainers[1]
  report.nativeOamGeometry=true;report.nativeMedicineQueue=true;report.oneEnemyReply=true
  report.drawSaveAndRngUnchanged=true;report.status='pass';persist()
  print('PASS_NATIVE_GBA_HEALTHBOX_SMOKE',edition);love.event.quit(0)
end
