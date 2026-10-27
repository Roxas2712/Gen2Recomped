-- Prepared ROM field/encounter fixture, separate from the ordinary story.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local edition=require('src.core.GameVersion').get();assert(edition=='ruby'or edition=='sapphire')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local report={edition=edition,status='running',preparedFieldAndBattleFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()end
  local function press(key,n)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(n or 12)end
  U.freshSave(game);game.save.options.battleAnimations=false;game.save.options.battleLayout='og'
  local mon=require('src.pokemon.Pokemon').new(game.data,'GROVYLE',100)
  mon.moves={{id='LEAF_BLADE',pp=15}};game.save.party={mon}
  assert(game.data.constants.gen3BuriedMovement==63,'Actual RS buried movement derivation changed')
  local function npc(id)
    for _,actor in ipairs(game.overworld.npcs)do if actor.def.localId==id then return actor end end
    error('Missing actual gym object '..id)
  end
  U.teleport(game,'MAP_G04_N01',8,22,'up');U.wait(240)
  local ids={2,3,4,5,7};report.initial={}
  for _,id in ipairs(ids)do
    local actor=npc(id)
    assert(actor.gen3MovementType==63 and actor.hidden and actor.buried,'Transition did not hide unbeaten trainer '..id)
    assert(not actor.gen3Hidden,'Burial must remain distinct from permanent invisibility')
    report.initial[#report.initial+1]={localId=id,movement=actor.gen3MovementType,hidden=actor.hidden,buried=actor.buried}
  end
  shot('native-lavaridge-unbeaten-trainers-buried')
  -- Enter its real range; actual sight/approach must reveal the same object.
  U.teleport(game,'MAP_G04_N01',4,18,'up');press('up',30);U.wait(180)
  local zane=npc(3)
  assert(not zane.buried and not zane.hidden,'Actual trainer approach failed to reveal Zane')
  shot('native-lavaridge-trainer-revealed-on-approach')
  local Battle=require('src.battle.BattleState');local observed
  for _=1,2500 do
    local top=game.stack:top()
    if getmetatable(top)==Battle then
      observed=top
      if top.phase=='menu'or top.phase=='moveSelect'then press('a')
      elseif top.phase=='messages'then press('b')else U.wait(1)end
    elseif game.overworld==top and observed and not(game.overworld.runner and game.overworld.runner:isRunning())then break
    elseif top and top.pages then press('a')else U.wait(1)end
  end
  assert(observed and observed.result=='win','Prepared encounter did not finish through ordinary battle input')
  assert(game.overworld:trainerDefeated(zane),'Actual trainer victory flag was not produced')
  U.teleport(game,'MAP_G04_N01',8,22,'up');U.wait(240)
  zane=npc(3)
  assert(not zane.hidden and not zane.buried,'Defeated trainer was buried again on actual map re-entry')
  for _,id in ipairs({2,4,5,7})do
    local actor=npc(id);assert(actor.hidden and actor.buried,'Unbeaten trainer became visible after another trainer won '..id)
  end
  report.actualTransitionScript=true;report.actualSightReveals=true;report.actualVictoryPersists=true
  report.reentryPreservesUnbeatenBurial=true;report.nativeRenderer=true
  shot('native-lavaridge-defeated-trainer-visible-after-reentry')
  report.status='pass';persist();print('PASS_RS_BURIED_TRAINERS_NATIVE '..edition);love.event.quit(0)
end
