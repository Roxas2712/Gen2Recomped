-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared option fixtures; ordinary input and real host option persistence.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local Values=require('src.core.Gen3RsOptionValues')
  local UI=require('src.ui.Gen3Options');local version=require('src.core.GameVersion').get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..version..'%-'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  game.save.player.gender=version=='firered'and'boy'or'girl'
  U.teleport(game,version=='emerald'and'MAP_G01_N01'or'MAP_G04_N00',4,2,'down');U.wait(60)
  local report={edition=version,status='running',preparedFixture=true,continuousStory=false,captures={},cases={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 8)
  end
  local function shot(name)
    local before=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(game.stack:top().draw,game.stack:top()))
    assert(before==Save.encode(game.save)and rng==love.math.getRandomState(),'Option draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local options=game.save.options
  options.textSpeed=3;options.battleAnim=true;options.battleStyle='shift';options.stereo=false
  options.gen3ButtonMode=1;options.gen3Frame=1;options.qaUnrelated='keep'
  local base=Values.read(options);local callback=0;local world=game.stack:top()
  local Extra=require('src.ui.OptionsMenu');local build=Extra.buildRows;local activations=0
  Extra.buildRows=function(g)
    local rows=build(g)
    rows[#rows+1]={id='qaOptionStep',label='QA STEP',value=function(host)
      assert(host==game);return tostring(host.save.options.qaOptionStep or 0)
    end,step=function(host,dir)
      assert(host==game);host.save.options.qaOptionStep=(host.save.options.qaOptionStep or 0)+dir;return true
    end}
    rows[#rows+1]={id='qaOptionAction',label='QA ACTION',activate=function(host)
      assert(host==game);activations=activations+1
    end}
    return rows
  end
  local function open()
    local screen=UI.new(game,{onCancel=function()callback=callback+1 end});game.stack:push(screen)
    assert(screen.rsNative and screen.rsNative.record.version==version,'Own edition did not select original options')
    U.wait(40);assert(screen.rsNative.scene.isOpen())
    return screen,screen.rsNative.scene
  end
  local function pages(scene)return version=='emerald'and scene._st.pages or scene._pages end
  local screen,scene=open();shot('native-edition-options-six-original-rows')
  local frames=version=='emerald'and 20 or 10
  local counts={3,2,2,2,3,frames}
  for i,key in ipairs(Values.keys)do
    assert(scene.cursor==i)
    local initial=Values.read(options)[key]
    for _=1,counts[i]do press('right')end
    assert(Values.read(options)[key]==initial,'Native right wrapping failed for '..key)
    press('left');assert(Values.read(options)[key]==(initial-1)%counts[i],'Native left wrapping failed for '..key)
    shot('native-edition-options-'..key)
    press('down')
  end
  assert(options.textSpeed==5 and options.gen3Frame==frames,'Native choices did not update the host fields')
  local expected=Values.read(options)
  -- The host's existing controls/mod/graphics options remain on a native subpage.
  assert(scene.cursor==7);press('a');assert(#pages(scene)==2)
  shot('native-edition-options-extra-host-settings')
  local function find(label)
    for _=1,256 do
      local page=pages(scene)[#pages(scene)];local row=page.rows[page.index]
      if row and row.label==label then return end;press('down')
    end
    error('Host option was lost: '..label)
  end
  find('QA STEP');press('right');assert(options.qaOptionStep==1)
  assert(require('src.core.SaveData').loadOptions().qaOptionStep==1,'Host extra row did not persist through its ordinary callback')
  assert(Values.read(options).textSpeed==expected.textSpeed,'Extra setting changed a cartridge field')
  find('QA ACTION');press('a');assert(activations==1,'Host activation callback was lost or duplicated')
  shot('native-edition-options-host-callbacks');press('b');assert(#pages(scene)==1)
  press('down');assert(scene.cursor==8);shot('native-edition-options-scroll-and-cancel')
  press('a',90)
  assert(game.stack:top()==world and callback==1,'Native CANCEL did not restore its owner callback once')
  assert(Save.encode(Values.read(options))==Save.encode(expected),'Native CANCEL did not commit all six host settings')
  local disk=require('src.core.SaveData').loadOptions()
  assert(Save.encode(Values.read(disk))==Save.encode(expected),'Options were not persisted through the host path')
  assert(options.qaUnrelated=='keep'and disk.qaUnrelated=='keep','Unrelated option field was lost')
  report.cases.allNativeEnumsWrap=true;report.cases.immediateHostPersistence=true;report.cases.extraHostRowsReachable=true
  report.cases.nativeCancelPersistsAllSix=true;report.cases.callbackOnce=true
  screen,scene=open();assert(Values.read(options).frameType==frames-1)
  shot('native-edition-options-reopened-last-frame');press('up');assert(scene.cursor==8,'UP did not wrap to CANCEL')
  press('b',90);assert(game.stack:top()==world and callback==2)
  -- Actual original main-menu OPTION return must also refresh its frame.
  local menu=require('src.ui.Gen3MainMenu').new(game,{});game.stack:push(menu);U.wait(90)
  for _=1,8 do
    if menu.items[menu.index].key=='option'then break end;press('down')
  end
  assert(menu.items[menu.index].key=='option');press('a',50)
  assert(game.stack:top().rsNative,'Main-menu OPTION did not reach native view')
  press('b',100);assert(game.stack:top()==menu)
  shot('native-edition-options-main-menu-return')
  Extra.buildRows=build
  report.cases.hostStepAndActivateCallbacks=true
  report.cases.mainMenuReturn=true;report.cases.originalFrameCount=frames;report.drawPreservesSaveRng=true
  report.status='pass';persist();print('PASS_NATIVE_EDITION_OPTIONS');love.event.quit(0)
end
