-- Prepared native storage fixture. Never evidence of ordinary story progress.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json');local Save=require('src.core.SaveSerializer')
  local Pokemon=require('src.pokemon.Pokemon');local Native=require('src.ui.Gen3RsStorage')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(edition=='ruby'or edition=='sapphire')
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local report={edition=edition,status='running',preparedStorageFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,referenceCommit='fb7b0366efcb85e703e9e6d5a8a24d01456a109b'}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  persist();U.freshSave(game);U.teleport(game,'MAP_G03_N01',10,2,'up');U.wait(120)
  local world=game.stack:top();local closed=0;local screen
  local function press(key,delay)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(delay or 60)end
  local function shot(name)
    local before=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(before==Save.encode(game.save)and rng==love.math.getRandomState(),'Storage draw mutated save or RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function core()return Save.encode({party=game.save.party,boxes=game.save.boxes,boxNames=game.save.boxNames,currentBox=game.save.currentBox})end
  local function fixture()
    assert(game.stack:top()==world)
    local a=Pokemon.new(game.data,'GROVYLE',18);local b=Pokemon.new(game.data,'ZIGZAGOON',2)
    a.nickname='ABCDEFGHIJ';a.privateUnknown={keep='stable'};b.nickname='ZIG'
    game.save.party={a,b};game.save.boxes={};game.save.boxNames={[14]='LONG BOX'};game.save.currentBox=14
    for i=1,14 do game.save.boxes[i]={}end
    local c=Pokemon.new(game.data,'WURMPLE',6);local d=Pokemon.new(game.data,'TAILLOW',9);d.gen3Markings=2
    game.save.boxes[14][30]=c;game.save.boxes[14][3]=d
    return a,b,c,d
  end
  local function open(mode)
    screen=require('src.ui.Gen3BoxMenu').new(game,{mode=mode or 'move',onCancel=function()closed=closed+1 end})
    assert(getmetatable(screen)==Native);game.stack:push(screen);U.wait(220)
    assert(not screen.scene.isPresentationBusy());return screen.scene
  end
  local function close()
    local was=closed
    if screen.scene.mode=='party_drawer'and screen.scene.subMode~='deposit'then press('b')end
    press('b',220);assert(game.stack:top()==world and closed==was+1,'PC close callback')
  end
  local function slot(index)
    local ui=screen.scene;assert(ui.mode=='browse')
    if ui.cursorSlot<0 then press('down')end
    while ui.cursorSlot>0 do press('up')end
    press('down');assert(ui.cursorSlot==1)
    for _=1,math.floor((index-1)/6)do press('down')end
    for _=1,(index-1)%6 do press('right')end
    assert(ui.cursorSlot==index)
  end
  local function action(label)
    local ui=screen.scene;press('a');assert(ui.mode=='action_menu')
    local found;for i,name in ipairs(ui._activeActions)do if name==label then found=i end end
    assert(found,'Missing native action '..label)
    for _=2,found do press('down')end
    assert(ui._activeActions[ui.actionCursor]==label);press('a',200)
  end
  local function party()
    slot(1);press('up');press('up');press('a');assert(screen.scene.mode=='party_drawer')
  end
  local a,b,c,d=fixture();local before=core()
  local done=0;local menu=require('src.ui.Gen3StorageMenu').new(game,{onCancel=function()done=done+1 end,onDone=function()done=done+1 end})
  assert(getmetatable(menu)==Native);game.stack:push(menu);U.wait(120);assert(#menu.rows==4)
  shot('storage-native-four-options');press('b');assert(done==2 and game.stack:top()==world and before==core())
  local ui=open();shot('storage-native-sparse-box14');slot(3);shot('storage-native-mon-data')
  action('MOVE');assert(ui.holdingMon and ui.holdingMon._host.species=='TAILLOW')
  assert(before==core(),'picked-up Pokemon leaked into authoritative save')
  press('b');assert(ui.mode=='message'and ui.holdingMon);shot('storage-native-holding-message')
  press('b');press('l',180);assert(screen.session.storage.currentBox==13)
  press('a',180);assert(not ui.holdingMon and screen.session.storage.boxes[13].mons[3])
  assert(before==core());shot('storage-native-moved-box13');close()
  assert(game.save.boxes[13][3]==d and not game.save.boxes[14][3]and game.save.boxes[14][30]==c)
  assert(game.save.party[1]==a and a.privateUnknown.keep=='stable')
  report.cases.nativeArtAndFourOptions=true;report.cases.sparseCrossBoxMoveAndHoldingSafety=true

  -- A party mon swapped with a box mon keeps both original host identities.
  a,b,c,d=fixture();before=core();ui=open();party();press('right');action('MOVE')
  assert(ui.holdingMon and #screen.session.party==1 and before==core())
  press('b');slot(3);press('a',180);assert(ui.holdingMon and ui.holdingMon._host.species=='TAILLOW')
  party();press('right');press('a',180);assert(not ui.holdingMon)
  shot('storage-native-party-box-swap');close()
  assert(game.save.party[1]==a and game.save.party[2]==d and game.save.boxes[14][3]==b)
  report.cases.nativePartyBoxSwap=true

  -- Summary traverses actual occupied slots, retaining the native sparse index.
  fixture();ui=open();slot(3);action('SUMMARY');assert(game.stack:top()~=screen)
  shot('storage-native-summary-from-box');press('down');press('b',220)
  assert(game.stack:top()==screen and ui.cursorSlot==30,'sparse summary return index')
  report.cases.sparseSummaryReturn=true
  -- Marking cancel and confirmation retain unknown fields and stable references.
  slot(3);action('MARK');assert(ui.mode=='markings');press('a');press('b')
  assert(screen.session.storage.boxes[14].mons[3].markings==2)
  action('MARK');press('a');shot('storage-native-marking-editor')
  for _=1,4 do press('down')end;press('a');assert(screen.session.storage.boxes[14].mons[3].markings==3)
  -- Box jump, wallpaper groups, naming with the original RS keyboard.
  press('up');press('a');assert(ui.mode=='box_menu');press('a');assert(ui.mode=='pick_box')
  shot('storage-native-box-popup');press('b');press('a');press('down');press('a')
  assert(ui.mode=='pick_wallpaper_group');shot('storage-native-wallpaper-groups')
  press('down');press('a');press('down');press('a',220)
  assert(screen.session.storage.boxes[14].wallpaper==6);shot('storage-native-volcano-wallpaper')
  press('a');press('down');press('down');press('a');assert(screen.naming and screen.naming.isOpen())
  shot('storage-native-box-naming');local naming=screen.naming
  -- Native SELECT/backspace and START/OK keep this a real keyboard input path.
  for _=1,8 do press('b')end
  press('a');press('start');press('a',150)
  assert(not screen.naming and naming.isOpen()==false)
  assert(screen.session.storage.boxes[14].name=='A');close()
  assert(game.save.boxNames[14]=='A'and game.save.boxes[14].wallpaper==5 and game.save.boxes[14][3].markings==3 and game.save.boxes[14][3].gen3Markings==3)
  report.cases.markingCancelAndCommit=true;report.cases.boxJumpWallpaperAndNaming=true

  -- Deposit heals using native move PP, with sparse source/target identity kept.
  a,b,c,d=fixture();a.hp=1;a.status='POISON';a.statusWord=8;a.moves[1]={id='CUT',pp=1,maxPp=39,ppUps=3}
  local original=core();ui=open('deposit');assert(ui.mode=='party_drawer')
  shot('storage-native-deposit-party');action('STORE');assert(ui.mode=='pick_box');shot('storage-native-deposit-target')
  press('a',200);assert(#screen.session.party==1 and screen.session.storage.boxes[1].mons[1])
  assert(original==core());close()
  assert(game.save.boxes[1][1]==a and a.hp==a.stats.hp and not a.status and a.statusWord==0 and a.moves[1].pp==48)
  assert(game.save.party[1]==b);report.cases.depositHealAndNativePp=true
  game.save.currentBox=1;ui=open('withdraw');action('WITHDRAW');close()
  assert(game.save.party[2]==a and not game.save.boxes[1][1]);report.cases.withdrawStableIdentity=true

  -- Native guards: last able mon, eggs, attached mail, full party and full box.
  a,b,c,d=fixture();b.hp=0;ui=open('deposit');action('STORE');assert(ui.mode=='message')
  shot('storage-native-last-able-mon');press('b');close()
  fixture();game.save.party[1].item='ORANGE_MAIL';ui=open('deposit');action('STORE');assert(ui.mode=='message')
  shot('storage-native-mail-guard');press('b');close()
  fixture();game.save.boxes[14][3].isEgg=true;ui=open();slot(3);action('RELEASE');assert(ui.mode=='message')
  shot('storage-native-egg-guard');press('b');close()
  fixture();for i=3,6 do game.save.party[i]=Pokemon.new(game.data,'ZIGZAGOON',2)end
  menu=require('src.ui.Gen3StorageMenu').new(game);game.stack:push(menu);press('a');assert(menu.message=='gPCText_PartyFull2')
  shot('storage-native-full-party');press('b');press('b');assert(game.stack:top()==world)
  fixture();for i=1,30 do game.save.boxes[1][i]=Pokemon.new(game.data,'WURMPLE',3)end
  ui=open('deposit');action('STORE');press('a');assert(ui.mode=='deposit_box_full');shot('storage-native-full-box')
  press('b');press('right');press('a',180);assert(#screen.session.party==1);close()
  report.cases.nativeLastAbleEggMailAndFullGuards=true

  -- Release defaults to NO. A true release and the RS last-SURF return are distinct.
  a,b,c,d=fixture();original=core();ui=open();slot(3);action('RELEASE')
  local release=screen.load('src.ui.game3.release_seq');assert(release.yesNoCursor==2)
  shot('storage-native-release-default-no');press('a');assert(not release.isActive()and original==core())
  action('RELEASE');press('up');press('a',55);shot('storage-native-release-animation');U.wait(180)
  assert(release.state=='released'and not release.returns);press('a');press('a');close()
  assert(not game.save.boxes[14][3]and game.save.boxes[14][30]==c);report.cases.releaseDefaultNoAndConfirmedYes=true
  fixture();local surfer=game.save.boxes[14][3];surfer.moves={{id='SURF',pp=15}};ui=open();slot(3);action('RELEASE')
  release=screen.load('src.ui.game3.release_seq');press('up');press('a',220)
  assert(release.returns and release.state=='released');press('a');press('a',80)
  assert(release.state=='came_back');shot('storage-native-last-surf-came-back')
  press('a');press('a');assert(not release.isActive());close();assert(game.save.boxes[14][3]==surfer)
  report.cases.lastSurfReturnsWithoutDeletion=true
  -- External teardown while holding discards the private edit, leaving autosave intact.
  fixture();original=core();ui=open();slot(3);action('MOVE');assert(ui.holdingMon)
  game.stack:pop();U.wait(5);assert(original==core());report.cases.teardownWhileHoldingPreservesSave=true
  report.closeCallbacks=closed;report.status='pass';persist();love.event.quit(0)
end
