-- Prepared bag fixtures exercise the real native tag and host return path.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local Bag=require('src.ui.Gen3BagMenu')
  local Action=require('src.ui.Gen3ItemMenu');local Native=require('src.ui.Gen3RsBerryTag')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(Native.available(game)and require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game);U.teleport(game,'MAP_G00_N11',11,9,'right');U.wait(90)
  local world=game.stack:top();local inventory,order={},{}
  for number=133,175 do
    local found
    for id,def in pairs(game.data.items)do if def.index==number then assert(not found);found=id end end
    assert(found,'Missing original berry item '..number);inventory[found]=3;order[#order+1]=found
  end
  game.save.inventory,game.save.bagOrder=inventory,order
  local report={edition=edition,status='running',preparedBerryFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,normalPlayTimeExcluded=true}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(bytes==Save.encode(game.save)and rng==love.math.getRandomState(),'Tag draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 3)
  end
  local function unrelated()
    local copy={};for k,v in pairs(game.save)do if k~='playTime'then copy[k]=v end end
    return Save.encode(copy)
  end
  for _,gender in ipairs({'boy','girl'})do
    game.save.player.gender=gender
    local bag=Bag.new(game,{pocket='BERRY'});game.stack:push(bag);U.wait(30)
    for _=1,43 do press('up')end
    local initial=unrelated()
    assert(#bag.rows==44 and bag.index==1 and bag:selected().id==order[1])
    press('a');local action=game.stack:top()
    assert(getmetatable(action)==Action and action.entries[action.index].kind=='checkTag')
    shot('berry-'..gender..'-actual-check-tag-action')
    press('a');U.wait(40);local screen=game.stack:top()
    assert(getmetatable(screen)==Native and screen.scene.isOpen())
    local st=screen.scene._st;local man=st.man
    assert(#man.berries==43 and man.assetLayout=='rs'and st.pos==0 and st.berryId==1)
    for index,row in ipairs(man.berries)do
      assert(type(row.name)=='string'and type(row.description1)=='string'and type(row.description2)=='string')
      local pic=assert(screen.load('src.ui.game3.rse.scene_kit').image(row.png))
      assert(pic:getWidth()==64 and pic:getHeight()==64,'Original berry picture dimensions')
    end
    shot('berry-'..gender..'-first-original-tag')
    press('up',22);assert(st.pos==0 and st.phase=='input','First berry wrapped')
    press('down',1);assert(st.phase=='scroll'and st.pos==0)
    U.wait(5);assert(st.step<9 and st.pos==0 and bag.index==1)
    shot('berry-'..gender..'-scroll-before-replacement')
    U.wait(4);assert(st.step>=9 and st.pos==1 and bag.index==2,'Native midpoint did not update bag cursor')
    shot('berry-'..gender..'-scroll-after-replacement')
    U.wait(20);assert(st.phase=='input'and st.scrollY==0)
    for _=1,41 do press('down',22)end
    assert(st.pos==42 and st.berryId==43 and bag.index==43 and bag.top>1)
    assert(not st.enigma and st.info==man.berries[43],'Missing custom Enigma data must use ROM fallback')
    press('down',22);assert(st.pos==42 and st.phase=='input','Last berry wrapped into a close row')
    shot('berry-'..gender..'-last-enigma-rom-fallback')
    press(gender=='boy'and'b'or'a');U.wait(40)
    assert(game.stack:top()==bag and bag.index==43 and bag:selected().id==order[43])
    assert(initial==unrelated(),'Viewing berries changed fields beyond normal playTime')
    shot('berry-'..gender..'-return-retains-last-bag-row')
    press('a');press('a');U.wait(40);screen=game.stack:top();st=screen.scene._st
    assert(getmetatable(screen)==Native and st.pos==42)
    press('up',22);assert(st.pos==41 and bag.index==42)
    press('b');U.wait(40);assert(game.stack:top()==bag and bag.index==42)
    assert(initial==unrelated(),'Reopening or reverse scrolling changed inventory/save')
    press('b');U.wait(10);assert(game.stack:top()==world)
  end
  report.cases.actualBerryPocketCheckTagCallback=true
  report.cases.all43OriginalRecordsAndPictures=true
  report.cases.bothGenderNativeBackgrounds=true
  report.cases.originalSixteenStepScrollAndNinthStepReplacement=true
  report.cases.firstAndLastEdgesDoNotWrap=true
  report.cases.enigmaWithoutCustomDataUsesOriginalRecord=true
  report.cases.aAndBReturnRetainAuthoritativeBagCursor=true
  report.cases.reopenAndReverseScrollPreserveSaveAndInventory=true
  report.status='pass';persist();love.event.quit(0)
end
