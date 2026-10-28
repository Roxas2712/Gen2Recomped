-- Prepared dex coverage, deliberately separate from ordinary story lineage.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local Native=require('src.ui.Gen3RsPokedex')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local report={edition=edition,status='running',preparedPokedexFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,referenceCommit='fb7b0366efcb85e703e9e6d5a8a24d01456a109b'}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  persist();U.freshSave(game);U.teleport(game,'MAP_G00_N11',11,9,'right');U.wait(120)
  -- Read scalar fields directly from the cartridge, independently of the
  -- reference extractor's serializer and the runtime's species-number views.
  local rawFile=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'))
  local rom=rawFile:read('*a');rawFile:close()
  local function u16(off)local a,b=rom:byte(off+1,off+2);return a+b*256 end
  local function s16(off)local n=u16(off);return n<32768 and n or n-65536 end
  local load=require('compat.gen1-rs.Loader').new(edition)
  local symbols=load('src.import.gba.syms').of(edition)
  local chunk=assert(love.filesystem.load('data/generated/gba/pokemon/pokedex/entries.lua'));setfenv(chunk,{})
  local entries=chunk();local base=symbols.off('gPokedexEntries');local checked=0
  for _,def in pairs(game.data.pokemon)do
    if def.dex and def.dex>=1 and def.dex<=386 and def.index and def.index<252 or
       def.dex and def.dex>=252 and def.dex<=386 and def.index then
      local e=entries[def.index]
      if e then
        local off=base+def.dex*36
        for key,offset in pairs({height=12,weight=14,pokemonScale=26,pokemonOffset=28,trainerScale=30,trainerOffset=32})do
          local value=key:find('Offset')and s16(off+offset)or u16(off+offset)
          assert(e[key]==value,'Cartridge dex field mismatch '..def.name..' '..key);checked=checked+1
        end
      end
    end
  end
  assert(checked==386*6);report.independentCartridgeFields=checked
  local world=game.stack:top();local screen;local closed=0
  local function press(key,delay)
    game.input:overlayPressed(key);U.wait(3);game.input:overlayReleased(key);U.wait(delay or 100)
    -- Cry completion uses the actual audio clock; accelerated game frames
    -- must wait for the native input gate instead of declaring a false hang.
    if screen and game.stack:top()==screen then
      for _=1,400 do
        local fn=screen.state.fn
        if fn~='loadInfo'and fn~='openInfoAfterMove'then break end
        U.wait(5)
      end
    end
  end
  local function shot(name)
    local before=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(before==Save.encode(game.save)and rng==love.math.getRandomState(),'Dex draw mutated save or RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function core()return Save.encode({dex=game.save.pokedex,party=game.save.party,boxes=game.save.boxes,flags=game.save.flags,vars=game.save.gen3Vars})end
  local function fixture(national)
    assert(game.stack:top()==world)
    game.save.nationalDex=national==true;game.save.gen3RsPokedex=nil
    game.save.pokedex={seen={TREECKO=true,GROVYLE=true,TORCHIC=true,ZIGZAGOON=true},
      owned={TREECKO=true,GROVYLE=true,ZIGZAGOON=true},customUnknown={keep=42}}
  end
  local function open()
    screen=require('src.ui.Gen3Pokedex').new(game,{onCancel=function()closed=closed+1 end})
    assert(getmetatable(screen)==Native);game.stack:push(screen);U.wait(220)
    assert(screen.state.fn=='mainInput',screen.state.fn);return screen.state
  end
  local function searchItem(target)
    local q=screen.state.searchState
    local key=q.topBar==0 and 'Search'or 'Shift'
    key=key..(screen.state.nationalEnabled and 'NatDex'or 'HoennDex')
    local graph=screen.load('src.ui.game3.rse.pokedex_gfx').manifest().search.movement[key]
    local queue={{q.menuItem,{}}};local seen={[q.menuItem]=true};local path
    for _,node in ipairs(queue)do
      if node[1]==target then path=node[2];break end
      for col,name in ipairs({'left','right','up','down'})do
        local dest=graph[node[1]+1][col]
        if dest~=255 and not seen[dest]then
          seen[dest]=true;local steps={};for i,v in ipairs(node[2])do steps[i]=v end
          steps[#steps+1]=name;queue[#queue+1]={dest,steps}
        end
      end
    end
    assert(path,'Unreachable native search item '..target)
    for _,keyName in ipairs(path)do press(keyName)end
    assert(q.menuItem==target)
  end
  fixture();local saved=game.save.pokedex;local seen=saved.seen;local owned=saved.owned;local before=core()
  local s=open();assert(s.seenCount==4 and s.ownCount==3 and s.dexMode==0)
  assert(s.list.items[0].dexNum==252 and s.list.items[0].owned)
  shot('pokedex-native-hoenn-list');press('start');assert(s.menuIsOpen)
  shot('pokedex-native-start-menu');press('b');press('a',220)
  assert(s.fn=='infoInput',s.fn);assert(s.info.owned and s.info.dexNum==252)
  shot('pokedex-native-treecko-page1')
  assert(screen.session.options.buttonMode==0);press('r');assert(s.selectedScreen==0,'NORMAL must not enable native R paging')
  press('a');assert(s.descriptionPage==1)
  shot('pokedex-native-treecko-page2');press('a');assert(s.descriptionPage==0)
  press('right');press('a',220);assert(s.fn=='areaInput',s.fn)
  assert(s.area.unknown);shot('pokedex-native-starter-area-unknown')
  press('right',220);assert(s.fn=='cryInput',s.fn);assert(s.cry.pcm and #s.cry.pcm.data>100)
  shot('pokedex-native-cry-screen');press('a',8);assert(screen.audio.isCryFinished()==false)
  shot('pokedex-native-cry-waveform');U.wait(150)
  press('right',220);assert(s.fn=='sizeInput',s.fn);assert(s.sizeMon.img and s.sizeTrainer.img)
  shot('pokedex-native-size-comparison');press('b',220);assert(s.fn=='infoInput')
  press('b',220);assert(s.fn=='mainInput');press('b',220)
  assert(game.stack:top()==world and closed==1 and before==core())
  assert(game.save.pokedex==saved and saved.seen==seen and saved.owned==owned and saved.customUnknown.keep==42)
  report.cases.nativeListInfoTwoPagesAndAudioSize=true
  report.cases.dexBitsAndStableSaveIdentityPreserved=true

  -- Unseen rows stay unavailable; a seen-only species hides measurements.
  s=open();press('down');press('down');assert(s.selected==2,'Expected unseen row 2, got '..s.selected..'/'..s.fn)
  local fn=s.fn;press('a');assert(s.fn==fn and not s.info)
  press('down');assert(s.list.items[s.selected].dexNum==255)
  press('a',220);assert(s.info and not s.info.owned)
  shot('pokedex-native-seen-only-entry');press('right');press('right');press('right');press('a')
  assert(s.fn=='infoInput','Seen-only size must remain locked')
  press('b',220);press('b',220);assert(game.stack:top()==world)
  report.cases.unseenAndSeenOnlyRestrictions=true

  -- Actual wild encounter locations must produce highlights, not a placeholder.
  s=open();for _=1,13 do press('down',50)end
  while s.list.items[s.selected].dexNum~=263 and s.selected<s.list.count-1 do press('down',50)end
  assert(s.list.items[s.selected].dexNum==263);press('a',220)
  press('right');press('a',220);assert(s.fn=='areaInput'and not s.area.unknown)
  assert(#s.area.found.overworld>0);shot('pokedex-native-zigzagoon-area')
  press('b',220);press('b',220);press('b',220);assert(game.stack:top()==world)
  report.cases.realEncounterAreaHighlights=true

  -- SELECT opens the original search UI; cancellation restores the list.
  s=open();local selected=s.selected;press('select',220);assert(s.fn=='searchTopBar',s.fn)
  shot('pokedex-native-search');press('b',220);assert(s.fn=='mainInput'and s.selected==selected)
  press('b',220);assert(game.stack:top()==world and before==core())
  report.cases.nativeSearchCancel=true

  s=open();press('select',220);press('a');assert(s.fn=='searchMenu')
  press('a');assert(s.fn=='searchParam');local original=s.searchState.cursor[0]
  press('down');shot('pokedex-native-search-name-parameter');press('b')
  assert(s.searchState.cursor[0]==original,'Search parameter B must restore its value')
  searchItem(6);press('a',150);assert(s.fn=='searchDone'and s.list.count==4)
  shot('pokedex-native-search-completed');press('a',220)
  assert(s.fn=='mainInput'and s.page==3 and s.list.count==4)
  shot('pokedex-native-search-results');press('b',220)
  assert(s.fn=='mainInput'and s.page==0);press('b',220)
  assert(game.stack:top()==world and before==core());report.cases.nativeSearchResultsAndParameterCancel=true

  game.save.gen3RsPokedex={mode=0,order=0,privateUnknown=55};local prefs=game.save.gen3RsPokedex
  s=open();press('select',220);press('right');press('a');assert(s.searchState.menuItem==4)
  press('a');press('down');press('a');searchItem(6);press('a',220)
  assert(s.fn=='mainInput'and s.dexOrder==1 and s.list.count==4)
  shot('pokedex-native-alphabetical-order');press('b',220)
  assert(game.save.gen3RsPokedex==prefs and prefs.order==1 and prefs.privateUnknown==55)
  s=open();assert(s.dexOrder==1 and s.list.count==4);press('b',220)
  assert(before==core());report.cases.nativeSortPreferencesPersistWithoutDexChanges=true

  -- Native registration is a separate two-page entry and closes exactly once.
  local registration=require('src.ui.Gen3DexEntry').new(game,{species='TREECKO',forceOwned=true})
  assert(getmetatable(registration)==Native);game.stack:push(registration);U.wait(220)
  assert(registration.state.fn=='caughtInput');shot('pokedex-native-caught-registration-page1')
  press('a');assert(registration.state.descriptionPage==1)
  shot('pokedex-native-caught-registration-page2');press('a',220)
  assert(game.stack:top()==world and before==core());report.cases.nativeCaughtRegistration=true
  fixture(true);game.save.pokedex.seen.BULBASAUR=true;game.save.pokedex.owned.BULBASAUR=true
  game.save.gen3RsPokedex={mode=1,order=0};before=core();s=open()
  assert(s.nationalEnabled and s.dexMode==1 and s.seenCount==5 and s.ownCount==4)
  shot('pokedex-native-national-list');press('b',220);assert(before==core())
  report.cases.nativeNationalCountsAndList=true
  fixture();game.save.pokedex={seen={},owned={}};before=core();s=open()
  assert(s.list.count==0 and s.seenCount==0 and s.ownCount==0)
  shot('pokedex-native-empty-list');press('a');press('down');press('b',220)
  assert(game.stack:top()==world and before==core());report.cases.emptyDexSafeReturn=true
  local originalMode=game.save.options.gen3ButtonMode
  game.save.options.gen3ButtonMode=2;game.input:setButtonMode(2);fixture();before=core();s=open()
  assert(screen.session.options.buttonMode==1);press('a',220)
  assert(s.fn=='infoInput'and s.selectedScreen==0)
  press('r');assert(s.selectedScreen==1);press('l');assert(s.selectedScreen==0)
  press('b',220);press('b',220);assert(game.stack:top()==world and before==core())
  game.save.options.gen3ButtonMode=3;game.input:setButtonMode(3);fixture();before=core();s=open()
  assert(screen.session.options.buttonMode==2);press('l',220)
  assert(s.fn=='infoInput'and s.selectedScreen==0);press('l');assert(s.descriptionPage==1)
  press('b',220);press('b',220);assert(game.stack:top()==world and before==core())
  game.save.options.gen3ButtonMode=originalMode;game.input:setButtonMode(originalMode or 1)
  report.cases.nativeButtonModes=true
  report.closeCallbacks=closed;report.status='pass';persist();love.event.quit(0)
end
