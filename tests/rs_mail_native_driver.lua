-- Prepared mail fixtures; real native input, final renderer and host SAVE.
return function(game)
  local U=require('tests.drivers.util');local S=require('src.core.SaveSerializer');local J=require('src.link.Json')
  local View=require('src.ui.Gen3RsMailView');local Model=require('src.inventory.Gen3RsMail')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(View.available(game)and require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game);U.teleport(game,'MAP_G00_N11',11,9,'right');U.wait(90)
  local world=game.stack:top();local report={edition=edition,status='running',preparedMailFixture=true,
    continuousStory=false,cases={},captures={},callbacks=0,drawSaveAndRngPreserved=true}
  local scratch=love.graphics.newCanvas(240,160,{dpiscale=1})
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,n,delay)
    for _=1,n or 1 do game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(delay or 5)end
  end
  local function shot(name)
    local before=S.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()
      love.graphics.setCanvas(scratch);love.graphics.origin();love.graphics.setScissor();love.graphics.setShader()
      love.graphics.clear(0,0,0,0);game.stack:top():draw()
    end))
    assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Mail draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'TREECKO',12),
    require('src.pokemon.Pokemon').new(game.data,'UNOWN',8)}
  game.save.party[2].personality=0x03020100
  game.save.inventory={ORANGE_MAIL=100,HARBOR_MAIL=2};game.save.bagOrder={'ORANGE_MAIL','HARBOR_MAIL'}
  local function goods()return S.encode({inventory=game.save.inventory,bagOrder=game.save.bagOrder,
    slots=game.save.gen3RsBagSlots,mail=game.save.gen3RsMail,party=game.save.party})end
  -- The older host allowed held stationery without a written record. Its
  -- original item remains recoverable via an explicit party MAIL -> TAKE.
  game.save.party[2].item='HARBOR_MAIL'
  local legacy=require('src.ui.Gen3PartyMenu').new(game,{});game.stack:push(legacy);U.wait(90)
  press('down');press('a');press('down',2);press('a');press('down');press('a');U.wait(90)
  assert(not game.save.party[2].item and game.save.inventory.HARBOR_MAIL==3 and not game.save.gen3RsMail)
  shot('mail-original-recovered-legacy-stationery')
  for _=1,100 do if game.stack:top()==legacy then break end;press('a')end
  assert(game.stack:top()==legacy);press('b');assert(game.stack:top()==world)
  report.cases.oldUncomposedHeldStationeryRecoveredWithoutInventingWords=true
  local mail=Model.new(game);assert(mail.valid)
  for _,gender in ipairs({'boy','girl'})do
    game.save.player.gender=gender;game.save.options.gen3Frame=gender=='boy'and 1 or 20
    for design=0,11 do
      local record=mail.native.clear();record.itemId=121+design
      record.playerName='QA';record.words={512,513,514,65535,65535,65535,65535,65535,65535}
      record.species=design==6 and 30007 or 277
      local before=goods();local reader=View.new(game,{kind='reader',record=record,onDone=function()report.callbacks=report.callbacks+1 end})
      game.stack:push(reader);U.wait(90);assert(reader.scene._state=='input')
      assert(reader.scene._content.design==design)
      shot(('mail-%s-original-design-%02d'):format(gender,design));press(design%2==0 and'a'or'b');U.wait(40)
      assert(game.stack:top()==world and before==goods(),'Reading changed goods or callback return')
    end
  end
  report.cases.twelveOriginalStationeryDesignsBothGenderPalettes=true
  report.cases.nativeWordsSignatureAndHarborDreamIcons=true
  report.cases.readerFadeABReturnAndReadOnlySave=true
  local record=mail.native.clear();local before=goods()
  local composer=View.new(game,{kind='composer',record=record,onDone=function(accepted)
    assert(not accepted);report.callbacks=report.callbacks+1
  end});game.stack:push(composer);U.wait(90)
  assert(composer.scene._state=='input'and composer.scene._view=='phrase')
  local initial={};for _,g in ipairs(composer.scene.groups)do initial[g.id]=true end
  assert(not initial[17]and not initial[18]and not initial[19]and not initial[20]and not initial[21])
  shot('mail-original-empty-composer');press('a');U.wait(60);press('select');U.wait(60)
  assert(composer.scene._group.alpha);shot('mail-original-alphabet-picker');press('b');U.wait(60)
  press('a');U.wait(60);press('select');U.wait(60);assert(not composer.scene._group.alpha)
  press('down',9,16);assert(composer.scene._group.top>0);shot('mail-original-group-scroll')
  press('b');U.wait(60);press('start');press('a')
  assert(composer.scene._confirm.kind=='empty');shot('mail-original-empty-phrase-refusal');press('b')
  press('b');assert(composer.scene._confirm.kind=='cancel'and composer.scene._confirm.cursor==1)
  shot('mail-original-cancel-default-no');press('up');press('a');U.wait(40)
  assert(game.stack:top()==world and before==goods())
  report.cases.emptyComposerRefusesAndCancelDefaultsNo=true
  report.cases.alphabetToggleGroupScrollAndBackToPhrase=true
  local Bag=require('src.ui.Gen3BagMenu');local bag=Bag.new(game,{pocket='ITEM'});game.stack:push(bag);U.wait(40)
  before=goods();press('a');press('a');local blank=game.stack:top()
  assert(getmetatable(blank)==View and blank.opts.hasText==false);U.wait(90)
  assert(not blank.scene._content.signature and not blank.scene._content.icon and #blank.scene._content.rows==0)
  shot('mail-original-bag-check-blank-stationery');press('b');U.wait(40)
  assert(game.stack:top()==bag and before==goods())
  local blankRecord=mail.native.clear();blankRecord.itemId=130;blankRecord.species=0
  blank=View.new(game,{kind='reader',record=blankRecord,hasText=false});game.stack:push(blank);U.wait(90)
  assert(blank.scene._content.design==9 and not blank.scene._content.signature and not blank.scene._content.icon)
  shot('mail-original-blank-dream-paper-without-fabricated-author');press('b');U.wait(40);assert(game.stack:top()==bag)
  report.cases.bagCheckShowsUnusedDesignWithoutWordsOrFabricatedAuthor=true
  press('down');assert(bag:selected().id=='ORANGE_MAIL'and bag:selected().qty==1)
  press('a');press('right');press('a');local party=game.stack:top();assert(party.pickOnly and party.keepOpen)
  U.wait(90);press('a');composer=game.stack:top();assert(getmetatable(composer)==View and composer.opts.kind=='composer')
  U.wait(90);assert(game.save.inventory.ORANGE_MAIL==100 and not game.save.party[1].item)
  press('a');U.wait(60);assert(composer.scene._view=='groups');shot('mail-original-word-groups')
  press('a');U.wait(60);assert(composer.scene._view=='words');shot('mail-original-word-picker')
  press('a');U.wait(60);assert(composer.scene._view=='phrase'and composer.scene.words[1]~=65535)
  shot('mail-original-selected-word');press('start');press('a')
  assert(composer.scene._confirm.kind=='save');shot('mail-original-save-confirmation');press('a');U.wait(50)
  assert(game.save.inventory.ORANGE_MAIL==99 and game.save.party[1].item=='ORANGE_MAIL')
  for _=1,120 do if game.stack:top()==bag then break end;press('a')end
  assert(game.stack:top()==bag and #Model.new(game):mailbox()==0)
  assert(bag.rows[1].qty==99 and bag.rows[2].id=='HARBOR_MAIL')
  shot('mail-bag-after-selected-stack-compose');press('b');assert(game.stack:top()==world)
  report.cases.bagGiveUsesRealPartyPickerAndNativeComposer=true
  report.cases.authoringDraftDoesNotChangeGoods=true
  report.cases.wordGroupPickerAndNineWordSavePrompt=true
  report.cases.acceptDebitsOnlySelectedPhysicalStack=true
  local Party=require('src.ui.Gen3PartyMenu')
  local function openParty()
    local p=Party.new(game,{});game.stack:push(p);U.wait(90);return p
  end
  local function action(p,id)
    if not p.submenu then press('a')end
    for _=1,12 do if p.submenu[p.subIndex].action==id then press('a');return end;press('down')end
    error('Missing party action '..id)
  end
  local function untilTop(predicate)
    for _=1,150 do if predicate(game.stack:top())then return game.stack:top()end;press('a')end
    error('Mail callback failed to return to expected screen')
  end
  party=openParty();action(party,'mail')
  assert(party.rsNative.mailSubmenu and #party.submenu==3);shot('mail-original-party-read-take-cancel')
  press('up');assert(party.subIndex==3);press('down');assert(party.subIndex==1)
  press('a');local reader=game.stack:top();assert(getmetatable(reader)==View);U.wait(90)
  shot('mail-original-authored-party-reader');press('b');U.wait(40);assert(game.stack:top()==party)
  assert(party.submenu and party.subIndex==1,'Held reader must return to the original party action menu')
  action(party,'mail');action(party,'takeMail')
  local yn=untilTop(function(t)return t.screenId=='Gen3RsChoice'end)
  assert(yn.yesNo and yn.index==1);shot('mail-original-send-to-pc-prompt');press('a')
  assert(not game.save.party[1].item and #Model.new(game):mailbox()==1)
  untilTop(function(t)return t==party end);press('b');assert(game.stack:top()==world)
  report.cases.partyMailMenuWrapAndReaderReturn=true
  report.cases.partyTakeSendsMessageAndStationeryToPc=true
  local function openMailbox()
    local pc=require('src.ui.Gen3PlayerPC').new(game,{order='player'});game.stack:push(pc);U.wait(20)
    press('down');press('a');local box=game.stack:top()
    assert(box.screenId=='Gen3RsMailbox'and box.ui.state=='list');return box,pc
  end
  local box,pc=openMailbox();before=goods();shot('mail-original-nonempty-mailbox')
  press('a');assert(box.ui.state=='options');shot('mail-original-mailbox-options');press('a')
  reader=game.stack:top();assert(getmetatable(reader)==View);U.wait(90);shot('mail-original-mailbox-reader')
  press('a');U.wait(40);assert(game.stack:top()==box and box.ui.state=='list'and before==goods())
  press('a');press('down');press('a');assert(box.ui.state=='confirm_msg')
  shot('mail-original-message-will-be-lost');press('b');assert(box.ui.state=='confirm')
  press('down');press('a');assert(box.ui.state=='list'and before==goods())
  press('a');press('down');press('a');press('a');assert(box.ui.state=='confirm')
  shot('mail-original-move-to-bag-confirm');press('a')
  assert(box.ui.state=='message'and #Model.new(game):mailbox()==0 and game.save.inventory.ORANGE_MAIL==100)
  shot('mail-original-returned-stationery-message');press('b');U.wait(10)
  assert(game.stack:top()==pc);press('b');assert(game.stack:top()==world)
  report.cases.nonemptyPcMailboxAndReaderReturn=true
  report.cases.moveToBagNoPreservesMessageAndYesErasesOnlyAfterAdding=true
  -- Explicit prepared fixtures for the original ten-letter list and overflow
  -- branches; the authored ordinary-input letter above is the source message.
  mail=Model.new(game);local fixture=assert(mail:prepareGive(1,'HARBOR_MAIL'))
  assert(mail:accept(fixture,{512,513,65535,65535,65535,65535,65535,65535,65535})and mail:store(1))
  local source=S.decode(S.encode(game.save.gen3RsMail.records[7]))
  for slot=7,16 do
    local r=assert(S.decode(S.encode(source)));r.playerName='QA'..(slot-6)
    game.save.gen3RsMail.records[slot]=r
  end
  before=goods();box,pc=openMailbox();assert(before==goods(),'Opening compact mailbox wrote save')
  press('down',9);assert(box.ui.scroll>0);shot('mail-original-ten-letter-scroll')
  press('up',20);press('a');press('down',2);press('a');local receiver=game.stack:top()
  assert(getmetatable(receiver)==Party and receiver.pickOnly);U.wait(90);press('down');press('a');U.wait(15)
  assert(game.stack:top()==box and #Model.new(game):mailbox()==9 and game.save.party[2].item=='HARBOR_MAIL')
  local received=assert(Model.new(game):readParty(2));assert(received.playerName=='QA1'and received.words[2]==513)
  shot('mail-original-mailbox-after-give');press('b');U.wait(10);assert(game.stack:top()==pc)
  press('b');assert(game.stack:top()==world)
  report.cases.tenLetterScrollAndGivePreservesOriginalSenderAndWords=true
  local keepInventory=assert(S.decode(S.encode({inventory=game.save.inventory,order=game.save.bagOrder,slots=game.save.gen3RsBagSlots})))
  game.save.inventory={POTION=99*20};game.save.bagOrder={'POTION'};game.save.gen3RsBagSlots=nil
  box,pc=openMailbox();before=goods();press('a');press('down');press('a');press('a');press('a')
  assert(box.ui.state=='message'and before==goods());shot('mail-original-full-bag-refusal')
  press('b');press('b');U.wait(10);assert(game.stack:top()==pc);press('b')
  game.save.inventory=keepInventory.inventory;game.save.bagOrder=keepInventory.order;game.save.gen3RsBagSlots=keepInventory.slots
  report.cases.fullBagMailboxRefusalPreservesAllWordsAndGoods=true
  -- Real party TAKE -> NO -> discard NO retains the held message, then YES
  -- returns precisely its stationery. This is separate from PC MOVE TO BAG.
  party=openParty();press('down');action(party,'mail');action(party,'takeMail');before=goods()
  untilTop(function(t)return t.screenId=='Gen3RsChoice'end);press('down');press('a')
  untilTop(function(t)return t.screenId=='Gen3RsChoice'end);shot('mail-original-discard-held-confirm')
  press('down');press('a');assert(game.stack:top()==party and before==goods())
  action(party,'mail');action(party,'takeMail')
  untilTop(function(t)return t.screenId=='Gen3RsChoice'end);press('down');press('a')
  untilTop(function(t)return t.screenId=='Gen3RsChoice'end);press('a')
  assert(not game.save.party[2].item);untilTop(function(t)return t==party end)
  shot('mail-original-party-after-discard');press('b');assert(game.stack:top()==world)
  report.cases.partyDiscardNoAndConfirmedStationeryReturn=true
  local C=require('compat.gen1-rs.Constants').new(require('compat.gen1-rs.Loader').new(edition))
  local clear=('FLAG_G3_%04X'):format(C:flag('FLAG_SYS_GAME_CLEAR'))
  local hipster=('FLAG_G3_%04X'):format(C:flag('FLAG_SYS_HIPSTER_MEET'))
  local oldClear,oldHipster,oldNational=game.save.flags[clear],game.save.flags[hipster],game.save.nationalDex
  local oldSeen,oldPhrases=game.save.pokedex.seen.TREECKO,game.save.gen3TrendyPhrases
  game.save.flags[clear]=true;game.save.flags[hipster]=true;game.save.nationalDex=true
  game.save.pokedex.seen.TREECKO=true;game.save.gen3TrendyPhrases={[0]=true}
  composer=View.new(game,{kind='composer',record=mail.native.clear()});game.stack:push(composer);U.wait(90)
  local enabled={};for _,g in ipairs(composer.scene.groups)do enabled[g.id]=true end
  for _,id in ipairs({0,17,18,19,20,21})do assert(enabled[id],'Missing native word gate '..id)end
  shot('mail-original-seen-clear-trendy-national-gates');press('b');press('up');press('a');U.wait(40)
  assert(game.stack:top()==world)
  game.save.flags[clear]=oldClear;game.save.flags[hipster]=oldHipster;game.save.nationalDex=oldNational
  game.save.pokedex.seen.TREECKO=oldSeen;game.save.gen3TrendyPhrases=oldPhrases
  report.cases.originalSeenGameClearTrendyAndNationalWordGates=true
  mail=Model.new(game);assert(mail:giveFromMailbox(6,1))
  local heldBefore=assert(mail:readParty(1))
  local Start=require('src.ui.Gen3StartMenu');local owner=Start.new(game)
  for i,row in ipairs(owner.rows)do if row.key=='save'then owner.index=i end end
  game.stack:push(owner);press('a');local saveMenu=game.stack:top()
  assert(getmetatable(saveMenu)==require('src.ui.Gen3RsSaveMenu'));press('a')
  for _=1,180 do if game.stack:top()==world then break end;U.wait(1)end
  assert(game.stack:top()==world and saveMenu.wrote)
  local IO=require('src.core.SaveData');local disk=assert(S.decode(assert(love.filesystem.read(IO.saveFilename(edition)))))
  assert(S.encode(disk.gen3RsMail)==S.encode(game.save.gen3RsMail)and #Model.new({save=disk,data=game.data}):mailbox()==8)
  shot('mail-field-after-native-save')
  report.cases.normalNativeSavePersistsMailboxAndIndependentHeldState=true
  local bytes=assert(love.filesystem.read(IO.saveFilename(edition)));local oldSave=game.save
  game:returnToTitle();local ready=false
  for _=1,6000 do
    local top=game.stack:top();if top and top.kind=='title'and top.scene.phase=='phase3'then ready=true;break end
    U.wait(1)
  end
  assert(ready);press('start');U.wait(100)
  assert(getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu')and game.stack:top().items[1].key=='continue')
  press('a');U.wait(30);assert(game.stack:top().info);shot('mail-original-continue-summary')
  press('a');U.wait(120);world=game.overworld
  assert(game.stack:top()==world and game.save~=oldSave)
  mail=Model.new(game);assert(mail.valid and #mail:mailbox()==8)
  assert(S.encode(game.save.gen3RsMail)==S.encode(disk.gen3RsMail)and S.encode(mail:readParty(1))==S.encode(heldBefore))
  assert(love.filesystem.read(IO.saveFilename(edition))==bytes,'CONTINUE rewrote stored mail save')
  party=openParty();action(party,'mail');action(party,'readMail');U.wait(90)
  shot('mail-original-continued-held-letter');press('b');U.wait(40);assert(game.stack:top()==party);press('b',2)
  box,pc=openMailbox();shot('mail-original-continued-mailbox');press('b');U.wait(10);assert(game.stack:top()==pc);press('b')
  report.cases.nativeContinueReopensHeldAndMailboxMessagesWithoutDiskWrites=true
  report.status='pass';persist();love.event.quit(0)
end
