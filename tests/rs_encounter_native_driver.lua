-- Explicitly prepared native movement/battle fixtures, not ordinary story.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local S=require('src.core.SaveSerializer');local R=require('src.world.Gen3RsEncounterRules')
  local Pokemon=require('src.pokemon.Pokemon');local Battle=require('src.battle.BattleState')
  local version=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(R.active()and require('src.import.RomImporter').readyReport(version).ok)
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..version..'%-'))
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  game.save.party={Pokemon.new(game.data,'RAYQUAZA',100)}
  game.save.inventory={MASTER_BALL=1,POKE_BALL=1}
  local report={edition=version,status='running',preparedEncounterFixture=true,continuousStory=false,
    cases={},captures={},protectedChecks={},drawSaveAndRngPreserved=true}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(k,delay)
    game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(delay or 30)
  end
  local function shot(name)
    local before=S.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
    local ok,why=require('src.render.GraphicsScope').call(top.draw,top);assert(ok,why)
    assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Drawing changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  persist()
  local random=love.math.random;local roll=R.roll;local rolls=0
  love.math.random=function(a,b)
    if a==0 and(b==2879 or b==99)then return 0 end
    return random(a,b)
  end
  R.roll=function(...)rolls=rolls+1;return roll(...)end
  local function setup(map,x,y,facing)
    game.input:reset();game.save.onBike=false;game.save.bikeKind=nil;game.save.surfing=nil
    U.teleport(game,map,x,y,facing);U.wait(90)
    local w=game.overworld
    assert(game.stack:top()==w and not w.runner:isRunning())
    assert(w.rsEncounterImmunity==0 and w.rsEncounterSerial==0,'Map entry is not an encounter step')
    rolls=0;return w
  end
  local function step(w,dir)
    local p=w.player;local x,y=p.cellX,p.cellY
    game.input:overlayPressed(dir)
    local moved=false
    for _=1,160 do
      U.wait(1)
      if(p.cellX~=x or p.cellY~=y)and not p.moving then moved=true;break end
    end
    game.input:overlayReleased(dir);U.wait(4)
    assert(moved and math.abs(p.cellX-x)+math.abs(p.cellY-y)==1,'Expected one physical walking tile')
  end
  local function five(w,forward,back,kind)
    report.protectedChecks[kind]={}
    for i=1,4 do
      step(w,i%2==1 and forward or back)
      assert(game.stack:top()==w and w.rsEncounterImmunity==i and rolls==0,'Early native wild encounter')
      assert(not w:tryWildEncounter()and w.rsEncounterImmunity==i and rolls==0,'Idle poll consumed another check')
      report.protectedChecks[kind][i]=w.rsEncounterImmunity
    end
    shot(kind..'-four-actual-steps-protected')
    step(w,forward);U.wait(240)
    assert(rolls==1 and w.rsEncounterImmunity==0,'Fifth step must reach a real battle and restart immunity')
    local b=game.stack:top();assert(getmetatable(b)==Battle and b.kind=='wild')
    shot(kind..'-fifth-actual-step-wild-battle');return b
  end
  local function menu(b)
    for _=1,40 do if b.phase=='menu'then return end;press('b',45)end
    error('Battle did not reach its menu')
  end
  local function flee(w,b,kind)
    menu(b);assert(b.menuIndex==1);press('down');press('right');press('a',120)
    for _=1,40 do if game.stack:top()==w then break end;press('b',60)end
    assert(game.stack:top()==w and w.rsEncounterImmunity==0,'Actual RUN did not restore a protected field')
    shot(kind..'-native-run-returns-protected-field')
  end
  local w=setup('MAP_G00_N27',25,44,'right')
  assert(w.map:isEncounterCell(25,44)and w.map:isEncounterCell(26,44))
  local b=five(w,'right','left','grass');report.cases.grassFirstFourAndFifth=true
  flee(w,b,'grass');report.cases.actualRunRestarts=true
  rolls=0;b=five(w,'left','right','after-run');report.cases.noImmediateRepeatAfterRun=true
  -- Use the real bag and capture sequence. Prepared Master Ball guarantees
  -- this boundary without replacing the ordinary capture calculation.
  menu(b);press('right');press('a',90)
  local bag=game.stack:top();assert(getmetatable(bag)==require('src.ui.Gen3BagMenu'))
  while bag.pocket~=2 do press('right',60)end
  while bag:selected().id~='MASTER_BALL'do press('down')end
  press('a',120);U.wait(900)
  for _=1,90 do
    if game.stack:top()==w then break end
    local top=game.stack:top()
    if getmetatable(top)==require('src.ui.Gen3RsChoice')then press('b',90)else press('a',90)end
  end
  assert(game.stack:top()==w and #game.save.party==2 and not game.save.inventory.MASTER_BALL)
  assert(w.rsEncounterImmunity==0);shot('native-catch-returns-protected-field')
  report.cases.actualCaptureRestarts=true
  rolls=0
  for i=1,4 do
    step(w,i%2==1 and'right'or'left')
    assert(game.stack:top()==w and w.rsEncounterImmunity==i and rolls==0)
  end
  shot('native-catch-next-four-actual-steps-protected');report.cases.noImmediateRepeatAfterCapture=true
  w=setup('MAP_G24_N14',26,30,'down')
  b=five(w,'down','up','cave');report.cases.caveFirstFourAndFifth=true;flee(w,b,'cave')
  -- Find an actual adjacent pond pair on Route 117, then prepare a surfer.
  w=setup('MAP_G00_N32',10,7,'right');local x,y
  for cy=2,w.map.heightCells-3 do for cx=2,w.map.widthCells-3 do
    if not x and w.map:isWaterCell(cx,cy)and w.map:isWaterCell(cx+1,cy)
      and w.map:cellElevation(cx,cy)==1 and w.map:cellElevation(cx+1,cy)==1 then x,y=cx,cy end
  end end
  assert(x,'Native Route117 pond pair missing')
  w=setup('MAP_G00_N32',x,y,'right');w.player.surfing=true;w.player.elevation=1;game.save.surfing=true
  report.waterPair={x=x,y=y};b=five(w,'right','left','water');report.cases.waterFirstFourAndFifth=true;flee(w,b,'water')
  w=setup('MAP_G00_N02',15,9,'right')
  for i=1,5 do step(w,i%2==1 and'right'or'left')end
  assert(game.stack:top()==w and w.rsEncounterImmunity==4 and rolls==0)
  shot('native-dry-ground-counts-without-rolling');report.cases.dryGroundCounts=true
  w:setMap('MAP_G00_N02',15,9,'right');U.wait(90)
  assert(w.rsEncounterImmunity==0);shot('native-same-map-load-restarts')
  report.cases.sameMapLoadRestarts=true
  game.save.gen3Flute='white';w:setMap('MAP_G00_N02',15,9,'right');U.wait(90)
  assert(not game.save.gen3Flute);report.cases.mapLoadClearsFlute=true
  -- Trainer entry uses the same real world transition path as trainer sight.
  w.rsEncounterImmunity=4
  local trainer=Battle.newTrainer(game,'BEN',1);w:pushBattle(trainer);U.wait(300)
  assert(w.rsEncounterImmunity==0 and game.stack:top()==trainer)
  shot('native-trainer-entry-restarts');report.cases.trainerEntryRestarts=true
  -- Only the source's instance is reset; no counter is serialized into save.
  assert(not game.save.rsEncounterImmunity and not game.save.rsEncounterPrevious)
  report.cases.counterIsRuntimeOnly=true
  love.math.random=random;R.roll=roll
  report.status='pass';persist();print('PASS_RS_NATIVE_ENCOUNTERS');love.event.quit()
end
