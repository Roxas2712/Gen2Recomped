-- Prepared native menu states; full story is covered separately, not implied.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local F=require('src.render.Font');local Save=require('src.core.SaveData')
  local Serialize=require('src.core.SaveSerializer');local Scope=require('src.render.GraphicsScope')
  local Menu=require('src.ui.Gen3MainMenu');local Title=require('src.ui.Gen3TitleFRLG')
  local Kit=require('src.ui.Gen3FrlgMainMenu');local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(require('src.core.GameVersion').get()=='leafgreen')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-leafgreen%-'))
  local report={edition='leafgreen',status='running',captures={},comparisons={},preparedSave=true,fullStoryTested=false}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local top=assert(game.stack:top());local old=Serialize.encode(game.save);local rng=love.math.getRandomState()
    local ok,why=Scope.call(top.draw,top);assert(ok,why)
    assert(Serialize.encode(game.save)==old and love.math.getRandomState()==rng,'Menu draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function waitFor(fn,n)for _=1,n do if fn()then return end;U.wait(1)end;error('Menu condition timed out')end
  local function press(k,n)
    game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(n or 1)
  end
  local function titleMenu()
    waitFor(function()return getmetatable(game.stack:top())==Title and game.stack:top().phase=='run'end,1400)
    press('start',150);local m=game.stack:top();assert(getmetatable(m)==Menu and m.frlgFade==0);return m
  end
  persist();press('b',8);press('b',8);local menu=titleMenu()
  assert(not menu.frlgSummary and #menu.items==3);shot('no-save-new-game')
  press('up');assert(menu.index==1);press('down');assert(menu.items[menu.index].key=='option')
  shot('no-save-option');press('a',30)
  assert(getmetatable(game.stack:top())==require('src.ui.Gen3Options'));shot('options-from-main-menu')
  local options=game.stack:top();local oldFrame=game.save.options.gen3Frame or 1
  for i,row in ipairs(options.rows)do if row.key=='frame'then options.index=i end end
  press('right',2);assert(game.save.options.gen3Frame~=oldFrame);shot('options-frame-preview')
  press('b',30);assert(game.stack:top()==menu and menu.frlgFade==0)
  assert(menu.frlgFrame==game.save.options.gen3Frame,'Options frame change was lost on menu return')
  shot('options-return-to-menu')
  press('b',30);assert(getmetatable(game.stack:top())==Title)
  local native=assert(game.data.constants.gen3FRLGMainMenu)
  local words={native.text.player,native.text.pokedex,native.text.time,native.text.badges}
  local labels={gText_Continue='CONTINUE',gText_NewGame='NEW GAME',gText_MysteryGift='OPTION',gText_MenuExit='EXIT GAME',
    gText_Player=words[1],gText_Time=words[3],gText_Pokedex=words[2],gText_Badges=words[4]}
  local function fontText(value,x,y,opts)
    F.pushStyle({text=opts.colors.fg,shadow=opts.colors.shadow})
    local ok,why=pcall(F.draw,tostring(value or ''),x,y);F.popStyle();assert(ok,why)
  end
  local window={template=function(l,t,w,h)return {left=l,top=t,w=w,h=h}end,
    userFrame=function(t,n)F.drawBox(t.left-1,t.top-1,t.w+2,t.h+2,n+1)end,
    printPx=fontText}
  local bindings={['src.core.game3.display']={W=240,H=160},['src.ui.game3.window']=window,
    ['src.core.game3.rom_text']={plain=function(k)return assert(labels[k],k)end},
    ['src.ui.game3.list_menu']={drawArrow=function(_,x,y,t)Kit.drawArrow(menu,x,y,t)end}}
  for _,n in ipairs({'src.core.game3.audio','src.core.game3.se_ids','src.ui.game3.new_game_scene',
    'src.ui.game3.naming_chrome','src.ui.game3.intro_movie','src.ui.game3.title_screen','src.ui.game3.frlg_font',
    'src.ui.game3.chrome','src.core.game3.mystery_gift','src.ui.game3.mystery_gift','src.ui.game3.boot_modules'})do bindings[n]={}end
  local original=require('compat.gen1-frlg.Loader').new(bindings)('src.ui.game3.boot')
  local function pixels(name)
    local f=assert(io.open(out..'/'..name..'.png','rb'));local b=f:read('*a');f:close()
    return love.image.newImageData(love.filesystem.newFileData(b,name..'.png'))
  end
  local function compare(name,m)
    local oldDraw,oldUpdate=m.draw,m.update;local oldLoad=Save.load
    m.frlgFade=0;m.frlgTick=0;m.update=function()end
    Save.load=function()error('Drawing attempted to load/recover a save')end
    shot(name..'-host')
    local s=assert(m.frlgSummary);local w,h=m:uiSize();assert(w==240 and h==160)
    local state={phase='menu',hasContinue=true,menuIndex=m.index,menuScroll=m.frlgScroll,blink=0,fadeT=0,
      continueInfo={name=s.name,gender=s.girl and 1 or 0,hours=math.floor(Save.playSeconds(m.frlgSave)/3600),
        minutes=math.floor(Save.playSeconds(m.frlgSave)/60)%60,hasDex=s.hasDex,dexCount=s.dexCount,badges=s.badges,frameType=s.frame-1}}
    m.draw=function()original.draw(state)end;shot(name..'-reference')
    m.draw,m.update=oldDraw,oldUpdate;Save.load=oldLoad
    local a,b=pixels(name..'-host'),pixels(name..'-reference')
    local aw,ah=a:getDimensions();local bw,bh=b:getDimensions();assert(aw==bw and ah==bh)
    local equal=a:getString()==b:getString()
    report.comparisons[name]={exactFramebufferMatch=equal,pixels=aw*ah,hostExtensionLabels={'OPTION','EXIT GAME'},
      nativeGeometryAndContinueFields=true,sharedHostFontAndFrameBridge=true}
    a:release();b:release();persist();assert(equal,'Native main-menu framebuffer mismatch: '..name)
  end
  -- Build only a disposable QA save: no personal save is loaded or copied.
  local prepared=game.save
  prepared.player.name='ALICE';prepared.player.gender='boy';prepared.playTime=3723
  prepared.flags.FLAG_G3_0829=nil;prepared.flags.FLAG_G3_0840=nil;prepared.nationalDex=false
  prepared.pokedex={owned={BULBASAUR=true,MEW=false,TREECKO=true}}
  local badges=require('src.inventory.Badges');local badgeRows=badges.list(game.data)
  badges.set(prepared,badgeRows[1],true,'leafgreen');badges.set(prepared,badgeRows[2],true,'leafgreen')
  prepared.options.gen3Frame=7
  assert(Save.save(prepared,game.mods));game:returnToTitle();menu=titleMenu()
  assert(menu.frlgSummary and not menu.frlgSummary.hasDex and menu.frlgSummary.frame==7)
  assert(menu.frlgSummary.badges==2 and menu.frlgSummary.dexCount==1)
  assert(menu:frlgWindows()[1].th==10 and menu:frlgWindows().step==16)
  compare('continue-before-pokedex',menu)
  menu.index=2;menu.frlgScroll=0;compare('new-game-native-position',menu)
  menu.index=4;menu.frlgScroll=4;compare('exit-after-native-scroll',menu)
  press('up');assert(menu.index==3 and menu.frlgScroll==4);compare('option-scrolled-up',menu)
  menu.index=1;menu.frlgScroll=0
  prepared.flags.FLAG_G3_0829=true;prepared.player.gender='girl';prepared.options.gen3Frame=10
  assert(Save.save(prepared,game.mods));game:returnToTitle();menu=titleMenu()
  assert(menu.frlgSummary.girl and menu.frlgSummary.hasDex and menu.frlgSummary.frame==10)
  compare('girl-pokedex-saved-frame',menu)
  local old=Serialize.encode(menu.frlgSave);local custom=menu.frlgSave.player.name
  menu.frlgSave.player.name='CUSTOMLONGNAME';menu.frlgSummary=Kit.snapshot(game,menu.frlgSave)
  shot('custom-name-display-only');assert(menu.frlgSave.player.name=='CUSTOMLONGNAME')
  menu.frlgSave.player.name=custom;assert(Serialize.encode(menu.frlgSave)==old)
  menu.frlgSummary=Kit.snapshot(game,menu.frlgSave)
  local actual=menu.items
  menu.items={};for i=1,9 do menu.items[i]={key='option',label='MOD OPTION '..i}end
  local invoked=0;local row={key='custom',label='CUSTOM ACTION',onSelect=function()invoked=invoked+1 end}
  menu.items[9]=row;menu.index=9;menu.frlgScroll=0;shot('many-mod-rows-scroll')
  press('a',30);assert(invoked==1 and menu.items[9]==row,'Mod action identity/callback lost')
  menu.items=actual;menu.index=1;menu.frlgScroll=0;U.wait(20)
  press('a',120);assert(game.overworld and game.stack:top()==game.overworld,'Native menu CONTINUE lost host callback')
  shot('continue-host-field')
  report.optionsAndReturn=true;report.optionsFrameAppliedOnReturn=true;report.nativeContinueGeometry=true;report.savedFrameAndGender=true
  report.regionalDexAndReceiptGate=true;report.modRowsAndCallbacks=true;report.continueThroughTitle=true
  report.drawSaveAndRngImmutable=true;report.status='pass';persist();print('PASS_LEAFGREEN_MAIN_MENU');love.event.quit(0)
end
