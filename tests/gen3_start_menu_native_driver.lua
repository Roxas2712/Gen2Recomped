-- Prepared field/menu fixture. No ordinary-story completion is claimed.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local S=require('src.core.SaveSerializer');local V=require('src.core.GameVersion')
  local Menu=require('src.ui.Gen3StartMenu');local IO=require('src.core.SaveData')
  local edition=V.get();local rs=edition=='ruby'or edition=='sapphire'
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  U.teleport(game,V.isFRLG()and'MAP_G00_N00'or'MAP_G00_N12',9,7,'down');U.wait(90)
  local world=game.stack:top();local record=assert(game.data.constants.gen3StartMenu)
  game.save.party={require('src.pokemon.Pokemon').new(game.data,V.isFRLG()and'BULBASAUR'or'TREECKO',12)}
  game.save.player.name='AURORA';game.save.options.gen3Frame=20
  game.save.flags[record.pokedexFlag]=true
  if record.pokenavFlag then game.save.flags[record.pokenavFlag]=true end
  game.modStatus={available={{id='prepared_menu_fixture'}}}
  local report={edition=edition,status='running',preparedStartMenuFixture=true,continuousStory=false,
    fullStoryAccepted=false,captures={},cases={},views={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 5)
  end
  local owner
  local function open()
    owner=Menu.new(game);game.stack:push(owner);U.wait(20)
    assert((owner.rsStartNative~=nil)==rs,'Wrong edition START renderer')
    return owner
  end
  local function shot(name)
    local bytes=S.encode(game.save);local rng=love.math.getRandomState()
    local disk=love.filesystem.read(IO.saveFilename(edition))
    assert(require('src.render.GraphicsScope').call(function()owner:draw()end))
    assert(S.encode(game.save)==bytes and love.math.getRandomState()==rng,'START draw mutated save/RNG')
    assert(love.filesystem.read(IO.saveFilename(edition))==disk,'START draw wrote a save')
    local tpl=owner:contentTemplate();local first,last=owner:visibleRange()
    assert(tpl.left>=1 and tpl.top>=1 and tpl.left+tpl.width<=29 and tpl.top+tpl.height<=19)
    assert(first<=owner.index and owner.index<=last and last-first<8)
    report.views[name]={rectangle=tpl,first=first,last=last,index=owner.index,rowCount=#owner.rows,rows={}}
    for i=first,last do report.views[name].rows[#report.views[name].rows+1]=owner.rows[i].id end
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  open();assert(#owner.rows>8);shot('start-original-rows-top')
  for index=2,#owner.rows do press('down');assert(owner.index==index)end
  assert(owner.rows[owner.index].key=='quit');shot('start-host-rows-bottom')
  press('down');assert(owner.index==1 and owner:visibleRange()==1)
  press('up');assert(owner.index==#owner.rows)
  report.cases.originalAndHostRowsPageAndWrap=true
  local chosen=0
  owner.rows[#owner.rows+1]={id='custom_action',key='custom_action',label='A VERY LONG CUSTOM ACTION',
    onSelect=function(g,row)assert(g==game and row.id=='custom_action');chosen=chosen+1 end}
  press('down');assert(owner.index==#owner.rows);shot('start-long-custom-action')
  press('a');assert(chosen==1 and game.stack:top()==owner)
  report.cases.stableCustomIdCallbackAndLongLabel=true
  press('b');assert(game.stack:top()==world)
  local function select(key)
    for _=1,#owner.rows do
      if owner.rows[owner.index].key==key then local index=owner.index;press('a',45);return index end
      press('down')
    end
    error('Missing START action '..key)
  end
  open();local bagIndex=select('bag');assert(game.stack:top()~=owner)
  press('b',90);owner=game.stack:top();assert(getmetatable(owner)==Menu)
  assert(owner.index==bagIndex and owner.rows[owner.index].key=='bag','BAG return lost the native START cursor')
  shot('start-bag-return');report.cases.actualBagReturn=true
  local optionIndex=select('option');assert(game.stack:top()~=owner)
  press('b',90);owner=game.stack:top();assert(getmetatable(owner)==Menu)
  assert(owner.index==optionIndex and owner.rows[owner.index].key=='option','OPTION return lost the native START cursor')
  shot('start-option-return');report.cases.actualSubmenuCursorRetained=true
  press('b');assert(game.stack:top()==world)
  press('start',45);owner=game.stack:top();assert(getmetatable(owner)==Menu)
  assert(owner.index==optionIndex and owner.rows[owner.index].key=='option','Fresh field START lost its native RAM cursor')
  shot('start-field-reopen-retained');report.cases.actualFieldReopenCursorRetained=true
  if rs then
    select('save');local save=game.stack:top();assert(save.screenId=='Gen3RsSaveMenu')
    press('b',45);assert(game.stack:top()==owner and not save.wrote)
    shot('start-native-save-cancel-return');report.cases.actualNativeSaveCancel=true
  end
  press('b');assert(game.stack:top()==world)
  report.cases.drawSaveDiskAndGameplayRngImmutable=true
  report.cases.nativeRsFontFrameOutlineCursor=rs
  report.status='pass';persist()
  print('[gen3-start-menu] PASS '..edition..' visible pages, native RS art and host callbacks')
  love.event.quit(0)
end
