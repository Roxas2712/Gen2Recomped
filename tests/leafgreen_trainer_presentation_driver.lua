-- Prepared battle presentation fixtures. Continuous story has its own driver.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local B=require('src.battle.BattleState');local Music=require('src.core.Music')
  local S=require('src.core.SaveSerializer');local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(require('src.core.GameVersion').get()=='leafgreen')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-leafgreen%-'))
  local report={edition='leafgreen',status='running',preparedBattles=true,fullStoryTested=false,captures={},trainers={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(k,n)game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(n or 1)end
  local function shot(name)
    local top=assert(game.stack:top());local old=S.encode(game.save);local rng=love.math.getRandomState()
    local ok,why=require('src.render.GraphicsScope').call(top.draw,top);assert(ok,why)
    assert(S.encode(game.save)==old and love.math.getRandomState()==rng,'Battle draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  persist();assert(require('src.import.RomImporter').readyReport('leafgreen').ok)
  local classes=game.data.constants.trainerClasses;local count=0
  for k,v in pairs(classes)do assert(type(k)=='number'and type(v)=='string');count=count+1 end
  assert(count==107 and classes[84]=='LEADER'and classes[87]=='ELITE FOUR'and classes[90]=='CHAMPION')
  assert(game.data.constants.gen3TrainerPresentation.classCount==107)
  press('b',10);press('b',10)
  local Title=require('src.ui.Gen3TitleFRLG')
  for _=1,1400 do if getmetatable(game.stack:top())==Title and game.stack:top().phase=='run'then break end;U.wait(1)end
  press('start',150);assert(game.stack:top().items[1].key=='newGame');press('a',100)
  for _=1,2500 do if game.overworld and game.stack:top()==game.overworld then break end;press('a',2)end
  assert(game.overworld and game.stack:top()==game.overworld)
  -- Explicit fixture in this isolated QA profile, never a story acceptance.
  game.save.player.rival='ALICE'
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'SQUIRTLE',10)}
  local cases={{class=81,kind='trainer',song='SONG_129',rival=true},
    {class=89,kind='trainer',song='SONG_129',rival=true},
    {class=84,name='BROCK',kind='gym',song='SONG_128'},
    {class=87,kind='elite',song='SONG_128'},
    {class=90,kind='final',song='SONG_12B',rival=true}}
  for _,case in ipairs(cases)do
    local key,raw
    for id,t in pairs(game.data.trainers)do
      if t.class==case.class and(not case.name or t.name==case.name)and(not raw or t.index<raw.index)then key,raw=id,t end
    end
    assert(key,'Missing imported trainer class '..case.class)
    local original=S.encode(raw);local party=raw.parties
    local battle=B.newTrainer(game,key,1)
    assert(battle.trainer.id==raw.id and battle.trainer.parties==party)
    assert(battle.trainer.name==(case.rival and 'ALICE'or raw.name))
    assert(battle:trainerLabel_()==classes[case.class]..' '..battle.trainer.name)
    assert(battle:computeMusicKind()==case.kind)
    game.stack:push(battle);U.wait(480)
    assert(Music.current()==case.song,'Native trainer role played wrong song')
    local name='trainer-class-'..case.class
    shot(name)
    report.trainers[#report.trainers+1]={key=key,index=raw.index,class=case.class,label=battle:trainerLabel_(),
      musicKind=battle.musicKind,song=Music.current(),stableImportedDefinition=S.encode(raw)==original}
    assert(S.encode(raw)==original,'Trainer presentation mutated imported catalog')
    game.stack:pop();assert(game.stack:top()==game.overworld);U.wait(5)
  end
  report.classCount=count;report.drawSaveAndRngImmutable=true;report.status='pass';persist()
  print('PASS_LEAFGREEN_TRAINER_PRESENTATION');love.event.quit(0)
end
