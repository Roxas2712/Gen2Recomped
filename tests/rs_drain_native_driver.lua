-- Prepared native battle fixtures, explicitly separate from ordinary story.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local V=require('src.core.GameVersion')
  local Battle=require('src.battle.BattleState');local Pokemon=require('src.pokemon.Pokemon')
  local Abilities=require('src.battle.Abilities');local edition=V.get()
  assert(edition=='ruby'or edition=='sapphire')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local report={edition=edition,status='running',preparedDrainFixture=true,continuousStory=false,
    cases={},captures={},drawSaveAndRngPreserved=true,callbacksReturned=0}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(button,frames)
    game.input:overlayPressed(button);U.wait(3);game.input:overlayReleased(button);U.wait(frames or 20)
  end
  local function shot(name)
    local before=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(before==Save.encode(game.save)and rng==love.math.getRandomState(),'Drain draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function waitFor(fn,n,label,advance)
    for _=1,n do if fn()then return end;if advance then advance()else U.wait(1)end end
    error(label..' timed out; top='..tostring(game.stack:top())..' phase='..tostring(game.stack:top()and game.stack:top().phase))
  end
  local specs={
    {name='one-hp-overkill',species='GEODUDE',hp=1,expected=8},
    {name='twenty-five-hp-overkill',species='GEODUDE',level=25,hp=25,expected=19},
    {name='substitute-five-hp',species='GEODUDE',level=25,hp=50,sub=5,expected=9},
    {name='liquid-ooze-six-hp',species='TENTACOOL',hp=6,ooze=true,expected=4},
    {name='dream-eater-ooze',species='TENTACOOL',hp=6,ooze=true,dream=true,expected=10},
    {name='liquid-ooze-double-faint',species='TENTACOOL',hp=1,ooze=true,userHP=1,expected=0},
  }
  persist()
  for _,spec in ipairs(specs)do
    U.freshSave(game)
    local move=spec.dream and 'DREAM_EATER'or 'ABSORB'
    local mon=Pokemon.new(game.data,spec.dream and 'GENGAR'or 'GROVYLE',spec.dream and 40 or 21)
    local basePP=assert(game.data.moves[move].pp)
    mon.moves={{id=move,pp=basePP,maxPp=basePP}};mon.hp=spec.userHP or 7
    local backup=Pokemon.new(game.data,'ZIGZAGOON',5)
    Battle.stampOT(game.save,mon);Battle.stampOT(game.save,backup)
    game.save.party={mon,backup}
    U.teleport(game,'MAP_G03_N01',7,7,'up');U.wait(120)
    local world=game.overworld;local b=Battle.newWild(game,spec.species,spec.level or 8)
    assert(spec.hp>0 and spec.hp<=b.enemy.mon.stats.hp,'Prepared target HP exceeds native max')
    b.enemy.mon.hp=spec.hp;b.enemy.shownHP=spec.hp;b.enemy.mon.item=nil
    b.enemy.mon.abilitySlot=spec.ooze and 2 or 1
    if spec.ooze then assert(Abilities.of(b.enemy)=='LIQUID_OOZE')end
    if spec.dream then b.enemy.mon.status='SLP';b.enemy.mon.sleepTurns=5;b.enemy.sleepTurns=5 end
    if spec.sub then b.enemy.substituteHP=spec.sub end
    -- The surviving Substitute case uses a harmless native enemy move so
    -- later enemy damage cannot obscure the independently checked heal.
    b.enemy.curMoves={{id='SPLASH',pp=40,maxPp=40}}
    local row={beforeHP=mon.hp,targetHP=spec.hp,expectedHP=spec.expected,hits={},faints={}}
    report.cases[spec.name]=row
    local apply=b.applyDamage
    b.applyDamage=function(self,who,damage,...)
      local before=who.mon.hp;local sub=who.substituteHP
      local dealt,endured=apply(self,who,damage,...)
      row.hits[#row.hits+1]={isPlayer=who.isPlayer,rolled=damage,before=before,after=who.mon.hp,
        substituteBefore=sub,dealt=dealt}
      return dealt,endured
    end
    local faint=b.onFaint
    b.onFaint=function(self,who,...)
      if not who.faintQueued then row.faints[#row.faints+1]=who.isPlayer and 'attacker'or 'defender'end
      return faint(self,who,...)
    end
    world:pushBattle(b)
    waitFor(function()return game.stack:top()==b and b.phase=='menu'end,12000,'Native drain menu',function()
      if game.stack:top()==b and b.phase=='messages'then press('b',12)else U.wait(1)end
    end)
    shot('drain-'..spec.name..'-before')
    press('a');assert(b.phase=='moveSelect','Fight input did not enter native move selection')
    press('a')
    for _=1,18000 do
      if mon.hp==spec.expected and #row.hits>0 then break end
      if game.stack:top()==b and b.phase=='messages'then press('b',12)else U.wait(1)end
    end
    assert(mon.hp==spec.expected,'Native '..spec.name..' healed/drained wrong HP: '..tostring(mon.hp))
    assert(row.hits[1].rolled>spec.hp or spec.sub,'Fixture did not actually overkill')
    assert(row.hits[1].dealt==(spec.sub or spec.hp),'Native hit did not record capped actual loss')
    if spec.sub then
      waitFor(function()return game.stack:top()==b and b.phase=='messages'or b.phase=='menu'end,12000,'Substitute aftermath')
      for _=1,2000 do
        if game.stack:top()==b and b.phase=='menu'then break end
        if game.stack:top()==b and b.phase=='messages'then press('b',12)else U.wait(1)end
      end
      assert(b.phase=='menu'and b.enemy.mon.hp==spec.hp and not b.enemy.substituteHP)
      assert(mon.hp==spec.expected)
      shot('drain-'..spec.name..'-after')
      press('right');press('down');assert(b.menuIndex==4,'Native RUN selection failed');press('a',120)
    end
    for _=1,18000 do
      if game.stack:top()==world and not world.runner:isRunning()then break end
      if game.stack:top()==b and b.phase=='messages'then press('b',12)
      elseif game.stack:top()~=b and game.stack:top()~=world then
        -- Native faint/experience overlays acknowledge ordinary B; no
        -- replacement party is injected and the prepared backup stays alive.
        press('b',12)
      else U.wait(1)end
    end
    assert(game.stack:top()==world and not world.runner:isRunning(),'Drain callback did not return to original field')
    assert(mon.hp==spec.expected,'Later callback changed the tested heal')
    if not spec.sub then shot('drain-'..spec.name..'-after')end
    if spec.userHP==1 then
      assert(row.faints[1]=='attacker'and row.faints[2]=='defender'and #row.faints==2,'Native Liquid Ooze faint order/callback count')
      assert(backup.hp==backup.stats.hp,'Native backup changed during double faint')
    end
    row.afterHP=mon.hp;row.returnedToField=true;row.status='pass'
    report.callbacksReturned=report.callbacksReturned+1;persist()
  end
  report.status='pass';persist();love.event.quit(0)
end
