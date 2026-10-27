-- Prepared menu fixtures, never ordinary story completion.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local V=require('src.core.GameVersion');local IO=require('src.core.SaveData')
  local Save=require('src.core.SaveSerializer');local Menu=require('src.ui.Gen3MainMenu')
  local Native=require('src.ui.Gen3RsMainMenu');local edition=V.get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  while game.stack:top()do game.stack:pop()end
  local backdrop={update=function()end,draw=function()end,isOpaque=true}
  game.stack:push(backdrop)
  game.input:reset();U.freshSave(game)
  assert(not IO.saveFileExists(edition))
  local report={edition=edition,status='running',preparedMainMenuFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 4)
  end
  local owner;local calls={newGame=0,continue=0,cancel=0,exit=0}
  local function open()
    owner=Menu.new(game,{onNewGame=function()calls.newGame=calls.newGame+1;game.stack:pop()end,
      onContinue=function()calls.continue=calls.continue+1;game.stack:pop()end,
      onCancel=function()calls.cancel=calls.cancel+1 end})
    assert(owner.rsNative);game.stack:push(owner);U.wait(45)
    assert(owner.rsNative.scene.state=='input')
    local w,h=owner:uiSize();assert(w==240 and h==160)
    return owner.rsNative.scene
  end
  local function shot(name)
    local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
    local disk=love.filesystem.read(IO.saveFilename(edition))
    assert(require('src.render.GraphicsScope').call(function()owner:draw()end))
    assert(Save.encode(game.save)==bytes and love.math.getRandomState()==rng)
    assert(love.filesystem.read(IO.saveFilename(edition))==disk)
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local s=open();assert(#s.items==3 and s.items[1]=='NEW_GAME')
  shot('native-empty-menu')
  press('up');assert(s.cursor==1,'RS native cursor must clamp, not wrap')
  press('a',45);assert(calls.newGame==1 and game.stack:top()==backdrop)
  report.cases.emptyMenuAndNewGameCallback=true
  local C=require('compat.gen1-rs.Constants').new(require('compat.gen1-rs.Loader').new(edition))
  local function flag(id,on)game.save.flags[('FLAG_G3_%04X'):format(id)]=on or nil end
  for n=C:flag('FLAG_BADGE01_GET'),C:flag('FLAG_BADGE01_GET')+2 do flag(n,true)end
  game.save.pokedex.owned={TREECKO=true,PIKACHU=true,MEWTWO=true}
  game.save.pokedex.caught={TREECKO=true}
  game.save.player.name='AURORA';game.save.playTime={hours=123,minutes=45,seconds=0}
  for _,gender in ipairs({'boy','girl'})do
    game.save.player.gender=gender;game.save.options.gen3Frame=gender=='girl'and 20 or 1
    assert(IO.save(game.save));local disk=assert(love.filesystem.read(IO.saveFilename(edition)))
    s=open();assert(#s.items==4 and s.items[1]=='CONTINUE')
    assert(s.info.name=='AURORA'and s.info.badges==3 and s.info.dexCount==2)
    assert(s.info.hours==123 and s.info.minutes==45 and s.info.gender==(gender=='girl'and 1 or 0))
    assert(s.frameType==(gender=='girl'and 19 or 0))
    shot('native-'..gender..'-continue-stats')
    press('down');assert(s.cursor==2)
    shot('native-'..gender..'-new-game-highlight')
    press('down');press('down');assert(s.cursor==4 and s.scroll==0)
    press('down');assert(s.cursor==4)
    shot('native-'..gender..'-exit-highlight')
    press('up');press('up');press('up');assert(s.cursor==1 and s.scroll==0)
    if gender=='boy'then
      press('a',45);assert(calls.continue==1 and game.stack:top()==backdrop)
    else press('b',45);assert(calls.cancel==1 and game.stack:top()==backdrop)end
    assert(love.filesystem.read(IO.saveFilename(edition))==disk)
  end
  report.cases.nativeContinueSummaryBothGendersFrames=true
  report.cases.highlightDimmingFullHeightAndClamp=true
  report.cases.directContinueAndTitleCancelCallbacks=true
  report.cases.saveBytesUnchangedByMenu=true
  game.save.nationalDex=true;flag(C:flag('FLAG_SYS_NATIONAL_DEX'),true)
  game.save.gen3Vars=game.save.gen3Vars or{};game.save.gen3Vars[C:var('VAR_NATIONAL_DEX')]=0x302
  assert(Native.snapshot(game,game.save).dexCount==3)
  game.save.gen3Vars[C:var('VAR_NATIONAL_DEX')]=nil
  assert(Native.snapshot(game,game.save).dexCount==2)
  report.cases.strictNationalGateAndDeduplicatedRegionalCount=true
  s=open();press('down');press('down');assert(s.items[s.cursor]=='OPTION')
  press('a',45);assert(game.stack:top()~=owner and owner.rsNative.waitingOptions)
  press('b',50);assert(game.stack:top()==owner and s.state=='input')
  shot('native-options-return')
  report.cases.actualHostOptionsReturn=true
  local actualExit=game.returnToLauncher
  game.returnToLauncher=function(self)calls.exit=calls.exit+1;self.stack:pop()end
  press('down');assert(s.items[s.cursor]=='EXIT');press('a',45)
  assert(calls.exit==1 and game.stack:top()==backdrop);game.returnToLauncher=actualExit
  report.cases.exitCallback=true
  local stock={{key='newGame',label='NEW GAME'},{key='option',label='OPTION'},{key='exit',label='EXIT GAME'}}
  local custom={game=game,items={stock[1],stock[2],stock[3],{key='custom',label='CUSTOM'}}}
  assert(not Native.available(custom));custom.items={stock[1],stock[2],stock[3],{key='exit',label='EXIT GAME'}}
  assert(not Native.available(custom));custom.items={{key='newGame',label='RENAMED'},stock[2],stock[3]}
  assert(not Native.available(custom))
  report.cases.customModRowsRetainHostContract=true
  report.calls=calls;report.status='pass';persist()
  print('[rs-main-menu] PASS '..edition..' original panels, stats, cursor, fades and host callbacks')
  love.event.quit(0)
end
