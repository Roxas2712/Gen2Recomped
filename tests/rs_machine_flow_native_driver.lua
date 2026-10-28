-- Prepared native UI fixtures, separate from the ordinary story lineage.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Serialize=require('src.core.SaveSerializer');local Pokemon=require('src.pokemon.Pokemon')
  local Bag=require('src.ui.Gen3BagMenu');local Party=require('src.ui.Gen3PartyMenu')
  local Choice=require('src.ui.ChoiceBox');local Summary=require('src.ui.Gen3SummaryMenu')
  local NativeChoice=require('src.ui.Gen3RsChoice')
  local TextBox=require('src.render.TextBox');local Sound=require('src.core.Sound')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(edition=='ruby'or edition=='sapphire')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local report={edition=edition,status='running',preparedMachineFixture=true,continuousStory=false,
    captures={},cases={},audio={},fanfareBlocksInput=false,drawSaveAndRngPreserved=true}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  persist();U.freshSave(game);U.teleport(game,'MAP_G11_N05',7,7,'up');U.wait(60)
  local world=game.stack:top();assert(world==game.overworld)
  local originalPlay=Sound.play
  local originalPlayId=Sound.playId;report.bootAudio={}
  Sound.playId=function(data,id,...)
    local source=originalPlayId(data,id,...)
    if data==game.data and id==data.constants.gen3RsPresentation.songIds.SE_PC_LOGIN then
      local box=game.stack:top()
      assert(getmetatable(box)==TextBox and box.rsMachineBag and box.done)
      assert(source and source:isPlaying(),'Machine boot cue did not play')
      report.bootAudio[#report.bootAudio+1]={afterBootText=true,sourcePlayed=true,index=id}
    end
    return source
  end
  Sound.play=function(data,name,...)
    local source=originalPlay(data,name,...)
    if data==game.data and name=='Level_Up'then
      local box=game.stack:top()
      assert(getmetatable(box)==TextBox and box.done and box.pageIndex==#box.pages,'Fanfare before learned text completed')
      assert(source and source:isPlaying()and data.audio.sfx.Level_Up.m4a==367)
      report.audio[#report.audio+1]={index=367,afterLastPage=true,sourcePlayed=true,frame=U.frame()}
    end
    return source
  end
  local function press(key,delay)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(delay or 18)
  end
  local function shot(name)
    local old=Serialize.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
    local ok,why=require('src.render.GraphicsScope').call(top.draw,top);assert(ok,why)
    assert(old==Serialize.encode(game.save)and rng==love.math.getRandomState(),'Drawing changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name
  end
  local bag;local bagClosed=0
  local function mon(species,moves)
    local m=Pokemon.new(game.data,species,16);m.moves={}
    for i,id in ipairs(moves)do m.moves[i]={id=id,pp=assert(game.data.moves[id]).pp}end
    return m
  end
  local function setup(mons,inventory)
    assert(game.stack:top()==world)
    game.save.party=mons;game.save.inventory=inventory;bagClosed=0
    bag=Bag.new(game,{onCancel=function()bagClosed=bagClosed+1 end})
    game.stack:push(bag);U.wait(120);press('right',60);press('right',60)
    assert(bag.rs and bag.pockets[bag.pocket].key=='TM_HM',J.encode({rs=bag.rs,pocket=bag.pocket,
      pocketKey=bag.pockets[bag.pocket].key,version=require('src.core.GameVersion').get(),
      nativeVersion=game.data.constants.gen3RsBag and game.data.constants.gen3RsBag.version}))
  end
  local function untilType(class)
    for _=1,600 do
      local top=game.stack:top();if getmetatable(top)==class or(class==Choice and getmetatable(top)==NativeChoice)then
        if class==Party then U.wait(120)elseif class==Summary then U.wait(60)end
        return top
      end
      assert(top~=bag,'Flow returned to bag before expected screen')
      if getmetatable(top)==TextBox or getmetatable(top)==Choice or getmetatable(top)==NativeChoice then press('a')else U.wait(6)end
    end
    error('Expected UI did not open')
  end
  local bootCaptured,questionCaptured={},{}
  local function open(id)
    local wanted
    for i,row in ipairs(bag.rows)do if row.id==id then wanted=i end end
    assert(wanted)
    while bag.index~=wanted do press(bag.index<wanted and'down'or'up')end
    press('a');local popup=game.stack:top()
    assert(getmetatable(popup)==require('src.ui.Gen3ItemMenu'))
    assert(popup.entries[popup.index].kind=='use');press('a')
    local boot=game.stack:top();assert(getmetatable(boot)==TextBox and boot.rsMachineBag==bag)
    local kind=game.data.items[id].machine.kind
    U.wait(90);assert(boot.done and boot.rsBootCue and game.stack:top()==boot)
    assert(boot.pages[1][1]==(kind=='HM'and'Booted up an HM.'or'Booted up a TM.'))
    if not bootCaptured[kind]then shot(kind:lower()..'-original-boot-message');bootCaptured[kind]=true end
    press('b');local question=untilType(Choice)
    assert(getmetatable(question)==NativeChoice and NativeChoice.yesNoStyle(game)=='bag_machine')
    assert(question.scene.left==7 and question.scene.top==7 and question.index==1)
    local contained=game.stack.states[#game.stack.states-1]
    assert(contained.rsMachineBag==bag and contained.pages[1][1]=='It contained')
    local expected=game.data.moves[game.data.items[id].machine.move].name
    assert(contained.pages[1][2]==expected..'.'and contained.pages[2][1]=='Teach '..expected)
    if not questionCaptured[kind]then shot(kind:lower()..'-original-teach-question');questionCaptured[kind]=true end
    return question
  end
  local function use(id,slot)
    open(id);press('a')
    local picker=untilType(Party);assert(picker.keepOpen,'Native party backdrop was discarded')
    while picker.index~=slot do press('down')end
    press('a');assert(game.stack.states[2]==bag and game.stack.states[3]==picker)
    return picker
  end
  local function finishToBag()
    for _=1,2000 do
      local top=game.stack:top();if top==bag then
        assert(#game.stack.states==2 and bagClosed==0,'Bag replaced, duplicated or closed')
        assert(bag.pockets[bag.pocket].key=='TM_HM');return
      end
      if getmetatable(top)==Summary then
        assert(top.rsNative and top.rsNative.scene._fade=='out','Summary selection did not start its native exit')
        U.wait(6)
      else
      assert(getmetatable(top)==TextBox,'Unexpected screen while returning to bag')
      if top.autoSrc and top.autoSrc:isPlaying()then
        local source=top.autoSrc;press('a',3)
        if source:isPlaying()then assert(game.stack:top()==top,'Fanfare was skipped');report.fanfareBlocksInput=true end
      else press('a')end
      end
    end
    error('Machine flow did not return to bag')
  end
  local function closeBag()
    press('b');assert(game.stack:top()==world and bagClosed==1)
  end
  -- Free slot: learned text stays over the original party, then returns to bag.
  local zig=mon('ZIGZAGOON',{'TACKLE','GROWL'})
  zig.nickname='ZIGZAGZIGZ'
  setup({zig},{HM01=1,TM39=1});local picker=use('HM01',1)
  local message=game.stack:top();assert(message.rsMachineParty==picker)
  assert(message.boxTx==4 and message.boxTy==15 and message.boxTw==22 and message.boxTh==4)
  assert(message.textX==32 and message.line1Y==120 and message.line2Y==136 and message.maxPixels==176)
  local widths=picker.rsNative.machineWidths()
  for _,lines in ipairs(message.pages)do for _,line in ipairs(lines)do
    local used=0;for _,code in ipairs(require('src.render.Font').encode(line))do used=used+(widths[code]or 0)end
    assert(used<=176,'Native message escaped its content window')
  end end
  local chrome,policy=picker.rsNative.chrome,picker.rsNative.policy
  local cancel,prompt=chrome.drawCancelButton,policy.drawPrompt
  chrome.drawCancelButton=function()error('CANCEL drawn under native message')end
  policy.drawPrompt=function()error('Party prompt drawn under native message')end
  U.wait(120);shot('hm-free-slot-party-message')
  chrome.drawCancelButton,policy.drawPrompt=cancel,prompt
  report.noPartyPromptOrCancelUnderMessage=true
  report.nativeMessageWindow={x=24,y=112,width=192,height=48,font=4,wrapPixels=176}
  finishToBag();assert(zig.moves[3].id=='CUT'and zig.moves[3].pp==30 and game.save.inventory.HM01==1)
  assert(zig.nickname=='ZIGZAGZIGZ')
  shot('hm-free-slot-return-bag');report.cases.hmFreeSlot=true
  -- Reuse / already learned: no item loss or move mutation.
  local partyBefore=Serialize.encode(game.save.party);local audioBefore=#report.audio
  use('HM01',1);finishToBag();assert(Serialize.encode(game.save.party)==partyBefore and game.save.inventory.HM01==1)
  assert(#report.audio==audioBefore);report.cases.hmAlreadyKnown=true;closeBag()
  -- Full set: use the actual RS summary chooser and replace LEER.
  local grovyle=mon('GROVYLE',{'POUND','LEER','ABSORB','QUICK_ATTACK'})
  setup({grovyle},{HM01=1,TM39=1});use('HM01',1);untilType(Summary)
  press('down');shot('hm-full-set-native-summary');press('a');finishToBag()
  assert(grovyle.moves[2].id=='CUT'and game.save.inventory.HM01==1)
  shot('hm-full-set-return-bag');report.cases.hmFullSet=true;closeBag()
  -- A cancelled full-set TM keeps the original mon and quantity.
  local geo=mon('GEODUDE',{'TACKLE','DEFENSE_CURL','ROCK_THROW','MUD_SPORT'})
  setup({geo},{TM39=1,HM01=1});partyBefore=Serialize.encode(game.save.party);audioBefore=#report.audio
  use('TM39',1);untilType(Choice);press('b',120)
  local stop=untilType(Choice);assert(stop.index==1);press('a');finishToBag()
  assert(game.save.inventory.TM39==1 and Serialize.encode(game.save.party)==partyBefore and #report.audio==audioBefore)
  shot('tm-cancel-return-bag');report.cases.tmCancelled=true;closeBag()
  -- Cancel the party picker itself, retaining bag cursor/pocket and both items.
  setup({geo},{TM39=1,HM01=1});open('TM39');local wanted=bag.index
  press('a');local picker=untilType(Party);press('b')
  assert(game.stack:top()==bag and bag.index==wanted and bagClosed==0 and game.save.inventory.TM39==1)
  report.cases.partyCancelled=true;closeBag()
  -- Incompatible target and a single-use TM's successful last-copy removal.
  setup({mon('MAGIKARP',{'SPLASH'})},{TM39=1,HM01=1});use('TM39',1);finishToBag()
  assert(game.save.inventory.TM39==1);report.cases.incompatible=true;closeBag()
  geo=mon('GEODUDE',{'TACKLE','DEFENSE_CURL'})
  setup({geo},{TM39=1,HM01=1});use('TM39',1);finishToBag()
  assert(geo.moves[3].id=='ROCK_TOMB'and not game.save.inventory.TM39 and game.save.inventory.HM01==1)
  for _,row in ipairs(bag.rows)do assert(row.id~='TM39','Consumed TM row survived')end
  shot('tm-last-copy-return-bag');report.cases.tmConsumedOnce=true;closeBag()
  -- An HM slot cannot be forgotten: the summary is reopened before a valid replacement.
  geo=mon('GEODUDE',{'ROCK_SMASH','TACKLE','DEFENSE_CURL','ROCK_THROW'})
  setup({geo},{TM39=1,HM01=1});use('TM39',1);untilType(Summary);press('a')
  local summary=game.stack:top()
  assert(getmetatable(summary)==Summary and summary.rsNative.scene._state=='notice')
  assert(geo.moves[1].id=='ROCK_SMASH'and game.save.inventory.TM39==1)
  shot('tm-cannot-forget-hm');press('down');press('a');finishToBag()
  assert(geo.moves[1].id=='ROCK_SMASH'and geo.moves[2].id=='ROCK_TOMB'and not game.save.inventory.TM39)
  report.cases.hmProtected=true;closeBag()
  -- NO and B at the original question are read-only and retain cursor/pocket.
  setup({geo},{TM39=1,HM06=1});partyBefore=Serialize.encode(game.save.party)
  local inventoryBefore=Serialize.encode(game.save.inventory)
  open('TM39');local wanted=bag.index;press('down');press('a')
  assert(game.stack:top()==bag and bag.index==wanted and bagClosed==0)
  assert(Serialize.encode(game.save.party)==partyBefore and Serialize.encode(game.save.inventory)==inventoryBefore)
  shot('tm-original-teach-no-returns-same-bag');report.cases.teachQuestionNo=true
  open('HM06');wanted=bag.index;press('b')
  assert(game.stack:top()==bag and bag.index==wanted and bagClosed==0)
  assert(Serialize.encode(game.save.party)==partyBefore and Serialize.encode(game.save.inventory)==inventoryBefore)
  report.cases.teachQuestionB=true;closeBag()
  assert(bootCaptured.TM and bootCaptured.HM and questionCaptured.TM and questionCaptured.HM)
  assert(game.data.moves.ROCK_SMASH.power==20 and game.data.moves.PURSUIT.power==40)
  report.cases.originalBootAndQuestion=true;report.cases.cartridgeMoveStats=true
  assert(report.fanfareBlocksInput and #report.audio==4)
  Sound.play,Sound.playId=originalPlay,originalPlayId;report.status='pass';persist();print('PASS_RS_NATIVE_MACHINE_FLOW');love.event.quit()
end
