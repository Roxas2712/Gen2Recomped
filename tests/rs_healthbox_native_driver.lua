-- Prepared own-ROM display/item fixture; never an ordinary-story receipt.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local version=require('src.core.GameVersion').get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert((version=='ruby'or version=='sapphire')and love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'))
  assert(require('src.import.RomImporter').readyReport(version).ok)
  assert(#require('src.import.Gen3RsHealthboxAssets').missing(version)==0)
  local report={edition=version,status='running',preparedBattleFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  persist();U.freshSave(game)
  game.save.options.battleLayout='og';game.save.options.battleAnimations=false
  local P=require('src.pokemon.Pokemon')
  local mon=P.new(game.data,'SCEPTILE',39)
  mon.stats.hp=114;mon.hp=44;mon.status='PSN';mon.nickname='AAAAAAAAAA';mon.personality=255
  game.save.party={mon};game.save.inventory={ANTIDOTE=1,SUPER_POTION=1};game.save.bagOrder={'ANTIDOTE','SUPER_POTION'}
  U.teleport(game,'MAP_G00_N34',35,85,'up')
  local b=require('src.battle.BattleState').newWild(game,'ROSELIA',27)
  b:syncSides();b.player.shownHP=44;b.player.shownStatus='PSN'
  b.enemy.mon.personality=255;b.enemy.curMoves={{id='SPLASH',pp=40}};b.enemy.mon.moves=b.enemy.curMoves
  b.phase,b.queue,b.frame,b.menuIndex,b.moveIndex='menu',{},0,1,1
  game.stack:push(b)
  for _=1,2000 do
    if b.phase=='menu'and not b.current and #b.queue==0 and(not b.introSlide or b.introSlide<=0)then break end
    if b.phase=='messages'then
      game.input:overlayPressed('b');U.wait(1);game.input:overlayReleased('b');U.wait(4)
    else U.wait(1)end
  end
  assert(b.phase=='menu'and not b.showPlayerBack,'Original encounter intro must finish before HUD input checks')
  local Native=require('src.battle.Gen3Battle')
  local x,y=Native.healthboxGeometry(b,0)
  assert(x==126 and y==72,'Player must retain the 64x32 OAM origin')
  local ex,ey=Native.healthboxGeometry(b,1)
  assert(ex==12 and ey==14,'Opponent must use its native OAM origin')
  local Serialize=require('src.core.SaveSerializer')
  local saved,rng=Serialize.encode(game.save),love.math.getRandomState()
  love.graphics.push('all');b:draw();love.graphics.pop()
  assert(Serialize.encode(game.save)==saved and love.math.getRandomState()==rng,'HUD drawing changed gameplay state')
  local oracle=require('tests.rs_healthbox_reference').new(game,b)
  report.reference={commit='fb7b0366efcb85e703e9e6d5a8a24d01456a109b',comparisons={}}
  local function compare(name)
    local result=oracle.compare(out,name,shot);report.reference.comparisons[name]=result;persist()
    assert(result.differences==0,'Native healthbox differs from pinned reference: '..name..' '..J.encode(result))
  end
  compare('rs-healthbox-level39-poison-long-name')
  local oldLevel,oldName=mon.level,mon.nickname
  mon.level=100;mon.nickname='SCEPTILE';b.player.name='SCEPTILE';mon.personality=0
  U.wait(3);compare('rs-healthbox-level100-female')
  mon.level=1;U.wait(3);compare('rs-healthbox-level1-female')
  for _,status in ipairs({'PAR','SLP','FRZ','BRN'})do
    mon.status=status;b.player.shownStatus=status;U.wait(3)
    compare('rs-healthbox-status-'..status)
  end
  mon.status='PSN';b.player.shownStatus='PSN'
  mon.level=oldLevel;mon.nickname=oldName;b.player.name=oldName;mon.personality=255
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 3)
  end
  press('right');press('a',30)
  assert(game.stack:top().screenId=='Gen3BagMenu')
  assert(game.stack:top():selected().id=='ANTIDOTE')
  press('a',30);assert(game.stack:top().screenId=='Gen3PartyMenu')
  press('a',8)
  assert(game.stack:top()==b,'Medicine must use the native battle queue, not a field TextBox')
  assert(not mon.status and not b.player.shownStatus,'Cured status must leave the HUD before its message')
  assert(not game.save.inventory.ANTIDOTE,'Exactly one Antidote must be consumed')
  compare('rs-healthbox-cured-native-battle-message')
  for _=1,2000 do
    if b.phase=='menu'and not b.current and #b.queue==0 then break end
    if b.phase=='messages'then press('b')else U.wait(1)end
  end
  assert(b.phase=='menu'and #b.queue==0,'Item action must return to the command menu')
  assert(b.enemy.curMoves[1].pp==39,'The enemy must execute exactly one response')
  assert(mon.hp==44 and not mon.status,'Harmless enemy reply must preserve the cured battler')
  shot('rs-healthbox-cured-next-command-menu')
  if b.menuIndex%2==1 then press('right')end
  if b.menuIndex>2 then press('up')end
  press('a',30);assert(game.stack:top().screenId=='Gen3BagMenu')
  assert(game.stack:top():selected().id=='SUPER_POTION')
  press('a',30);assert(game.stack:top().screenId=='Gen3PartyMenu');press('a',8)
  assert(game.stack:top()==b and mon.hp==94 and not game.save.inventory.SUPER_POTION)
  for _=1,400 do
    if b.current and b.current.text and b.current.text:find('restored',1,true)then break end
    U.wait(1)
  end
  assert(b.current and b.current.text and b.current.text:find('restored',1,true),'HP medicine text never entered the battle queue')
  assert(b.player.shownHP==94,'HP medicine text preceded its visible HP restoration')
  compare('rs-healthbox-healed-before-medicine-message')
  for _=1,2000 do
    if b.phase=='menu'and not b.current and #b.queue==0 then break end
    if b.phase=='messages'then press('b')else U.wait(1)end
  end
  assert(b.phase=='menu'and b.enemy.curMoves[1].pp==38 and mon.hp==94,'Second medicine must spend one item and one enemy response')
  -- Use an actual imported double-battle trainer and the engine's own four
  -- admitted battlers; do not replace battlerAt or the double-render gates.
  game.stack:pop()
  game.save.party={mon,P.new(game.data,'NUMEL',30)}
  local trainers={}
  for id,t in pairs(game.data.trainers)do
    if t.doubleBattle and t.parties and t.parties[1]and #t.parties[1]>=2 then trainers[#trainers+1]=id end
  end
  table.sort(trainers);assert(#trainers>0,'No native RS double trainer imported')
  b=require('src.battle.BattleState').newTrainer(game,trainers[1],1)
  assert(b:isDouble());game.stack:push(b)
  for _=1,3000 do
    if b.phase=='menu'and not b.current and #b.queue==0 and not b.showPlayerBack and not b.showEnemyTrainer then break end
    if b.phase=='messages'then press('b')else U.wait(1)end
  end
  assert(b.phase=='menu'and b:battlerAt(2)and b:battlerAt(3),'Double encounter intro did not admit all four battlers')
  local statuses={'PSN','PAR','BRN','SLP'}
  for id=0,3 do local battler=b:battlerAt(id);battler.mon.status=statuses[id+1];battler.shownStatus=statuses[id+1]end
  U.wait(30)
  oracle=require('tests.rs_healthbox_reference').new(game,b)
  compare('rs-healthbox-four-native-double-panels')
  report.nativeDoubleTrainer=trainers[1]
  report.singleOamOrigins=true;report.drawSaveAndRngUnchanged=true
  report.nativeMedicineQueue=true;report.curedStatusBeforeMessage=true;report.oneEnemyReplyPerMedicine=true
  report.hpDrainBeforeMedicineMessage=true
  report.status='pass';persist();print('PASS_RS_NATIVE_HEALTHBOX');love.event.quit(0)
end
