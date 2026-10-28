-- Prepared near-level fixture; actual attack, EXP queue and ordinary inputs.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local edition=V.get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local report={edition=edition,status='running',preparedBattleFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 4)
  end
  persist();U.freshSave(game)
  game.save.options.battleLayout='og';game.save.options.battleAnimations=false
  local P=require('src.pokemon.Pokemon');local mon=P.new(game.data,'SCEPTILE',39)
  local def=game.data.pokemon.SCEPTILE
  mon.exp=require('src.pokemon.Growth').expForLevel(def.growthRate,40,game.data.growth_rates)-1
  mon.moves={{id='TACKLE',pp=35}};game.save.party={mon}
  U.teleport(game,V.isFRLG()and'MAP_G03_N00'or'MAP_G00_N16',10,12,'up')
  local Battle=require('src.battle.BattleState');local b=Battle.newWild(game,'ROSELIA',1)
  b.enemy.mon.hp=1;b.enemy.shownHP=1;b.enemy.curMoves={{id='SPLASH',pp=40}};b.enemy.mon.moves=b.enemy.curMoves
  game.stack:push(b)
  local function menu()
    for _=1,3000 do
      if b.phase=='menu'and not b.current and #b.queue==0 and not b.showPlayerBack then return end
      if b.phase=='messages'then press('b')else U.wait(1)end
    end
    error('Battle intro did not complete')
  end
  menu();local screen
  for _=1,4000 do
    local top=game.stack:top()
    if getmetatable(top)==Battle.StatBox then screen=top;break end
    if top==b then
      if b.phase=='menu'or b.phase=='moveSelect'then press('a',12)
      elseif b.phase=='messages'then press('b')else U.wait(1)end
    else U.wait(1)end
  end
  assert(screen and screen.native,'Actual EXP award did not open native stats')
  assert(screen.uiSize,'Native stat overlay must declare its GBA surface')
  local ox,oy=require('src.core.Game').homeOffset(screen,240,160)
  assert(ox==0 and oy==0,'Stat overlay inherited the GB centering offset')
  assert(mon.level==40 and screen.native.scene._page==1)
  local old,new=screen.native.scene._oldStats,screen.native.scene._newStats
  assert(old.maxHp<new.maxHp and new.maxHp==mon.stats.hp,'HP gain was not captured before recalculation')
  shot('native-stat-growth-increases')
  press('a',4)
  assert(game.stack:top()==screen and screen.native.scene._page==2,'First acknowledgment must show totals')
  local S=require('src.core.SaveSerializer');local before,rng=S.encode(game.save),love.math.getRandomState()
  screen:draw();assert(S.encode(game.save)==before and love.math.getRandomState()==rng,'Stats drawing mutated gameplay')
  shot('native-stat-growth-totals');press('b',4)
  assert(game.stack:top()==b and not screen.native.scene.isOpen(),'Second acknowledgment must resume combat')
  for _=1,3000 do
    if game.stack:top()==game.overworld then break end
    if game.stack:top()==b and b.phase=='messages'then press('b')else U.wait(1)end
  end
  assert(game.stack:top()==game.overworld,'Stat window failed to resume victory/field')
  -- The field Rare Candy flow must share these native pages and keep its
  -- item consumption, move-learning continuation and caller intact.
  game.save.inventory={RARE_CANDY=1};game.save.bagOrder={'RARE_CANDY'}
  local bag=require('src.ui.Gen3BagMenu').new(game)
  game.stack:push(bag);U.wait(30);assert(bag:selected().id=='RARE_CANDY')
  press('a',30)
  for _=1,4 do
    if game.stack:top().screenId=='Gen3PartyMenu'then break end
    press('a',30)
  end
  assert(game.stack:top().screenId=='Gen3PartyMenu','Candy must ask for an ordinary party target')
  press('a',30)
  local candy
  for _=1,1200 do
    local top=game.stack:top()
    if top.native and top.native.scene and top.native.scene.isOpen()then candy=top;break end
    press('a',12)
  end
  assert(candy and mon.level==41 and not game.save.inventory.RARE_CANDY,'Candy stat window/consumption failed')
  assert(candy.native.scene._oldStats.maxHp<candy.native.scene._newStats.maxHp,'Candy lost its pre-level HP')
  shot('native-stat-growth-candy-increases');press('a',4)
  assert(game.stack:top()==candy and candy.native.scene._page==2)
  shot('native-stat-growth-candy-totals');press('b',12)
  assert(not candy.native.scene.isOpen()and mon.level==41 and not game.save.inventory.RARE_CANDY)
  report.nativeCandyPages=true;report.oneCandyConsumed=true
  report.sixNativeStatLabels=#screen.native.spec.labels
  report.actualExpAward=true;report.oldMaxHp=old.maxHp;report.newMaxHp=new.maxHp
  report.twoAcknowledgments=true;report.queueResumedOnce=true;report.drawSaveRngUnchanged=true
  report.status='pass';persist();print('PASS_NATIVE_STAT_GROWTH',edition);love.event.quit(0)
end
