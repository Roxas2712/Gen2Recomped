return function(game)
  io.stdout:setvbuf('no')
  local U=require('tests.drivers.util')
  local V=require('src.core.GameVersion')
  local J=require('src.link.Json')
  local Serialize=require('src.core.SaveSerializer')
  local Pokemon=require('src.pokemon.Pokemon')
  local Summary=require('src.ui.Gen3SummaryMenu')
  local edition=V.get()
  assert(love.filesystem.getIdentity():match('^oasc%-rs%-bag%-qa%-'))
  assert(game.data.constants.gen3RsSummary.version==edition)
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local out=assert(os.getenv('RS_UI_QA_OUT'))
  local report={edition=edition,status='running',captures={},fullStory=false}
  local function persist()
    local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()
  end
  persist()
  U.teleport(game,'MAP_G00_N16',10,12,'up')
  local world=game.stack:top()
  local main=Pokemon.new(game.data,'TREECKO',20)
  local egg=Pokemon.new(game.data,'TORCHIC',5);egg.isEgg=true;egg.happiness=10
  local last=Pokemon.new(game.data,'MUDKIP',17)
  main.ot=game.save.player.name;main.otId=game.save.player.id
  main.metLevel=5;main.metLocation=16;main.metGame=edition=='ruby' and 2 or 1
  main.nickname='TREECKO';main.markings=5;main.heldItem='ORAN_BERRY';main.ribbons={cool=2,champion=true}
  main.moves={{id='SURF',pp=3,ppUps=2},{id='TACKLE',pp=11,ppUps=1},
    {id='CUT',pp=5,ppUps=3},{id='QUICK_ATTACK',pp=7,ppUps=0}}
  game.save.party={main,egg,last}
  local screen
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 1)
  end
  local function immutable()
    local before=Serialize.encode(game.save);local rng=love.math.getRandomState()
    love.graphics.push('all');local ok,why=pcall(screen.draw,screen);love.graphics.pop();assert(ok,why)
    assert(Serialize.encode(game.save)==before,'Native summary drawing changed saved data')
    assert(love.math.getRandomState()==rng,'Native summary drawing consumed gameplay RNG')
  end
  local function shot(name)
    immutable();assert(U.shot(game,out..'/'..name..'.png'))
    report.captures[#report.captures+1]=name;persist()
  end
  local function open(opts)
    screen=Summary.new(game,opts or {mon=main,party=game.save.party,partyIndex=1})
    assert(screen.rsNative,'Native RS summary was not selected')
    game.stack:push(screen);U.wait(25)
    assert(screen.rsNative.scene._fade==nil,'Native entrance fade stalled')
  end
  local function close()
    press('b',90);assert(game.stack:top()==world,'Native summary did not return to world')
  end
  open()
  assert(screen.page==1 and screen.mon==main)
  assert(screen.rsNative.scene.locationName(16)=='ROUTE 101','Native RS met-location name is missing')
  shot('info')
  press('left',30);assert(screen.page==1,'First page wrapped')
  press('right',30);assert(screen.page==2)
  press('a',30);assert(game.stack:top()==screen and screen.page==2,'A unexpectedly closed SKILLS')
  local v=screen.rsNative.view(main)
  assert(v.maxHp==main.stats.hp and v.stats.spAtk==main.stats.spatk and v.stats.spDef==main.stats.spdef)
  shot('skills')
  press('right',30);assert(screen.page==3);shot('battle-moves')
  press('a',15);assert(screen.moveSelect);shot('battle-detail')
  press('a');press('down');shot('move-swap')
  press('a')
  assert(main.moves[1].id=='TACKLE' and main.moves[1].pp==11 and main.moves[1].ppUps==1)
  assert(main.moves[2].id=='SURF' and main.moves[2].pp==3 and main.moves[2].ppUps==2)
  assert(screen.rsNative.scene.policy.maxPP(screen.rsNative.view(main),1,game.data.moves.TACKLE.index)==42)
  shot('after-move-swap')
  press('b',15);assert(not screen.moveSelect)
  press('right',30);assert(screen.page==4);shot('contest-moves')
  press('a',15);assert(screen.moveSelect);shot('contest-detail')
  press('b',15);press('right',30);assert(screen.page==4,'Last page wrapped')
  close()

  open()
  local scene=screen.rsNative.scene
  local nativeData=screen.rsNative.load('src.core.game3.summary_data')
  local cases={{'PSN',1},{'PAR',2},{'SLP',3},{'FRZ',4},{'BRN',5}}
  for _,row in ipairs(cases)do
    main.status=row[1];U.wait(2)
    assert(nativeData.statusAilment(screen.rsNative.view(main))==row[2]);shot('status-'..row[1])
  end
  main.status=nil;main.pokerus=1;U.wait(2)
  assert(nativeData.statusAilment(screen.rsNative.view(main))==6);shot('status-pokerus')
  main.pokerus=0;main.hp=0;U.wait(2)
  assert(nativeData.statusAilment(screen.rsNative.view(main))==7);shot('status-fainted')
  main.hp=main.stats.hp;main.isShiny=true;main.shiny=true;U.wait(2);shot('shiny')
  main.isShiny=false;main.shiny=false
  main.gen3OtName='GUEST';main.ot=nil;main.secretId=12345
  main.gen3Markings=15;main.markings=nil;main.gen3Pokerus=1;main.pokerus=nil
  main.gen3Language=2;main.ball='ULTRA_BALL';main.statusWord=64
  U.wait(2)
  local imported=screen.rsNative.view(main)
  assert(imported.otName=='GUEST' and imported.otSecretId==12345 and imported.markings==15
    and imported.pokerus==1 and imported.pokeball=='ULTRA_BALL')
  assert(nativeData.statusAilment(imported)==2)
  shot('imported-metadata')
  press('down',40);assert(screen.mon==egg and screen.partyIndex==2)
  shot('egg')
  press('right',30);assert(screen.page==1,'Egg left INFO')
  press('up',40);assert(screen.mon==main)
  press('right',30);press('down',40)
  assert(screen.mon==last and screen.partyIndex==3,'Native SKILLS did not skip egg')
  shot('second-mon-skills')
  close()

  local answer='pending'
  main.moves={{id='SURF',pp=3,ppUps=2},{id='TACKLE',pp=11,ppUps=1},
    {id='CUT',pp=5,ppUps=3},{id='QUICK_ATTACK',pp=7,ppUps=0}}
  local before=Serialize.encode(main.moves)
  open({mon=main,choose={move='ABSORB',onChoose=function(i)answer=i end}})
  assert(screen.page==3);shot('learn-move')
  press('a',10);assert(screen.rsNative.scene._state=='notice' and answer=='pending')
  shot('hm-refused')
  press('b',10);press('down');press('a',90)
  assert(game.stack:top()==world and answer==2,'Native chooser returned wrong host slot')
  assert(Serialize.encode(main.moves)==before,'Native chooser modified moves before host callback')
  answer='pending'
  open({mon=main,choose={move='ABSORB',onChoose=function(i)answer=i end}})
  close();assert(answer==nil,'Native chooser cancel did not return nil')
  local box={[1]=main,[3]=last}
  open({mon=main,party=box,partyIndex=1,context='box'})
  press('down',40);assert(screen.mon==last and screen.partyIndex==3,'PC summary did not skip empty slot')
  shot('pc-summary');close()
  report.nativePages=true;report.nativeTransitions=true;report.nativeMoveSwap=true
  report.movePpUpsPreserved=true;report.nativeStatuses=true;report.eggAndParty=true
  report.hmRefusal=true;report.hostChooseCallback=true;report.pcEmptySlotSkip=true
  report.drawSaveAndRngImmutable=true;report.status='pass';persist()
  print('PASS_RS_SUMMARY_NATIVE '..edition);love.event.quit(0)
end
