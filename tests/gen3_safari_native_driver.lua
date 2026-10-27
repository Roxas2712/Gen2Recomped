-- Prepared Safari fixture; ordinary menu input, case, queue and final renderer.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local V=require('src.core.GameVersion');local edition=V.get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,wait)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 4)end
  local function shot(name)assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()end
  persist();U.freshSave(game);game.save.options.battleLayout='og'
  local P=require('src.pokemon.Pokemon');game.save.party={P.new(game.data,'SCEPTILE',39)}
  U.teleport(game,V.isFRLG()and'MAP_G03_N00'or'MAP_G00_N16',10,12,'up')
  local b=require('src.battle.BattleState').newWild(game,'PIKACHU',25)
  game.save.safari={balls=30,steps=400};b:makeSafari(game.save.safari)
  -- Controlled RNG inputs make the fixture reproducible; the native rules
  -- still decide every outcome. This is not evidence of a story completion.
  b.rng=function(lo,hi)assert(lo==0 and hi==65535);return 199 end
  game.stack:push(b)
  local function menu()
    for _=1,4000 do
      if b.phase=='menu'and not b.current and #b.queue==0 then return end
      if b.phase=='messages'then press('b')else U.wait(1)end
    end
    error('Safari queue did not return to menu')
  end
  menu();assert(b.showPlayerBack and b.gen3Safari)
  local G=require('src.battle.Gen3Safari');local R=require('src.battle.Gen3SafariRules')
  assert(require('src.import.Gen3SafariAssets').valid(game.data.constants.gen3SafariNative,edition))
  report.labels=game.data.constants.gen3SafariNative.labels
  report.prompt=G.text(b,'prompt');report.initialCatchRate=b.safariCatchRate
  shot('native-safari-action-menu')
  local S=require('src.core.SaveSerializer');local saveBefore=S.encode(game.save);local randomBefore=love.math.getRandomState()
  b:draw();assert(S.encode(game.save)==saveBefore and love.math.getRandomState()==randomBefore)
  if R.isHoenn(edition)then
    local blocks=require('src.inventory.Pokeblocks')
    local block={flavours={10,0,0,0,0},feel=20,colour=1};blocks.case(game.save)[7]=block
    press('right');press('a',20);local case=game.stack:top()
    assert(case.pickOnly and case~=b and b.waitingUI)
    shot('native-safari-pokeblock-selection');press('b',20)
    assert(game.stack:top()==b and b.phase=='menu'and blocks.case(game.save)[7]==block)
    assert(b.gen3Safari.pokeblockThrows==0 and game.save.safari.balls==30)
    press('a',20);press('a',10)
    assert(blocks.case(game.save)[7]==nil and b.gen3Safari.pokeblockThrows==1)
    menu();shot('native-safari-after-pokeblock')
    -- Empty case has a selectable exit and does not create a turn.
    press('a',20);assert(game.stack:top().rows[1].close);press('a',20)
    assert(b.phase=='menu'and b.gen3Safari.pokeblockThrows==1)
    press('left');press('down');press('a',8);menu()
    assert(b.gen3Safari.goNearCounter==1);shot('native-safari-after-go-near')
  else
    press('right');press('a',8);menu()
    assert(b.gen3Safari.baitCounter>0);shot('native-safari-after-bait')
    press('left');press('down');press('a',8);menu()
    assert(b.gen3Safari.rockCounter>0 and b.gen3Safari.baitCounter==0);shot('native-safari-after-rock')
  end
  -- Failed throw must return through the shared ball animation and update
  -- the separate native Safari counter without a Pokemon HP/EXP overlay.
  press('up');local n=0;b.rng=function(lo,hi)assert(lo==0 and hi==65535);n=n+1;return n==1 and 199 or 65535 end
  press('a',8);menu();assert(game.save.safari.balls==29 and n==2)
  shot('native-safari-after-missed-ball')
  report.catchRate=b.safariCatchRate;report.fleePercent=R.fleePercent(b.gen3Safari)
  report.drawSaveRngUnchanged=true;report.cancelAndConsumptionPassed=true
  press('right');press('down');press('a',8)
  assert(b.result=='run'and b.afterQueue=='finish'and game.save.safari.balls==29)
  for _=1,4000 do
    if game.stack:top()==game.overworld then break end
    if game.stack:top()==b and b.phase=='messages'then press('b')else U.wait(1)end
  end
  assert(game.stack:top()==game.overworld,'Safari run failed to resume field')
  report.status='pass';persist();print('PASS_NATIVE_GBA_SAFARI');love.event.quit(0)
end
